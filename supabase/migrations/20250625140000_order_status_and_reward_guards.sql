-- Order status: forward-only transitions and idempotent reward settlement

-- ---------------------------------------------------------------------------
-- Status transitions: no backward moves; terminal statuses are immutable
-- ---------------------------------------------------------------------------

create or replace function public.validate_order_status_transition()
returns trigger
language plpgsql
as $$
declare
  v_old_rank integer;
  v_new_rank integer;
begin
  if old.status is not distinct from new.status then
    return new;
  end if;

  if old.status in ('completed', 'cancelled') then
    raise exception 'Orders in % status cannot be changed', old.status;
  end if;

  v_old_rank := case old.status
    when 'pending' then 0
    when 'confirmed' then 1
    when 'preparing' then 2
    when 'ready' then 3
    else -1
  end;

  v_new_rank := case new.status
    when 'pending' then 0
    when 'confirmed' then 1
    when 'preparing' then 2
    when 'ready' then 3
    when 'completed' then 4
    when 'cancelled' then 5
    else -1
  end;

  if v_old_rank = -1 or v_new_rank = -1 then
    raise exception 'Invalid order status transition from % to %', old.status, new.status;
  end if;

  if new.status = 'cancelled' then
    return new;
  end if;

  if v_new_rank <= v_old_rank then
    raise exception 'Order status can only move forward';
  end if;

  return new;
end;
$$;
drop trigger if exists orders_validate_status_transition on public.orders;
create trigger orders_validate_status_transition
before update of status on public.orders
for each row
execute function public.validate_order_status_transition();
-- ---------------------------------------------------------------------------
-- Rewards: apply earn or redeem once per order
-- ---------------------------------------------------------------------------

create or replace function public.handle_order_completed()
returns trigger
language plpgsql
as $$
declare
  v_points integer;
  v_metadata jsonb;
  v_items jsonb;
begin
  if new.status = 'completed' and old.status is distinct from 'completed' then
    if exists (
      select 1
      from public.reward_transactions rt
      where rt.order_id = new.id
        and rt.type in ('earn', 'redeem')
    ) then
      return new;
    end if;

    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'product_id', oi.product_id,
          'product_name', oi.product_name,
          'quantity', oi.quantity,
          'points_earned', oi.points_earned,
          'points_redeemed', oi.points_redeemed
        )
        order by oi.created_at
      ),
      '[]'::jsonb
    )
    into v_items
    from public.order_items oi
    where oi.order_id = new.id;

    if new.is_redemption then
      v_points := public.calculate_order_redemption_points(new.id);

      v_metadata := jsonb_build_object(
        'rule', 'redemption',
        'items', v_items,
        'total_points', v_points
      );

      update public.orders
      set
        points_redeemed = v_points,
        reward_metadata = v_metadata,
        completed_at = coalesce(new.completed_at, now()),
        updated_at = now()
      where id = new.id;

      if v_points > 0 then
        perform public.apply_reward_transaction(
          new.profile_id,
          -v_points,
          'redeem',
          'Points redeemed for order ' || new.order_number,
          new.id,
          v_metadata
        );
      end if;
    else
      v_points := public.calculate_order_points(new.id);

      v_metadata := jsonb_build_object(
        'rule', 'purchase',
        'items', v_items,
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
  end if;

  return new;
end;
$$;
grant execute on function public.validate_order_status_transition()
  to anon, authenticated, service_role;
