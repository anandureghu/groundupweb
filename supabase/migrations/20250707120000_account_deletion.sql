-- Account deletion: audit log, profile anonymization, and auth user removal support

create table public.deleted_accounts (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete restrict,
  email text not null,
  reason text not null,
  experience_rating smallint check (experience_rating between 1 and 5),
  experience_emoji text,
  deleted_at timestamptz not null default now()
);

create index deleted_accounts_profile_id_idx on public.deleted_accounts (profile_id);
create index deleted_accounts_email_idx on public.deleted_accounts (lower(email));
create index deleted_accounts_deleted_at_idx on public.deleted_accounts (deleted_at desc);

comment on table public.deleted_accounts is
  'Audit log when a member deletes their account from the website or app.';

alter table public.profiles
  add column if not exists deleted_at timestamptz;

create index if not exists profiles_deleted_at_idx
  on public.profiles (deleted_at)
  where deleted_at is not null;

-- Allow profile rows to remain for order history after auth.users is deleted.
alter table public.profiles
  drop constraint if exists profiles_id_fkey;

create or replace function public.delete_member_account(
  p_email text,
  p_reason text,
  p_experience_rating smallint default null,
  p_experience_emoji text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_profile public.profiles;
  v_anonymized_email text;
begin
  if nullif(trim(p_email), '') is null then
    raise exception 'Email is required';
  end if;

  if nullif(trim(p_reason), '') is null then
    raise exception 'Reason is required';
  end if;

  if p_experience_rating is not null
    and (p_experience_rating < 1 or p_experience_rating > 5) then
    raise exception 'Experience rating must be between 1 and 5';
  end if;

  select *
  into v_profile
  from public.profiles
  where lower(email) = lower(trim(p_email))
  limit 1;

  if not found then
    raise exception 'No account found for this email address';
  end if;

  if v_profile.staff_role is not null then
    raise exception 'Staff accounts cannot be deleted through this page';
  end if;

  if v_profile.deleted_at is not null then
    raise exception 'This account has already been deleted';
  end if;

  if exists (
    select 1
    from public.deleted_accounts da
    where da.profile_id = v_profile.id
  ) then
    raise exception 'This account has already been deleted';
  end if;

  insert into public.deleted_accounts (
    profile_id,
    email,
    reason,
    experience_rating,
    experience_emoji
  )
  values (
    v_profile.id,
    v_profile.email,
    trim(p_reason),
    p_experience_rating,
    nullif(trim(p_experience_emoji), '')
  );

  v_anonymized_email :=
    'deleted+' || replace(v_profile.id::text, '-', '') || '@deleted.groundupsociety.local';

  update public.profiles
  set
    first_name = 'Deleted',
    last_name = 'Member',
    email = v_anonymized_email,
    mobile_number = '0000000000',
    birthday = date '2000-01-01',
    marketing_opt_in = false,
    avatar_url = null,
    points_balance = 0,
    is_active = false,
    is_profile_completed = false,
    must_change_password = false,
    deleted_at = now(),
    updated_at = now()
  where id = v_profile.id;

  update public.push_tokens
  set is_active = false, updated_at = now()
  where profile_id = v_profile.id;

  return v_profile.id;
end;
$$;

revoke all on function public.delete_member_account(text, text, smallint, text)
  from public, anon, authenticated;

grant execute on function public.delete_member_account(text, text, smallint, text)
  to service_role;

alter table public.deleted_accounts enable row level security;

create or replace function public.list_customers()
returns table (
  id uuid,
  first_name text,
  last_name text,
  email text,
  mobile_number text,
  referral_code text,
  points_balance integer,
  is_active boolean,
  created_at timestamptz
)
language plpgsql
stable
as $$
begin
  perform public.assert_admin_access();

  return query
  select
    p.id,
    p.first_name,
    p.last_name,
    p.email,
    p.mobile_number,
    p.referral_code,
    p.points_balance,
    p.is_active,
    p.created_at
  from public.profiles p
  where p.staff_role is null
    and p.is_profile_completed = true
    and p.deleted_at is null
  order by p.created_at desc;
end;
$$;

grant select on table public.deleted_accounts to service_role;
