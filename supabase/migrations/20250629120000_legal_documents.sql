-- Legal documents in app_settings and signup consent on profiles

alter table public.profiles
  add column if not exists terms_accepted_at timestamptz,
  add column if not exists privacy_accepted_at timestamptz,
  add column if not exists legal_version text;
insert into public.app_settings (key, value_integer, value_text, description)
values
  (
    'legal_documents_version',
    0,
    '1.0',
    'Version label for terms and privacy policy shown during signup'
  ),
  (
    'terms_content',
    0,
    E'Terms and Conditions\n\nBy creating a Groundup Society account, you agree to use the app responsibly and follow our cafe policies.\n\nMembership rewards, offers, and promotions may change from time to time. Points and redemptions are subject to availability and store rules.\n\nWe may update these terms. Continued use of the app after changes are published means you accept the updated terms.',
    'Terms and conditions shown during signup'
  ),
  (
    'privacy_policy_content',
    0,
    E'Privacy Policy\n\nGroundup Society collects the information you provide during signup, including your name, email, mobile number, and birthday, so we can manage your membership.\n\nWe use your details to operate rewards, orders, referrals, and member communications. We do not sell your personal data.\n\nYou can contact us if you want to update or delete your account information, subject to legal and operational requirements.',
    'Privacy policy shown during signup'
  )
on conflict (key) do nothing;
create or replace function public.get_legal_documents()
returns table (
  version text,
  terms_content text,
  privacy_policy_content text
)
language sql
stable
as $$
  select
    public.get_app_setting_text('legal_documents_version', '1.0'),
    public.get_app_setting_text(
      'terms_content',
      'Terms and conditions are not available right now.'
    ),
    public.get_app_setting_text(
      'privacy_policy_content',
      'Privacy policy is not available right now.'
    );
$$;
grant execute on function public.get_legal_documents()
  to anon, authenticated, service_role;
create or replace function public.update_app_setting_text(
  p_key text,
  p_value_text text
)
returns void
language plpgsql
as $$
begin
  perform public.assert_admin_access();

  if p_key not in (
    'default_redeem_title',
    'default_redeem_description',
    'legal_documents_version',
    'terms_content',
    'privacy_policy_content'
  ) then
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
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  assigned_store uuid;
begin
  assigned_store := nullif(new.raw_user_meta_data->>'assigned_store_id', '')::uuid;

  insert into public.profiles (
    id,
    first_name,
    last_name,
    email,
    mobile_number,
    birthday,
    marketing_opt_in,
    points_balance,
    must_change_password,
    is_profile_completed,
    is_active,
    assigned_store_id,
    staff_role,
    terms_accepted_at,
    privacy_accepted_at,
    legal_version
  )
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'first_name', ''),
    coalesce(new.raw_user_meta_data->>'last_name', ''),
    coalesce(new.email, ''),
    coalesce(new.raw_user_meta_data->>'mobile_number', ''),
    coalesce(nullif(new.raw_user_meta_data->>'birthday', '')::date, date '2000-01-01'),
    coalesce((new.raw_user_meta_data->>'marketing_opt_in')::boolean, false),
    0,
    coalesce((new.raw_user_meta_data->>'must_change_password')::boolean, false),
    coalesce((new.raw_user_meta_data->>'is_profile_completed')::boolean, true),
    coalesce((new.raw_user_meta_data->>'is_active')::boolean, true),
    assigned_store,
    nullif(new.raw_user_meta_data->>'staff_role', ''),
    nullif(new.raw_user_meta_data->>'terms_accepted_at', '')::timestamptz,
    nullif(new.raw_user_meta_data->>'privacy_accepted_at', '')::timestamptz,
    nullif(new.raw_user_meta_data->>'legal_version', '')
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
