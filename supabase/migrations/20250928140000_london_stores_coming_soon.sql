-- London stores: add coming_soon status and replace NYC seed locations
-- Mirrored from app/supabase/migrations/20250928140000_london_stores_coming_soon.sql

alter table public.stores
  drop constraint if exists stores_status_check;

alter table public.stores
  add constraint stores_status_check
  check (status in ('open', 'closing_soon', 'closed', 'coming_soon'));

alter table public.stores
  alter column city set default 'London';

alter table public.stores
  alter column state set default 'England';

update public.stores
set is_active = false,
    updated_at = now()
where slug in (
  'groundup-soho',
  'groundup-williamsburg',
  'groundup-west-village'
);

insert into public.stores (
  id,
  name,
  slug,
  neighborhood,
  address_line1,
  city,
  state,
  postal_code,
  latitude,
  longitude,
  google_maps_url,
  status,
  opens_at,
  closes_at,
  image_url,
  is_active
)
values
  (
    'b2000000-0000-4000-8000-000000000001',
    'Groundup Green Street',
    'groundup-green-street',
    'Green Street, Newham',
    '125 Green Street',
    'London',
    'England',
    'E7 8JF',
    51.5441324,
    0.0324762,
    'https://maps.app.goo.gl/kRoBCRZZGJHvY33X7?g_st=ic',
    'open',
    '07:00',
    '19:00',
    'https://images.unsplash.com/photo-1493857671505-729ba8a9607b?auto=format&fit=crop&w=600&q=80',
    true
  ),
  (
    'b2000000-0000-4000-8000-000000000002',
    'Groundup York Way',
    'groundup-york-way',
    'York Way, Islington',
    '394 York Way',
    'London',
    'England',
    'N7 9LW',
    51.5484816,
    -0.1279875,
    'https://maps.app.goo.gl/4Fn2EYJHYh4YSJ3r6?g_st=ic',
    'open',
    '07:00',
    '19:00',
    'https://images.unsplash.com/photo-1554118811-1e0d58224f24?auto=format&fit=crop&w=600&q=80',
    true
  ),
  (
    'b2000000-0000-4000-8000-000000000003',
    'Groundup Gants Hill',
    'groundup-gants-hill',
    'Gants Hill',
    null,
    'London',
    'England',
    null,
    51.5765250,
    0.0648799,
    null,
    'coming_soon',
    null,
    null,
    'https://images.unsplash.com/photo-1501339846605-531ba89a99e0?auto=format&fit=crop&w=600&q=80',
    true
  ),
  (
    'b2000000-0000-4000-8000-000000000004',
    'Groundup Bradford',
    'groundup-bradford',
    'Bradford',
    null,
    'Bradford',
    'England',
    null,
    53.7944229,
    -1.7519186,
    null,
    'coming_soon',
    null,
    null,
    'https://images.unsplash.com/photo-1442512595331-e89e73853f31?auto=format&fit=crop&w=600&q=80',
    true
  ),
  (
    'b2000000-0000-4000-8000-000000000005',
    'Groundup Kilburn',
    'groundup-kilburn',
    'Kilburn',
    null,
    'London',
    'England',
    null,
    51.5418820,
    -0.1979358,
    null,
    'coming_soon',
    null,
    null,
    'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?auto=format&fit=crop&w=600&q=80',
    true
  ),
  (
    'b2000000-0000-4000-8000-000000000006',
    'Groundup Whitechapel',
    'groundup-whitechapel',
    'Whitechapel',
    null,
    'London',
    'England',
    null,
    51.5174861,
    -0.0659685,
    null,
    'coming_soon',
    null,
    null,
    'https://images.unsplash.com/photo-1509042239860-f550ce710b93?auto=format&fit=crop&w=600&q=80',
    true
  )
on conflict (id) do update set
  name = excluded.name,
  slug = excluded.slug,
  neighborhood = excluded.neighborhood,
  address_line1 = excluded.address_line1,
  city = excluded.city,
  state = excluded.state,
  postal_code = excluded.postal_code,
  latitude = excluded.latitude,
  longitude = excluded.longitude,
  google_maps_url = excluded.google_maps_url,
  status = excluded.status,
  opens_at = excluded.opens_at,
  closes_at = excluded.closes_at,
  image_url = excluded.image_url,
  is_active = true,
  updated_at = now();

update public.stores
set is_active = false,
    updated_at = now()
where slug in (
  'groundup-soho',
  'groundup-williamsburg',
  'groundup-west-village'
);
