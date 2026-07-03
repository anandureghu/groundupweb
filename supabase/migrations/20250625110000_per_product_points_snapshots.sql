-- Per-product points earning with line-item snapshots at order time

-- ---------------------------------------------------------------------------
-- Order items: snapshot points per unit when the order is placed
-- ---------------------------------------------------------------------------

alter table public.order_items
  add column if not exists points_earned integer not null default 0 check (points_earned >= 0);
update public.order_items oi
set points_earned = coalesce(p.points_earned, 0)
from public.products p
where p.id = oi.product_id
  and oi.points_earned = 0;
-- ---------------------------------------------------------------------------
-- Clarify app setting description
-- ---------------------------------------------------------------------------

update public.app_settings
set description = 'Default points earned per product unit for newly created products'
where key = 'purchase_points_per_product';
-- ---------------------------------------------------------------------------
-- Rewards: calculate points from snapshotted line-item rates
-- ---------------------------------------------------------------------------

create or replace function public.calculate_order_points(p_order_id uuid)
returns integer
language sql
stable
as $$
  select coalesce(sum(oi.quantity * oi.points_earned), 0)::integer
  from public.order_items oi
  where oi.order_id = p_order_id;
$$;
-- ---------------------------------------------------------------------------
-- Orders: award points when an order is completed
-- ---------------------------------------------------------------------------

create or replace function public.handle_order_completed()
returns trigger
language plpgsql
as $$
declare
  v_points integer;
  v_metadata jsonb;
begin
  if new.status = 'completed' and old.status is distinct from 'completed' then
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'product_id', oi.product_id,
          'product_name', oi.product_name,
          'quantity', oi.quantity,
          'points_earned', oi.points_earned
        )
        order by oi.created_at
      ),
      '[]'::jsonb
    )
    into v_metadata
    from public.order_items oi
    where oi.order_id = new.id;

    v_points := public.calculate_order_points(new.id);

    v_metadata := jsonb_build_object(
      'rule', 'purchase',
      'items', v_metadata,
      'total_points', v_points
    );

    update public.orders
    set
      points_earned = v_points,
      reward_metadata = v_metadata,
      completed_at = coalesce(new.completed_at, now()),
      updated_at = now()
    where id = new.id;

    if v_points > 0 then
      perform public.apply_reward_transaction(
        new.profile_id,
        v_points,
        'earn',
        'Points earned for order ' || new.order_number,
        new.id,
        v_metadata
      );
    end if;
  end if;

  return new;
end;
$$;
