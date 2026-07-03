-- Phase 5: Functions and triggers for Groundup Society commerce schema

-- ---------------------------------------------------------------------------
-- Shared: updated_at trigger (reusable across tables)
-- ---------------------------------------------------------------------------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;
create trigger stores_set_updated_at
before update on public.stores
for each row
execute function public.set_updated_at();
create trigger categories_set_updated_at
before update on public.categories
for each row
execute function public.set_updated_at();
create trigger products_set_updated_at
before update on public.products
for each row
execute function public.set_updated_at();
create trigger orders_set_updated_at
before update on public.orders
for each row
execute function public.set_updated_at();
create trigger promotions_set_updated_at
before update on public.promotions
for each row
execute function public.set_updated_at();
-- ---------------------------------------------------------------------------
-- Orders: auto-generate order numbers (GO-XXXXXX)
-- ---------------------------------------------------------------------------

create or replace function public.generate_order_number()
returns trigger
language plpgsql
as $$
declare
  chars constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  code text := 'GO-';
  i integer;
begin
  if new.order_number is not null and new.order_number <> '' then
    return new;
  end if;

  loop
    code := 'GO-';
    for i in 1..6 loop
      code := code || substr(chars, floor(random() * length(chars) + 1)::integer, 1);
    end loop;

    exit when not exists (
      select 1 from public.orders where order_number = code
    );
  end loop;

  new.order_number := code;
  return new;
end;
$$;
create trigger orders_set_order_number
before insert on public.orders
for each row
execute function public.generate_order_number();
-- ---------------------------------------------------------------------------
-- Order items: compute line totals
-- ---------------------------------------------------------------------------

create or replace function public.set_order_item_line_total()
returns trigger
language plpgsql
as $$
begin
  new.line_total_cents := new.unit_price_cents * new.quantity;
  return new;
end;
$$;
create trigger order_items_set_line_total
before insert or update of unit_price_cents, quantity on public.order_items
for each row
execute function public.set_order_item_line_total();
-- ---------------------------------------------------------------------------
-- Orders: recalculate subtotal and total from line items
-- ---------------------------------------------------------------------------

create or replace function public.recalculate_order_totals(p_order_id uuid)
returns void
language plpgsql
as $$
declare
  v_subtotal integer;
  v_tax integer;
begin
  select coalesce(sum(line_total_cents), 0)
  into v_subtotal
  from public.order_items
  where order_id = p_order_id;

  select tax_cents into v_tax
  from public.orders
  where id = p_order_id;

  update public.orders
  set
    subtotal_cents = v_subtotal,
    total_cents = v_subtotal + coalesce(v_tax, 0),
    updated_at = now()
  where id = p_order_id;
end;
$$;
create or replace function public.trigger_recalculate_order_totals()
returns trigger
language plpgsql
as $$
begin
  perform public.recalculate_order_totals(coalesce(new.order_id, old.order_id));
  return coalesce(new, old);
end;
$$;
create trigger order_items_recalculate_order_totals
after insert or update or delete on public.order_items
for each row
execute function public.trigger_recalculate_order_totals();
-- ---------------------------------------------------------------------------
-- Rewards: calculate points for an order
-- ---------------------------------------------------------------------------

create or replace function public.calculate_order_points(p_order_id uuid)
returns integer
language sql
stable
as $$
  select coalesce(sum(oi.quantity * coalesce(p.points_earned, 0)), 0)::integer
  from public.order_items oi
  left join public.products p on p.id = oi.product_id
  where oi.order_id = p_order_id;
$$;
-- ---------------------------------------------------------------------------
-- Rewards: apply a points transaction and update profile balance
-- ---------------------------------------------------------------------------

create or replace function public.apply_reward_transaction(
  p_profile_id uuid,
  p_points integer,
  p_type text,
  p_description text,
  p_order_id uuid default null
)
returns uuid
language plpgsql
as $$
declare
  v_balance integer;
  v_transaction_id uuid;
begin
  if p_points = 0 then
    raise exception 'Points must be non-zero';
  end if;

  select points_balance
  into v_balance
  from public.profiles
  where id = p_profile_id
  for update;

  if not found then
    raise exception 'Profile not found: %', p_profile_id;
  end if;

  v_balance := v_balance + p_points;

  if v_balance < 0 then
    raise exception 'Insufficient points balance for profile %', p_profile_id;
  end if;

  update public.profiles
  set
    points_balance = v_balance,
    updated_at = now()
  where id = p_profile_id;

  insert into public.reward_transactions (
    profile_id,
    order_id,
    type,
    points,
    balance_after,
    description
  )
  values (
    p_profile_id,
    p_order_id,
    p_type,
    p_points,
    v_balance,
    p_description
  )
  returning id into v_transaction_id;

  return v_transaction_id;
end;
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
begin
  if new.status = 'completed' and old.status is distinct from 'completed' then
    v_points := public.calculate_order_points(new.id);

    update public.orders
    set
      points_earned = v_points,
      completed_at = coalesce(new.completed_at, now()),
      updated_at = now()
    where id = new.id;

    if v_points > 0 then
      perform public.apply_reward_transaction(
        new.profile_id,
        v_points,
        'earn',
        'Points earned for order ' || new.order_number,
        new.id
      );
    end if;
  end if;

  return new;
end;
$$;
create trigger orders_handle_completed
after update of status on public.orders
for each row
execute function public.handle_order_completed();
-- ---------------------------------------------------------------------------
-- Profiles: ensure signup trigger sets default customer role in app_metadata
-- (optional helper — keeps roles consistent without dashboard edits)
-- ---------------------------------------------------------------------------

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (
    id,
    first_name,
    last_name,
    email,
    mobile_number,
    birthday,
    marketing_opt_in,
    points_balance
  )
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'first_name', ''),
    coalesce(new.raw_user_meta_data->>'last_name', ''),
    coalesce(new.email, ''),
    coalesce(new.raw_user_meta_data->>'mobile_number', ''),
    coalesce(nullif(new.raw_user_meta_data->>'birthday', '')::date, date '2000-01-01'),
    coalesce((new.raw_user_meta_data->>'marketing_opt_in')::boolean, false),
    0
  )
  on conflict (id) do nothing;

  if new.raw_app_meta_data is null
     or new.raw_app_meta_data->'roles' is null then
    update auth.users
    set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb)
      || jsonb_build_object('roles', jsonb_build_array('customer'))
    where id = new.id;
  end if;

  return new;
end;
$$;
-- ---------------------------------------------------------------------------
-- Utility: list active promotions (for app queries)
-- ---------------------------------------------------------------------------

create or replace function public.get_active_promotions()
returns setof public.promotions
language sql
stable
as $$
  select *
  from public.promotions
  where is_active = true
    and starts_at <= now()
    and (ends_at is null or ends_at >= now())
  order by starts_at desc;
$$;
-- ---------------------------------------------------------------------------
-- Utility: member points summary
-- ---------------------------------------------------------------------------

create or replace function public.get_member_points_summary(p_profile_id uuid)
returns table (
  points_balance integer,
  lifetime_earned integer,
  lifetime_redeemed integer
)
language sql
stable
as $$
  select
    p.points_balance,
    coalesce(sum(rt.points) filter (where rt.points > 0), 0)::integer as lifetime_earned,
    coalesce(abs(sum(rt.points) filter (where rt.points < 0)), 0)::integer as lifetime_redeemed
  from public.profiles p
  left join public.reward_transactions rt on rt.profile_id = p.id
  where p.id = p_profile_id
  group by p.points_balance;
$$;
grant execute on function public.recalculate_order_totals(uuid) to anon, authenticated, service_role;
grant execute on function public.calculate_order_points(uuid) to anon, authenticated, service_role;
grant execute on function public.apply_reward_transaction(uuid, integer, text, text, uuid) to anon, authenticated, service_role;
grant execute on function public.get_active_promotions() to anon, authenticated, service_role;
grant execute on function public.get_member_points_summary(uuid) to anon, authenticated, service_role;
