-- Fix storage RLS for avatar upserts and admin product/store image uploads

-- Profiles: keep updates working for avatar_url (development uses open access)
alter table public.profiles disable row level security;
-- Avatars: recreate policies with explicit WITH CHECK (required for upsert/update)
drop policy if exists "Avatar images are publicly accessible" on storage.objects;
drop policy if exists "Users can upload their own avatar" on storage.objects;
drop policy if exists "Users can update their own avatar" on storage.objects;
drop policy if exists "Users can delete their own avatar" on storage.objects;
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
  and auth.uid() is not null
  and split_part(name, '/', 1) = auth.uid()::text
);
create policy "Users can update their own avatar"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'avatars'
  and auth.uid() is not null
  and split_part(name, '/', 1) = auth.uid()::text
)
with check (
  bucket_id = 'avatars'
  and auth.uid() is not null
  and split_part(name, '/', 1) = auth.uid()::text
);
create policy "Users can delete their own avatar"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'avatars'
  and auth.uid() is not null
  and split_part(name, '/', 1) = auth.uid()::text
);
-- Products / stores: add WITH CHECK on update (upsert)
drop policy if exists "Admins can update product images" on storage.objects;
drop policy if exists "Admins can update store images" on storage.objects;
create policy "Admins can update product images"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'products'
  and exists (
    select 1
    from public.profiles
    where id = auth.uid() and staff_role = 'admin'
  )
)
with check (
  bucket_id = 'products'
  and exists (
    select 1
    from public.profiles
    where id = auth.uid() and staff_role = 'admin'
  )
);
create policy "Admins can update store images"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'stores'
  and exists (
    select 1
    from public.profiles
    where id = auth.uid() and staff_role = 'admin'
  )
)
with check (
  bucket_id = 'stores'
  and exists (
    select 1
    from public.profiles
    where id = auth.uid() and staff_role = 'admin'
  )
);
