-- Feature gates + staff invite lookup + onboarding analytics

insert into public.app_settings (key, value_integer, value_text, description)
values
  (
    'feature_gates',
    0,
    '{"defaultMode":"coming_soon","enabledScreens":[],"comingSoonMessage":"We are preparing something special. Check back soon."}',
    'JSON feature gate config for first-release coming soon mode'
  ),
  (
    'feature_gate_whitelist',
    0,
    '[]',
    'JSON array of profile UUIDs allowed to bypass feature gates'
  )
on conflict (key) do update
set
  value_text = coalesce(public.app_settings.value_text, excluded.value_text),
  description = excluded.description,
  updated_at = now();

-- ---------------------------------------------------------------------------
-- Feature gates (authenticated read; admin write)
-- ---------------------------------------------------------------------------

create or replace function public.get_feature_gates()
returns table (
  default_mode text,
  enabled_screens jsonb,
  coming_soon_message text,
  is_whitelisted boolean
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_gates jsonb;
  v_whitelist jsonb;
  v_uid uuid := auth.uid();
  v_email text;
begin
  select coalesce(value_text::jsonb, '{}'::jsonb)
  into v_gates
  from public.app_settings
  where key = 'feature_gates';

  select coalesce(value_text::jsonb, '[]'::jsonb)
  into v_whitelist
  from public.app_settings
  where key = 'feature_gate_whitelist';

  if v_uid is not null then
    select lower(trim(email)) into v_email
    from public.profiles
    where id = v_uid;
  end if;

  return query
  select
    coalesce(v_gates->>'defaultMode', 'full') as default_mode,
    coalesce(v_gates->'enabledScreens', '[]'::jsonb) as enabled_screens,
    coalesce(
      nullif(trim(v_gates->>'comingSoonMessage'), ''),
      'We are preparing something special. Check back soon.'
    ) as coming_soon_message,
    (
      v_uid is not null
      and (
        v_whitelist ? v_uid::text
        or (
          v_email is not null
          and exists (
            select 1
            from jsonb_array_elements_text(v_whitelist) as w(value)
            where lower(trim(w.value)) = v_email
          )
        )
      )
    ) as is_whitelisted;
end;
$$;

grant execute on function public.get_feature_gates() to authenticated, service_role;

create or replace function public.update_feature_gates(
  p_default_mode text,
  p_coming_soon_message text,
  p_enabled_screens jsonb default '[]'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_mode text := lower(trim(coalesce(p_default_mode, 'coming_soon')));
  v_message text := trim(coalesce(p_coming_soon_message, ''));
  v_payload jsonb;
begin
  perform public.assert_admin_access();

  if v_mode not in ('coming_soon', 'full') then
    raise exception 'Invalid feature gate mode';
  end if;

  if v_message = '' then
    v_message := 'We are preparing something special. Check back soon.';
  end if;

  v_payload := jsonb_build_object(
    'defaultMode', v_mode,
    'enabledScreens', coalesce(p_enabled_screens, '[]'::jsonb),
    'comingSoonMessage', v_message
  );

  insert into public.app_settings (key, value_integer, value_text, description)
  values (
    'feature_gates',
    0,
    v_payload::text,
    'JSON feature gate config for first-release coming soon mode'
  )
  on conflict (key) do update
  set
    value_text = excluded.value_text,
    updated_at = now();
end;
$$;

grant execute on function public.update_feature_gates(text, text, jsonb) to authenticated, service_role;

create or replace function public.update_feature_gate_whitelist(p_whitelist jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.assert_admin_access();

  if p_whitelist is null or jsonb_typeof(p_whitelist) <> 'array' then
    raise exception 'Whitelist must be a JSON array';
  end if;

  insert into public.app_settings (key, value_integer, value_text, description)
  values (
    'feature_gate_whitelist',
    0,
    p_whitelist::text,
    'JSON array of profile UUIDs allowed to bypass feature gates'
  )
  on conflict (key) do update
  set
    value_text = excluded.value_text,
    updated_at = now();
end;
$$;

grant execute on function public.update_feature_gate_whitelist(jsonb) to authenticated, service_role;

create or replace function public.list_feature_gate_whitelist_members()
returns table (
  id uuid,
  first_name text,
  last_name text,
  email text,
  referral_code text
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_whitelist jsonb;
begin
  perform public.assert_admin_access();

  select coalesce(value_text::jsonb, '[]'::jsonb)
  into v_whitelist
  from public.app_settings
  where key = 'feature_gate_whitelist';

  return query
  select
    p.id,
    p.first_name,
    p.last_name,
    p.email,
    p.referral_code
  from public.profiles p
  where p.staff_role is null
    and (
      v_whitelist ? p.id::text
      or lower(trim(p.email)) in (
        select lower(trim(w.value))
        from jsonb_array_elements_text(v_whitelist) as w(value)
      )
    )
  order by p.first_name, p.last_name;
end;
$$;

grant execute on function public.list_feature_gate_whitelist_members() to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Referral code lookup (for signup staff attribution)
-- ---------------------------------------------------------------------------

create or replace function public.lookup_referral_code(p_code text)
returns table (
  valid boolean,
  is_staff boolean,
  display_name text,
  referral_code text
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_code text := upper(trim(coalesce(p_code, '')));
  v_profile public.profiles%rowtype;
begin
  if v_code = '' or v_code !~ '^GS-[A-Z0-9]{6}$' then
    return query select false, false, null::text, null::text;
    return;
  end if;

  select * into v_profile
  from public.profiles
  where referral_code = v_code
    and is_active = true
  limit 1;

  if not found then
    return query select false, false, null::text, null::text;
    return;
  end if;

  return query
  select
    true,
    v_profile.staff_role is not null,
    nullif(trim(concat_ws(' ', v_profile.first_name, v_profile.last_name)), ''),
    v_profile.referral_code;
end;
$$;

grant execute on function public.lookup_referral_code(text) to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Admin onboarding analytics
-- ---------------------------------------------------------------------------

create or replace function public.get_admin_onboarding_analytics()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_total_customers integer;
  v_total_staff integer;
  v_total_admins integer;
  v_staff_onboardings jsonb;
  v_total_staff_onboarded integer;
begin
  perform public.assert_admin_access();

  select count(*)::integer into v_total_customers
  from public.profiles
  where staff_role is null
    and is_profile_completed = true;

  select count(*)::integer into v_total_staff
  from public.profiles
  where staff_role = 'staff';

  select count(*)::integer into v_total_admins
  from public.profiles
  where staff_role = 'admin';

  select coalesce(jsonb_agg(row_data order by (row_data->>'onboardedCount')::integer desc), '[]'::jsonb)
  into v_staff_onboardings
  from (
    select jsonb_build_object(
      'staffId', s.id,
      'name', nullif(trim(concat_ws(' ', s.first_name, s.last_name)), ''),
      'email', s.email,
      'referralCode', s.referral_code,
      'onboardedCount', coalesce(c.cnt, 0)
    ) as row_data
    from public.profiles s
    left join lateral (
      select count(*)::integer as cnt
      from public.profiles r
      where r.referred_by_id = s.id
        and r.staff_role is null
    ) c on true
    where s.staff_role = 'staff'
  ) staff_rows;

  select coalesce(sum((item->>'onboardedCount')::integer), 0)::integer
  into v_total_staff_onboarded
  from jsonb_array_elements(v_staff_onboardings) as item;

  return jsonb_build_object(
    'totalCustomers', v_total_customers,
    'totalStaff', v_total_staff,
    'totalAdmins', v_total_admins,
    'totalStaffOnboarded', v_total_staff_onboarded,
    'staffOnboardings', v_staff_onboardings
  );
end;
$$;

grant execute on function public.get_admin_onboarding_analytics() to authenticated, service_role;

-- Extend staff list with onboarded counts
create or replace function public.list_staff_members()
returns table (
  id uuid,
  first_name text,
  last_name text,
  email text,
  staff_role text,
  assigned_store_id uuid,
  store_name text,
  is_active boolean,
  must_change_password boolean,
  is_profile_completed boolean,
  created_at timestamptz,
  referral_code text,
  onboarded_count integer
)
language sql
stable
security definer
set search_path = public
as $$
  select
    p.id,
    p.first_name,
    p.last_name,
    p.email,
    p.staff_role,
    p.assigned_store_id,
    s.name as store_name,
    p.is_active,
    p.must_change_password,
    p.is_profile_completed,
    p.created_at,
    p.referral_code,
    (
      select count(*)::integer
      from public.profiles r
      where r.referred_by_id = p.id
        and r.staff_role is null
    ) as onboarded_count
  from public.profiles p
  left join public.stores s on s.id = p.assigned_store_id
  where p.staff_role is not null
  order by p.created_at desc;
$$;

grant execute on function public.list_staff_members() to anon, authenticated, service_role;

-- Admin customer referred-by display
create or replace function public.get_admin_customer_referrer(p_customer_id uuid)
returns table (
  referrer_id uuid,
  display_name text,
  referral_code text,
  is_staff boolean
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform public.assert_admin_access();

  return query
  select
    r.id,
    nullif(trim(concat_ws(' ', r.first_name, r.last_name)), ''),
    r.referral_code,
    r.staff_role is not null
  from public.profiles c
  join public.profiles r on r.id = c.referred_by_id
  where c.id = p_customer_id;
end;
$$;

grant execute on function public.get_admin_customer_referrer(uuid) to authenticated, service_role;
