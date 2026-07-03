-- Admin customer list: completed member accounts only (exclude staff and incomplete signups)

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
  order by p.created_at desc;
end;
$$;
grant execute on function public.list_customers() to authenticated;
