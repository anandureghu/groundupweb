-- Per-product points redemption via $0 redemption orders

-- ---------------------------------------------------------------------------
-- Products: redemption config
-- ---------------------------------------------------------------------------

alter table public.products
  add column if not exists is_redeemable boolean not null default false,
  add column if not exists points_to_redeem integer not null default 200 check (points_to_redeem >= 0),
  add column if not exists redeem_title text,
  add column if not exists redeem_description text;
-- ---------------------------------------------------------------------------
-- App settings: default redemption cost
-- ---------------------------------------------------------------------------

insert into public.app_settings (key, value_integer, description)
values (
  'default_points_to_redeem',
  200,
  'Default points required to redeem a product when not overridden per product'
)
on conflict (key) do nothing;
drop function if exists public.get_reward_settings();
create function public.get_reward_settings()
returns table (
  purchase_points_per_product integer,
  referral_points_per_party integer,
  default_points_to_redeem integer
)
language sql
stable
as $$
  select
    public.get_app_setting_integer('purchase_points_per_product', 50),
    public.get_app_setting_integer('referral_points_per_party', 1000),
    public.get_app_setting_integer('default_points_to_redeem', 200);
$$;
grant execute on function public.get_reward_settings()
  to anon, authenticated, service_role;
create or replace function public.update_app_setting(
  p_key text,
  p_value_integer integer
)
returns void
language plpgsql
as $$
begin
  if p_key not in (
    'purchase_points_per_product',
    'referral_points_per_party',
    'default_points_to_redeem'
  ) then
    raise exception 'Unknown app setting key: %', p_key;
  end if;

  if p_value_integer < 0 then
    raise exception 'Setting value must be non-negative';
  end if;

  update public.app_settings
  set
    value_integer = p_value_integer,
    updated_at = now()
  where key = p_key;

  if not found then
    raise exception 'App setting not found: %', p_key;
  end if;
end;
$$;
-- ---------------------------------------------------------------------------
-- Orders: redemption markers
-- ---------------------------------------------------------------------------

alter table public.orders
  add column if not exists is_redemption boolean not null default false,
  add column if not exists points_redeemed integer not null default 0 check (points_redeemed >= 0);
alter table public.order_items
  add column if not exists points_redeemed integer not null default 0 check (points_redeemed >= 0);
-- ---------------------------------------------------------------------------
-- Rewards: calculate redemption points from line-item snapshots
-- ---------------------------------------------------------------------------

create or replace function public.calculate_order_redemption_points(p_order_id uuid)
returns integer
language sql
stable
as $$
  select coalesce(sum(oi.quantity * oi.points_redeemed), 0)::integer
  from public.order_items oi
  where oi.order_id = p_order_id;
$$;
-- ---------------------------------------------------------------------------
-- Orders: award or redeem points when an order is completed
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
-- ---------------------------------------------------------------------------
-- Staff: create a $0 redemption order with balance validation
-- ---------------------------------------------------------------------------

create or replace function public.create_redemption_order(
  p_profile_id uuid,
  p_store_id uuid,
  p_product_id uuid,
  p_quantity integer default 1
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_caller_role text;
  v_balance integer;
  v_product record;
  v_cost integer;
  v_order_id uuid;
begin
  if p_quantity is null or p_quantity < 1 then
    raise exception 'Quantity must be at least 1';
  end if;

  select staff_role
  into v_caller_role
  from public.profiles
  where id = auth.uid();

  if v_caller_role is null then
    raise exception 'Only staff can create redemption orders';
  end if;

  select
    id,
    name,
    is_redeemable,
    is_active,
    points_to_redeem
  into v_product
  from public.products
  where id = p_product_id;

  if not found then
    raise exception 'Product not found: %', p_product_id;
  end if;

  if not v_product.is_active then
    raise exception 'Product is not active';
  end if;

  if not v_product.is_redeemable then
    raise exception 'Product is not redeemable';
  end if;

  v_cost := v_product.points_to_redeem * p_quantity;

  select points_balance
  into v_balance
  from public.profiles
  where id = p_profile_id
  for update;

  if not found then
    raise exception 'Profile not found: %', p_profile_id;
  end if;

  if v_balance < v_cost then
    raise exception 'Insufficient points balance for profile %', p_profile_id;
  end if;

  insert into public.orders (
    profile_id,
    store_id,
    status,
    subtotal_cents,
    tax_cents,
    total_cents,
    notes,
    is_redemption,
    order_number
  )
  values (
    p_profile_id,
    p_store_id,
    'pending',
    0,
    0,
    0,
    'Points redemption',
    true,
    ''
  )
  returning id into v_order_id;

  insert into public.order_items (
    order_id,
    product_id,
    product_name,
    unit_price_cents,
    points_earned,
    points_redeemed,
    quantity
  )
  values (
    v_order_id,
    v_product.id,
    v_product.name,
    0,
    0,
    v_product.points_to_redeem,
    p_quantity
  );

  return v_order_id;
end;
$$;
-- ---------------------------------------------------------------------------
-- Demo: mark sample products as redeemable
-- ---------------------------------------------------------------------------

update public.products
set
  is_redeemable = true,
  points_to_redeem = 200,
  redeem_title = 'Claim with points',
  redeem_description = 'Visit the counter and show your member QR to redeem this ceremonial matcha.'
where slug = 'ceremonial-matcha';
update public.products
set
  is_redeemable = true,
  points_to_redeem = 200,
  redeem_title = 'Complimentary oat flat white',
  redeem_description = 'Use your reward points to claim an oat flat white at the register.'
where slug = 'oat-flat-white';
grant execute on function public.calculate_order_redemption_points(uuid)
  to anon, authenticated, service_role;
grant execute on function public.create_redemption_order(uuid, uuid, uuid, integer)
  to anon, authenticated, service_role;
