-- Staff management: profile flags, store assignment, avatars storage

alter table public.profiles
  add column if not exists must_change_password boolean not null default false,
  add column if not exists is_profile_completed boolean not null default true,
  add column if not exists is_active boolean not null default true,
  add column if not exists avatar_url text,
  add column if not exists assigned_store_id uuid references public.stores (id) on delete set null,
  add column if not exists staff_role text check (staff_role is null or staff_role in ('staff', 'admin'));
create index if not exists profiles_staff_role_idx on public.profiles (staff_role)
  where staff_role is not null;
create index if not exists profiles_assigned_store_id_idx on public.profiles (assigned_store_id)
  where assigned_store_id is not null;
-- Keep existing members marked as completed
update public.profiles
set
  is_profile_completed = true,
  must_change_password = false
where staff_role is null;
-- Avatars bucket (public read)
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;
create policy "Avatar images are publicly accessible"
on storage.objects
for select
to public
using (bucket_id = 'avatars');
create policy "Users can upload their own avatar"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);
create policy "Users can update their own avatar"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);
create policy "Users can delete their own avatar"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);
-- Extend signup trigger for staff onboarding defaults
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
    staff_role
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
    nullif(new.raw_user_meta_data->>'staff_role', '')
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
-- List staff members for admin console
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
  created_at timestamptz
)
language sql
stable
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
    p.created_at
  from public.profiles p
  left join public.stores s on s.id = p.assigned_store_id
  where p.staff_role is not null
  order by p.created_at desc;
$$;
grant execute on function public.list_staff_members() to anon, authenticated, service_role;
