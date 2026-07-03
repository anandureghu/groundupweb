-- App settings: text values and admin-only updates for all settings

alter table public.app_settings
  add column if not exists value_text text;
insert into public.app_settings (key, value_integer, value_text, description)
values
  (
    'default_redeem_title',
    0,
    'Claim with points',
    'Default redemption title shown when a product has no custom title'
  ),
  (
    'default_redeem_description',
    0,
    'Visit the counter and show your member QR to redeem this item.',
    'Default redemption description shown when a product has no custom description'
  )
on conflict (key) do nothing;
create or replace function public.get_app_setting_text(
  p_key text,
  p_default text
)
returns text
language sql
stable
as $$
  select coalesce(
    nullif(trim((select value_text from public.app_settings where key = p_key)), ''),
    p_default
  );
$$;
create or replace function public.assert_admin_access()
returns void
language plpgsql
as $$
declare
  v_role text;
begin
  select staff_role
  into v_role
  from public.profiles
  where id = auth.uid();

  if v_role is distinct from 'admin' then
    raise exception 'Admin access required';
  end if;
end;
$$;
drop function if exists public.get_reward_settings();
create function public.get_reward_settings()
returns table (
  purchase_points_per_product integer,
  referral_points_per_party integer,
  default_points_to_redeem integer,
  default_redeem_title text,
  default_redeem_description text
)
language sql
stable
as $$
  select
    public.get_app_setting_integer('purchase_points_per_product', 50),
    public.get_app_setting_integer('referral_points_per_party', 1000),
    public.get_app_setting_integer('default_points_to_redeem', 200),
    public.get_app_setting_text('default_redeem_title', 'Claim with points'),
    public.get_app_setting_text(
      'default_redeem_description',
      'Visit the counter and show your member QR to redeem this item.'
    );
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
  perform public.assert_admin_access();

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
create or replace function public.update_app_setting_text(
  p_key text,
  p_value_text text
)
returns void
language plpgsql
as $$
begin
  perform public.assert_admin_access();

  if p_key not in ('default_redeem_title', 'default_redeem_description') then
    raise exception 'Unknown app setting key: %', p_key;
  end if;

  if nullif(trim(p_value_text), '') is null then
    raise exception 'Setting value must not be empty';
  end if;

  update public.app_settings
  set
    value_text = trim(p_value_text),
    updated_at = now()
  where key = p_key;

  if not found then
    raise exception 'App setting not found: %', p_key;
  end if;
end;
$$;
grant execute on function public.get_app_setting_text(text, text)
  to anon, authenticated, service_role;
grant execute on function public.assert_admin_access()
  to anon, authenticated, service_role;
grant execute on function public.update_app_setting_text(text, text)
  to anon, authenticated, service_role;
