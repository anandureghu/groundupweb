-- Configurable rewards: app_settings, snapshots, referral attribution

-- ---------------------------------------------------------------------------
-- App settings table
-- ---------------------------------------------------------------------------

create table public.app_settings (
  key text primary key,
  value_integer integer not null check (value_integer >= 0),
  description text,
  updated_at timestamptz not null default now()
);
create trigger app_settings_set_updated_at
before update on public.app_settings
for each row
execute function public.set_updated_at();
insert into public.app_settings (key, value_integer, description)
values
  (
    'purchase_points_per_product',
    50,
    'Default points earned per product unit for newly created products'
  ),
  (
    'referral_points_per_party',
    1000,
    'Points awarded to each party when a referral signup completes'
  );
-- ---------------------------------------------------------------------------
-- Snapshot and referral columns
-- ---------------------------------------------------------------------------

alter table public.reward_transactions
  add column if not exists metadata jsonb not null default '{}'::jsonb;
alter table public.orders
  add column if not exists reward_metadata jsonb not null default '{}'::jsonb;
alter table public.profiles
  add column if not exists referred_by_id uuid references public.profiles (id) on delete set null;
create index profiles_referred_by_id_idx on public.profiles (referred_by_id);
-- ---------------------------------------------------------------------------
-- Settings helpers
-- ---------------------------------------------------------------------------

create or replace function public.get_app_setting_integer(
  p_key text,
  p_default integer
)
returns integer
language sql
stable
as $$
  select coalesce(
    (select value_integer from public.app_settings where key = p_key),
    p_default
  );
$$;
create or replace function public.get_reward_settings()
returns table (
  purchase_points_per_product integer,
  referral_points_per_party integer
)
language sql
stable
as $$
  select
    public.get_app_setting_integer('purchase_points_per_product', 50),
    public.get_app_setting_integer('referral_points_per_party', 1000);
$$;
create or replace function public.update_app_setting(
  p_key text,
  p_value_integer integer
)
returns void
language plpgsql
as $$
begin
  if p_key not in ('purchase_points_per_product', 'referral_points_per_party') then
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
-- Rewards: apply a points transaction and update profile balance
-- ---------------------------------------------------------------------------

create or replace function public.apply_reward_transaction(
  p_profile_id uuid,
  p_points integer,
  p_type text,
  p_description text,
  p_order_id uuid default null,
  p_metadata jsonb default '{}'::jsonb
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
    description,
    metadata
  )
  values (
    p_profile_id,
    p_order_id,
    p_type,
    p_points,
    v_balance,
    p_description,
    coalesce(p_metadata, '{}'::jsonb)
  )
  returning id into v_transaction_id;

  return v_transaction_id;
end;
$$;
-- ---------------------------------------------------------------------------
-- Rewards: calculate points for an order
-- ---------------------------------------------------------------------------

create or replace function public.calculate_order_points(p_order_id uuid)
returns integer
language sql
stable
as $$
  select coalesce(sum(oi.quantity), 0)::integer
    * public.get_app_setting_integer('purchase_points_per_product', 50)
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
  v_total_quantity integer;
  v_rate integer;
  v_metadata jsonb;
begin
  if new.status = 'completed' and old.status is distinct from 'completed' then
    v_rate := public.get_app_setting_integer('purchase_points_per_product', 50);

    select coalesce(sum(quantity), 0)::integer
    into v_total_quantity
    from public.order_items
    where order_id = new.id;

    v_points := v_total_quantity * v_rate;

    v_metadata := jsonb_build_object(
      'rule', 'purchase',
      'purchase_points_per_product', v_rate,
      'total_quantity', v_total_quantity
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
-- ---------------------------------------------------------------------------
-- Referrals: award points on signup with a valid referral code
-- ---------------------------------------------------------------------------

create or replace function public.apply_referral_on_signup(
  p_referee_id uuid,
  p_referral_code text
)
returns void
language plpgsql
as $$
declare
  v_referrer_id uuid;
  v_rate integer;
  v_referee_metadata jsonb;
  v_referrer_metadata jsonb;
  v_normalized_code text;
begin
  v_normalized_code := upper(trim(p_referral_code));

  if v_normalized_code = '' then
    return;
  end if;

  select id
  into v_referrer_id
  from public.profiles
  where referral_code = v_normalized_code;

  if not found then
    raise exception 'Invalid referral code';
  end if;

  if v_referrer_id = p_referee_id then
    raise exception 'Cannot use your own referral code';
  end if;

  if exists (
    select 1
    from public.profiles
    where id = p_referee_id
      and referred_by_id is not null
  ) then
    raise exception 'Referral reward already applied for this member';
  end if;

  if exists (
    select 1
    from public.reward_transactions
    where profile_id = p_referee_id
      and type = 'referral'
  ) then
    raise exception 'Referral reward already applied for this member';
  end if;

  v_rate := public.get_app_setting_integer('referral_points_per_party', 1000);

  update public.profiles
  set
    referred_by_id = v_referrer_id,
    updated_at = now()
  where id = p_referee_id
    and referred_by_id is null;

  if not found then
    raise exception 'Referral reward already applied for this member';
  end if;

  v_referee_metadata := jsonb_build_object(
    'rule', 'referral',
    'referral_points_per_party', v_rate,
    'counterparty_profile_id', v_referrer_id,
    'role', 'referee'
  );

  v_referrer_metadata := jsonb_build_object(
    'rule', 'referral',
    'referral_points_per_party', v_rate,
    'counterparty_profile_id', p_referee_id,
    'role', 'referrer'
  );

  if v_rate > 0 then
    perform public.apply_reward_transaction(
      p_referee_id,
      v_rate,
      'referral',
      'Referral signup bonus',
      null,
      v_referee_metadata
    );

    perform public.apply_reward_transaction(
      v_referrer_id,
      v_rate,
      'referral',
      'Referral reward for new member',
      null,
      v_referrer_metadata
    );
  end if;
end;
$$;
-- ---------------------------------------------------------------------------
-- Dev grants
-- ---------------------------------------------------------------------------

alter table public.app_settings disable row level security;
grant select, insert, update, delete on table public.app_settings
  to anon, authenticated, service_role;
grant execute on function public.get_app_setting_integer(text, integer)
  to anon, authenticated, service_role;
grant execute on function public.get_reward_settings()
  to anon, authenticated, service_role;
grant execute on function public.update_app_setting(text, integer)
  to anon, authenticated, service_role;
grant execute on function public.apply_reward_transaction(uuid, integer, text, text, uuid, jsonb)
  to anon, authenticated, service_role;
grant execute on function public.apply_referral_on_signup(uuid, text)
  to anon, authenticated, service_role;
