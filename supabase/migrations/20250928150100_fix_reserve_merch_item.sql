-- Fix reserve_merch_item drop lookup (invalid SELECT INTO)

create or replace function public.reserve_merch_item(p_item_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_profile_id uuid := auth.uid();
  v_item public.merch_items%rowtype;
  v_drop_launch timestamptz;
  v_launch timestamptz;
  v_points integer;
  v_code text;
  v_reservation_id uuid;
begin
  if v_profile_id is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_item
  from public.merch_items
  where id = p_item_id
  for update;

  if not found or not v_item.is_active then
    raise exception 'Merch item not found';
  end if;

  if v_item.drop_id is not null then
    select launch_at into v_drop_launch
    from public.merch_drops
    where id = v_item.drop_id and is_active;
    if not found then
      raise exception 'Merch drop not available';
    end if;
  end if;

  v_launch := public.merch_item_effective_launch_at(v_item.launch_at, v_drop_launch);
  if not public.merch_is_launched(v_launch) then
    raise exception 'Merch item is not available yet';
  end if;

  if v_item.quantity_remaining <= 0 then
    raise exception 'Merch item is sold out';
  end if;

  if exists (
    select 1 from public.merch_reservations
    where profile_id = v_profile_id and item_id = v_item.id and status = 'reserved'
  ) then
    raise exception 'You already have a reservation for this item';
  end if;

  v_points := coalesce(nullif(v_item.points_required, 0), 0);

  if v_points > 0 then
    perform public.apply_reward_transaction(
      v_profile_id,
      -v_points,
      'redeem',
      'Merch reservation: ' || v_item.name,
      null,
      jsonb_build_object('merch_item_id', v_item.id, 'merch_slug', v_item.slug)
    );
  end if;

  update public.merch_items
  set quantity_remaining = quantity_remaining - 1,
      updated_at = now()
  where id = v_item.id;

  v_code := public.generate_merch_claim_code();

  insert into public.merch_reservations (
    profile_id, item_id, claim_code, points_spent, status
  ) values (
    v_profile_id, v_item.id, v_code, v_points, 'reserved'
  )
  returning id into v_reservation_id;

  return jsonb_build_object(
    'id', v_reservation_id,
    'claimCode', v_code,
    'pointsSpent', v_points,
    'status', 'reserved',
    'itemId', v_item.id,
    'itemSlug', v_item.slug,
    'itemName', v_item.name
  );
end;
$$;
