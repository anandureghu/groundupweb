-- Store locator: Google Maps URL + coordinate backfill for seed stores

alter table public.stores
  add column if not exists google_maps_url text;
-- Backfill seed stores with coordinates and Google Maps links
update public.stores
set
  latitude = 40.724275,
  longitude = -74.001822,
  google_maps_url = 'https://www.google.com/maps/search/?api=1&query=40.724275,-74.001822'
where slug = 'groundup-soho';
update public.stores
set
  latitude = 40.714726,
  longitude = -73.961561,
  google_maps_url = 'https://www.google.com/maps/search/?api=1&query=40.714726,-73.961561'
where slug = 'groundup-williamsburg';
update public.stores
set
  latitude = 40.733761,
  longitude = -74.002876,
  google_maps_url = 'https://www.google.com/maps/search/?api=1&query=40.733761,-74.002876'
where slug = 'groundup-west-village';
