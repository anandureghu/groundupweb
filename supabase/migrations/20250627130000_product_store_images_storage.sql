-- Product and store image storage buckets (admin upload, public read)

insert into storage.buckets (id, name, public)
values
  ('products', 'products', true),
  ('stores', 'stores', true)
on conflict (id) do nothing;
create policy "Product images are publicly accessible"
on storage.objects
for select
to public
using (bucket_id = 'products');
create policy "Store images are publicly accessible"
on storage.objects
for select
to public
using (bucket_id = 'stores');
create policy "Admins can upload product images"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'products'
  and exists (
    select 1
    from public.profiles
    where id = auth.uid() and staff_role = 'admin'
  )
);
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
);
create policy "Admins can delete product images"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'products'
  and exists (
    select 1
    from public.profiles
    where id = auth.uid() and staff_role = 'admin'
  )
);
create policy "Admins can upload store images"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'stores'
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
);
create policy "Admins can delete store images"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'stores'
  and exists (
    select 1
    from public.profiles
    where id = auth.uid() and staff_role = 'admin'
  )
);
