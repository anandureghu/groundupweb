-- Admin-configurable marketing banners for slider and timed popup placements

create table public.marketing_banners (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  placement text not null check (placement in ('home_slider', 'home_popup')),
  title text not null,
  subtitle text,
  image_url text,
  detail_title text,
  detail_body text,
  detail_image_url text,
  cta_label text,
  cta_href text,
  popup_delay_seconds integer check (popup_delay_seconds is null or popup_delay_seconds >= 0),
  starts_at timestamptz,
  ends_at timestamptz,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index marketing_banners_placement_idx
  on public.marketing_banners (placement, is_active, sort_order);
create trigger marketing_banners_set_updated_at
before update on public.marketing_banners
for each row
execute function public.set_updated_at();
create or replace function public.is_marketing_banner_active(p_banner public.marketing_banners)
returns boolean
language sql
stable
as $$
  select
    p_banner.is_active
    and (p_banner.starts_at is null or now() >= p_banner.starts_at)
    and (p_banner.ends_at is null or now() <= p_banner.ends_at);
$$;
create or replace function public.get_active_marketing_banners(p_placement text)
returns setof public.marketing_banners
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if p_placement not in ('home_slider', 'home_popup') then
    raise exception 'Invalid banner placement: %', p_placement;
  end if;

  return query
  select *
  from public.marketing_banners b
  where b.placement = p_placement
    and public.is_marketing_banner_active(b)
  order by b.sort_order, b.created_at;
end;
$$;
create or replace function public.validate_banner_slug(p_slug text)
returns text
language plpgsql
immutable
as $$
declare
  v_slug text;
begin
  v_slug := lower(trim(p_slug));

  if v_slug = '' then
    raise exception 'Slug is required';
  end if;

  if v_slug !~ '^[a-z0-9]+(-[a-z0-9]+)*$' then
    raise exception 'Slug must use lowercase letters, numbers, and hyphens only';
  end if;

  return v_slug;
end;
$$;
create or replace function public.validate_banner_placement(p_placement text)
returns text
language plpgsql
immutable
as $$
begin
  if p_placement not in ('home_slider', 'home_popup') then
    raise exception 'Invalid banner placement: %', p_placement;
  end if;

  return p_placement;
end;
$$;
create or replace function public.list_marketing_banners_admin()
returns setof public.marketing_banners
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform public.assert_admin_access();

  return query
  select *
  from public.marketing_banners
  order by placement, sort_order, created_at;
end;
$$;
create or replace function public.upsert_marketing_banner_admin(
  p_id uuid default null,
  p_slug text default null,
  p_placement text default null,
  p_title text default null,
  p_subtitle text default null,
  p_image_url text default null,
  p_detail_title text default null,
  p_detail_body text default null,
  p_detail_image_url text default null,
  p_cta_label text default null,
  p_cta_href text default null,
  p_popup_delay_seconds integer default null,
  p_starts_at timestamptz default null,
  p_ends_at timestamptz default null,
  p_is_active boolean default true,
  p_sort_order integer default 0
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_slug text;
  v_placement text;
  v_title text;
  v_id uuid;
begin
  perform public.assert_admin_access();

  v_slug := public.validate_banner_slug(p_slug);
  v_placement := public.validate_banner_placement(p_placement);
  v_title := trim(p_title);

  if v_title = '' then
    raise exception 'Title is required';
  end if;

  if v_placement = 'home_popup' and (p_popup_delay_seconds is null or p_popup_delay_seconds < 0) then
    raise exception 'Popup banners require a non-negative popup delay in seconds';
  end if;

  if p_sort_order is null or p_sort_order < 0 then
    raise exception 'Sort order must be zero or greater';
  end if;

  if p_starts_at is not null and p_ends_at is not null and p_ends_at <= p_starts_at then
    raise exception 'End date must be after start date';
  end if;

  if p_id is null then
    insert into public.marketing_banners (
      slug,
      placement,
      title,
      subtitle,
      image_url,
      detail_title,
      detail_body,
      detail_image_url,
      cta_label,
      cta_href,
      popup_delay_seconds,
      starts_at,
      ends_at,
      is_active,
      sort_order
    )
    values (
      v_slug,
      v_placement,
      v_title,
      nullif(trim(coalesce(p_subtitle, '')), ''),
      nullif(trim(coalesce(p_image_url, '')), ''),
      nullif(trim(coalesce(p_detail_title, '')), ''),
      nullif(trim(coalesce(p_detail_body, '')), ''),
      nullif(trim(coalesce(p_detail_image_url, '')), ''),
      nullif(trim(coalesce(p_cta_label, '')), ''),
      nullif(trim(coalesce(p_cta_href, '')), ''),
      p_popup_delay_seconds,
      p_starts_at,
      p_ends_at,
      coalesce(p_is_active, true),
      p_sort_order
    )
    returning id into v_id;
  else
    update public.marketing_banners
    set
      slug = v_slug,
      placement = v_placement,
      title = v_title,
      subtitle = nullif(trim(coalesce(p_subtitle, '')), ''),
      image_url = nullif(trim(coalesce(p_image_url, '')), ''),
      detail_title = nullif(trim(coalesce(p_detail_title, '')), ''),
      detail_body = nullif(trim(coalesce(p_detail_body, '')), ''),
      detail_image_url = nullif(trim(coalesce(p_detail_image_url, '')), ''),
      cta_label = nullif(trim(coalesce(p_cta_label, '')), ''),
      cta_href = nullif(trim(coalesce(p_cta_href, '')), ''),
      popup_delay_seconds = p_popup_delay_seconds,
      starts_at = p_starts_at,
      ends_at = p_ends_at,
      is_active = coalesce(p_is_active, true),
      sort_order = p_sort_order,
      updated_at = now()
    where id = p_id
    returning id into v_id;

    if v_id is null then
      raise exception 'Banner not found: %', p_id;
    end if;
  end if;

  return v_id;
end;
$$;
alter table public.marketing_banners enable row level security;
create policy marketing_banners_select_authenticated
  on public.marketing_banners
  for select
  to authenticated
  using (true);
grant select on table public.marketing_banners to authenticated;
grant execute on function public.get_active_marketing_banners(text) to authenticated;
grant execute on function public.list_marketing_banners_admin() to authenticated;
grant execute on function public.upsert_marketing_banner_admin(
  uuid,
  text,
  text,
  text,
  text,
  text,
  text,
  text,
  text,
  text,
  text,
  integer,
  timestamptz,
  timestamptz,
  boolean,
  integer
) to authenticated;
-- Banner image storage
insert into storage.buckets (id, name, public)
values ('banners', 'banners', true)
on conflict (id) do nothing;
create policy "Banner images are publicly accessible"
on storage.objects
for select
to public
using (bucket_id = 'banners');
create policy "Admins can upload banner images"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'banners'
  and exists (
    select 1
    from public.profiles
    where id = auth.uid() and staff_role = 'admin'
  )
);
create policy "Admins can update banner images"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'banners'
  and exists (
    select 1
    from public.profiles
    where id = auth.uid() and staff_role = 'admin'
  )
);
create policy "Admins can delete banner images"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'banners'
  and exists (
    select 1
    from public.profiles
    where id = auth.uid() and staff_role = 'admin'
  )
);
