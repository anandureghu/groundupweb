-- Prevent duplicate sign-ups by email (auth + profiles) and normalized phone number

create or replace function public.check_signup_availability(
  p_email text,
  p_mobile_number text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  normalized_email text := lower(trim(coalesce(p_email, '')));
  normalized_mobile text := regexp_replace(coalesce(p_mobile_number, ''), '[^0-9]', '', 'g');
  email_exists boolean := false;
  mobile_exists boolean := false;
begin
  if normalized_email <> '' then
    select exists (
      select 1
      from auth.users
      where lower(email) = normalized_email
      union
      select 1
      from public.profiles
      where lower(email) = normalized_email
    ) into email_exists;
  end if;

  if normalized_mobile <> '' then
    select exists (
      select 1
      from public.profiles
      where regexp_replace(mobile_number, '[^0-9]', '', 'g') = normalized_mobile
    ) into mobile_exists;
  end if;

  return jsonb_build_object(
    'emailTaken', email_exists,
    'mobileTaken', mobile_exists
  );
end;
$$;
revoke all on function public.check_signup_availability(text, text) from public;
grant execute on function public.check_signup_availability(text, text) to service_role;
-- Keep the earliest profile when legacy seed data reused the same phone number.
with ranked_profiles as (
  select
    id,
    row_number() over (
      partition by regexp_replace(mobile_number, '[^0-9]', '', 'g')
      order by created_at asc, id asc
    ) as row_number
  from public.profiles
  where length(regexp_replace(mobile_number, '[^0-9]', '', 'g')) > 0
)
update public.profiles as profile
set mobile_number = profile.mobile_number || ' #' || substring(profile.id::text, 1, 8)
from ranked_profiles as ranked
where profile.id = ranked.id
  and ranked.row_number > 1;
create unique index if not exists profiles_mobile_normalized_unique_idx
on public.profiles (
  regexp_replace(mobile_number, '[^0-9]', '', 'g')
)
where length(regexp_replace(mobile_number, '[^0-9]', '', 'g')) > 0;
