-- Mixed orders: earn and redeem points from line items on the same order

create or replace function public.handle_order_completed()
returns trigger
language plpgsql
as $$
declare
  v_earn integer;
  v_redeem integer;
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

    v_earn := public.calculate_order_points(new.id);
    v_redeem := public.calculate_order_redemption_points(new.id);

    v_metadata := jsonb_build_object(
      'rule', case
        when v_earn > 0 and v_redeem > 0 then 'mixed'
        when v_redeem > 0 then 'redemption'
        else 'purchase'
      end,
      'items', v_items,
      'points_earned', v_earn,
      'points_redeemed', v_redeem
    );

    update public.orders
    set
      points_earned = v_earn,
      points_redeemed = v_redeem,
      is_redemption = (v_redeem > 0 and v_earn = 0 and new.total_cents = 0),
      reward_metadata = v_metadata,
      completed_at = coalesce(new.completed_at, now()),
      updated_at = now()
    where id = new.id;

    if v_redeem > 0 then
      perform public.apply_reward_transaction(
        new.profile_id,
        -v_redeem,
        'redeem',
        'Points redeemed for order ' || new.order_number,
        new.id,
        v_metadata
      );
    end if;

    if v_earn > 0 then
      perform public.apply_reward_transaction(
        new.profile_id,
        v_earn,
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
