-- Merch drops: catalog, tags, reservations, admin + customer RPCs

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table if not exists public.merch_tags (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  label text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger merch_tags_set_updated_at
before update on public.merch_tags
for each row execute function public.set_updated_at();

create table if not exists public.merch_drops (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  description text,
  hero_image_url text,
  launch_at timestamptz not null,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger merch_drops_set_updated_at
before update on public.merch_drops
for each row execute function public.set_updated_at();

create table if not exists public.merch_items (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  description text,
  image_url text,
  price_cents integer check (price_cents is null or price_cents >= 0),
  points_required integer check (points_required is null or points_required >= 0),
  quantity_total integer not null check (quantity_total >= 0),
  quantity_remaining integer not null check (quantity_remaining >= 0),
  drop_id uuid references public.merch_drops (id) on delete set null,
  highlight_tag_id uuid references public.merch_tags (id) on delete set null,
  launch_at timestamptz,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint merch_items_quantity_consistency check (quantity_remaining <= quantity_total)
);

create index if not exists merch_items_drop_id_idx on public.merch_items (drop_id);
create index if not exists merch_items_active_sort_idx on public.merch_items (is_active, sort_order);

create trigger merch_items_set_updated_at
before update on public.merch_items
for each row execute function public.set_updated_at();

create table if not exists public.merch_item_tags (
  item_id uuid not null references public.merch_items (id) on delete cascade,
  tag_id uuid not null references public.merch_tags (id) on delete cascade,
  primary key (item_id, tag_id)
);

create table if not exists public.merch_reservations (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  item_id uuid not null references public.merch_items (id) on delete restrict,
  claim_code text not null,
  points_spent integer not null default 0 check (points_spent >= 0),
  status text not null default 'reserved'
    check (status in ('reserved', 'fulfilled', 'cancelled')),
  reserved_at timestamptz not null default now(),
  fulfilled_at timestamptz,
  fulfilled_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists merch_reservations_claim_code_uidx
  on public.merch_reservations (claim_code);

create unique index if not exists merch_reservations_one_open_per_member_item
  on public.merch_reservations (profile_id, item_id)
  where status = 'reserved';

create index if not exists merch_reservations_profile_status_idx
  on public.merch_reservations (profile_id, status, reserved_at desc);

create trigger merch_reservations_set_updated_at
before update on public.merch_reservations
for each row execute function public.set_updated_at();

alter table public.merch_tags enable row level security;
alter table public.merch_drops enable row level security;
alter table public.merch_items enable row level security;
alter table public.merch_item_tags enable row level security;
alter table public.merch_reservations enable row level security;

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

create or replace function public.merch_item_effective_launch_at(
  p_item_launch_at timestamptz,
  p_drop_launch_at timestamptz
)
returns timestamptz
language sql
immutable
as $$
  select coalesce(p_item_launch_at, p_drop_launch_at);
$$;

create or replace function public.merch_is_launched(p_launch_at timestamptz)
returns boolean
language sql
stable
as $$
  select p_launch_at is null or p_launch_at <= now();
$$;

create or replace function public.generate_merch_claim_code()
returns text
language plpgsql
as $$
declare
  v_code text;
  v_exists boolean;
begin
  loop
    v_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
    select exists(
      select 1 from public.merch_reservations where claim_code = v_code
    ) into v_exists;
    exit when not v_exists;
  end loop;
  return v_code;
end;
$$;

create or replace function public.assert_staff_access()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text;
begin
  select staff_role into v_role from public.profiles where id = auth.uid();
  if v_role is null then
    raise exception 'Staff access required';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Customer reads
-- ---------------------------------------------------------------------------

create or replace function public.list_merch_catalog()
returns table (
  id uuid,
  slug text,
  name text,
  description text,
  image_url text,
  price_cents integer,
  points_required integer,
  quantity_remaining integer,
  drop_id uuid,
  drop_slug text,
  drop_name text,
  highlight_tag_label text,
  launch_at timestamptz,
  is_launched boolean,
  is_tease boolean,
  sort_order integer
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  return query
  select
    i.id,
    i.slug,
    i.name,
    i.description,
    i.image_url,
    i.price_cents,
    nullif(i.points_required, 0),
    i.quantity_remaining,
    i.drop_id,
    d.slug,
    d.name,
    t.label,
    public.merch_item_effective_launch_at(i.launch_at, d.launch_at),
    public.merch_is_launched(public.merch_item_effective_launch_at(i.launch_at, d.launch_at)),
    not public.merch_is_launched(public.merch_item_effective_launch_at(i.launch_at, d.launch_at)),
    i.sort_order
  from public.merch_items i
  left join public.merch_drops d on d.id = i.drop_id and d.is_active
  left join public.merch_tags t on t.id = i.highlight_tag_id and t.is_active
  where i.is_active
    and (i.drop_id is null or d.id is not null)
  order by
    public.merch_is_launched(public.merch_item_effective_launch_at(i.launch_at, d.launch_at)) desc,
    i.sort_order asc,
    i.name asc;
end;
$$;

create or replace function public.list_merch_drops_coming_soon()
returns table (
  id uuid,
  slug text,
  name text,
  description text,
  hero_image_url text,
  launch_at timestamptz,
  sort_order integer
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  return query
  select d.id, d.slug, d.name, d.description, d.hero_image_url, d.launch_at, d.sort_order
  from public.merch_drops d
  where d.is_active
    and d.launch_at > now()
  order by d.launch_at asc, d.sort_order asc;
end;
$$;

create or replace function public.get_merch_drop(p_slug text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_drop public.merch_drops%rowtype;
  v_launched boolean;
  v_items jsonb;
begin
  select * into v_drop
  from public.merch_drops
  where slug = trim(p_slug) and is_active;

  if not found then
    return null;
  end if;

  v_launched := public.merch_is_launched(v_drop.launch_at);

  select coalesce(jsonb_agg(row_to_json(x)::jsonb order by x.sort_order, x.name), '[]'::jsonb)
  into v_items
  from (
    select
      i.id,
      i.slug,
      i.name,
      i.description,
      i.image_url,
      i.price_cents,
      nullif(i.points_required, 0) as points_required,
      i.quantity_remaining,
      t.label as highlight_tag_label,
      public.merch_item_effective_launch_at(i.launch_at, v_drop.launch_at) as launch_at,
      public.merch_is_launched(public.merch_item_effective_launch_at(i.launch_at, v_drop.launch_at)) as is_launched,
      not public.merch_is_launched(public.merch_item_effective_launch_at(i.launch_at, v_drop.launch_at)) as is_tease,
      i.sort_order
    from public.merch_items i
    left join public.merch_tags t on t.id = i.highlight_tag_id and t.is_active
    where i.drop_id = v_drop.id and i.is_active
  ) x;

  return jsonb_build_object(
    'id', v_drop.id,
    'slug', v_drop.slug,
    'name', v_drop.name,
    'description', v_drop.description,
    'heroImageUrl', v_drop.hero_image_url,
    'launchAt', v_drop.launch_at,
    'isLaunched', v_launched,
    'isTease', not v_launched,
    'sortOrder', v_drop.sort_order,
    'items', v_items
  );
end;
$$;

create or replace function public.get_merch_item(p_slug text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_item public.merch_items%rowtype;
  v_drop public.merch_drops%rowtype;
  v_launch timestamptz;
  v_launched boolean;
  v_tags jsonb;
  v_highlight text;
  v_reservation jsonb;
begin
  select * into v_item
  from public.merch_items
  where slug = trim(p_slug) and is_active;

  if not found then
    return null;
  end if;

  if v_item.drop_id is not null then
    select * into v_drop from public.merch_drops where id = v_item.drop_id;
    if v_drop.id is null or not v_drop.is_active then
      return null;
    end if;
  end if;

  v_launch := public.merch_item_effective_launch_at(v_item.launch_at, v_drop.launch_at);
  v_launched := public.merch_is_launched(v_launch);

  select t.label into v_highlight
  from public.merch_tags t
  where t.id = v_item.highlight_tag_id and t.is_active;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', t.id,
    'slug', t.slug,
    'label', t.label,
    'isHighlight', t.id = v_item.highlight_tag_id
  ) order by t.label), '[]'::jsonb)
  into v_tags
  from public.merch_item_tags mit
  join public.merch_tags t on t.id = mit.tag_id and t.is_active
  where mit.item_id = v_item.id;

  if auth.uid() is not null then
    select jsonb_build_object(
      'id', r.id,
      'claimCode', r.claim_code,
      'status', r.status,
      'pointsSpent', r.points_spent,
      'reservedAt', r.reserved_at
    )
    into v_reservation
    from public.merch_reservations r
    where r.profile_id = auth.uid()
      and r.item_id = v_item.id
      and r.status = 'reserved'
    order by r.reserved_at desc
    limit 1;
  end if;

  return jsonb_build_object(
    'id', v_item.id,
    'slug', v_item.slug,
    'name', v_item.name,
    'description', v_item.description,
    'imageUrl', v_item.image_url,
    'priceCents', v_item.price_cents,
    'pointsRequired', nullif(v_item.points_required, 0),
    'quantityRemaining', v_item.quantity_remaining,
    'quantityTotal', v_item.quantity_total,
    'dropId', v_item.drop_id,
    'dropSlug', v_drop.slug,
    'dropName', v_drop.name,
    'highlightTagLabel', v_highlight,
    'tags', v_tags,
    'launchAt', v_launch,
    'isLaunched', v_launched,
    'isTease', not v_launched,
    'sortOrder', v_item.sort_order,
    'myReservation', v_reservation
  );
end;
$$;

create or replace function public.list_my_merch_reservations()
returns table (
  id uuid,
  item_id uuid,
  item_slug text,
  item_name text,
  item_image_url text,
  claim_code text,
  points_spent integer,
  status text,
  reserved_at timestamptz,
  fulfilled_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  return query
  select
    r.id,
    r.item_id,
    i.slug,
    i.name,
    i.image_url,
    r.claim_code,
    r.points_spent,
    r.status,
    r.reserved_at,
    r.fulfilled_at
  from public.merch_reservations r
  join public.merch_items i on i.id = r.item_id
  where r.profile_id = auth.uid()
  order by r.reserved_at desc;
end;
$$;

create or replace function public.list_member_merch_reservations(p_profile_id uuid)
returns table (
  id uuid,
  item_id uuid,
  item_slug text,
  item_name text,
  item_image_url text,
  claim_code text,
  points_spent integer,
  status text,
  reserved_at timestamptz,
  fulfilled_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform public.assert_staff_access();

  return query
  select
    r.id,
    r.item_id,
    i.slug,
    i.name,
    i.image_url,
    r.claim_code,
    r.points_spent,
    r.status,
    r.reserved_at,
    r.fulfilled_at
  from public.merch_reservations r
  join public.merch_items i on i.id = r.item_id
  where r.profile_id = p_profile_id
  order by
    case when r.status = 'reserved' then 0 else 1 end,
    r.reserved_at desc;
end;
$$;

-- ---------------------------------------------------------------------------
-- Reserve / fulfill
-- ---------------------------------------------------------------------------

create or replace function public.reserve_merch_item(p_item_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_profile_id uuid := auth.uid();
  v_item public.merch_items%rowtype;
  v_drop_launch timestamptz;
  v_drop_found boolean := false;
  v_launch timestamptz;
  v_points integer;
  v_code text;
  v_reservation_id uuid;
begin
  if v_profile_id is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_item
  from public.merch_items
  where id = p_item_id
  for update;

  if not found or not v_item.is_active then
    raise exception 'Merch item not found';
  end if;

  if v_item.drop_id is not null then
    select launch_at into v_drop_launch
    from public.merch_drops
    where id = v_item.drop_id and is_active;
    if not found then
      raise exception 'Merch drop not available';
    end if;
    v_drop_found := true;
  end if;

  v_launch := public.merch_item_effective_launch_at(v_item.launch_at, v_drop_launch);
  if not public.merch_is_launched(v_launch) then
    raise exception 'Merch item is not available yet';
  end if;

  if v_item.quantity_remaining <= 0 then
    raise exception 'Merch item is sold out';
  end if;

  if exists (
    select 1 from public.merch_reservations
    where profile_id = v_profile_id and item_id = v_item.id and status = 'reserved'
  ) then
    raise exception 'You already have a reservation for this item';
  end if;

  v_points := coalesce(nullif(v_item.points_required, 0), 0);

  if v_points > 0 then
    perform public.apply_reward_transaction(
      v_profile_id,
      -v_points,
      'redeem',
      'Merch reservation: ' || v_item.name,
      null,
      jsonb_build_object('merch_item_id', v_item.id, 'merch_slug', v_item.slug)
    );
  end if;

  update public.merch_items
  set quantity_remaining = quantity_remaining - 1,
      updated_at = now()
  where id = v_item.id;

  v_code := public.generate_merch_claim_code();

  insert into public.merch_reservations (
    profile_id, item_id, claim_code, points_spent, status
  ) values (
    v_profile_id, v_item.id, v_code, v_points, 'reserved'
  )
  returning id into v_reservation_id;

  return jsonb_build_object(
    'id', v_reservation_id,
    'claimCode', v_code,
    'pointsSpent', v_points,
    'status', 'reserved',
    'itemId', v_item.id,
    'itemSlug', v_item.slug,
    'itemName', v_item.name
  );
end;
$$;

create or replace function public.fulfill_merch_reservation(p_reservation_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reservation public.merch_reservations%rowtype;
begin
  perform public.assert_staff_access();

  select * into v_reservation
  from public.merch_reservations
  where id = p_reservation_id
  for update;

  if not found then
    raise exception 'Reservation not found';
  end if;

  if v_reservation.status is distinct from 'reserved' then
    raise exception 'Reservation is not open';
  end if;

  update public.merch_reservations
  set
    status = 'fulfilled',
    fulfilled_at = now(),
    fulfilled_by = auth.uid(),
    updated_at = now()
  where id = p_reservation_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Admin: tags
-- ---------------------------------------------------------------------------

create or replace function public.list_merch_tags_admin()
returns setof public.merch_tags
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform public.assert_admin_access();
  return query
  select * from public.merch_tags
  order by label asc;
end;
$$;

create or replace function public.upsert_merch_tag_admin(
  p_id uuid default null,
  p_slug text default null,
  p_label text default null,
  p_is_active boolean default true
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_slug text;
begin
  perform public.assert_admin_access();

  if p_slug is null or trim(p_slug) = '' then
    raise exception 'Slug is required';
  end if;
  if p_label is null or trim(p_label) = '' then
    raise exception 'Label is required';
  end if;

  v_slug := lower(trim(p_slug));

  if p_id is null then
    insert into public.merch_tags (slug, label, is_active)
    values (v_slug, trim(p_label), coalesce(p_is_active, true))
    returning id into v_id;
  else
    update public.merch_tags
    set
      slug = v_slug,
      label = trim(p_label),
      is_active = coalesce(p_is_active, true),
      updated_at = now()
    where id = p_id
    returning id into v_id;
    if v_id is null then
      raise exception 'Merch tag not found';
    end if;
  end if;

  return v_id;
end;
$$;

create or replace function public.delete_merch_tag_admin(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.assert_admin_access();
  delete from public.merch_tags where id = p_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Admin: drops
-- ---------------------------------------------------------------------------

create or replace function public.list_merch_drops_admin()
returns setof public.merch_drops
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform public.assert_admin_access();
  return query
  select * from public.merch_drops
  order by sort_order asc, launch_at desc;
end;
$$;

create or replace function public.upsert_merch_drop_admin(
  p_id uuid default null,
  p_slug text default null,
  p_name text default null,
  p_description text default null,
  p_hero_image_url text default null,
  p_launch_at timestamptz default null,
  p_is_active boolean default true,
  p_sort_order integer default 0
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_slug text;
begin
  perform public.assert_admin_access();

  if p_slug is null or trim(p_slug) = '' then
    raise exception 'Slug is required';
  end if;
  if p_name is null or trim(p_name) = '' then
    raise exception 'Name is required';
  end if;
  if p_launch_at is null then
    raise exception 'Launch time is required';
  end if;

  v_slug := lower(trim(p_slug));

  if p_id is null then
    insert into public.merch_drops (
      slug, name, description, hero_image_url, launch_at, is_active, sort_order
    ) values (
      v_slug, trim(p_name), nullif(trim(coalesce(p_description, '')), ''),
      nullif(trim(coalesce(p_hero_image_url, '')), ''), p_launch_at,
      coalesce(p_is_active, true), coalesce(p_sort_order, 0)
    )
    returning id into v_id;
  else
    update public.merch_drops
    set
      slug = v_slug,
      name = trim(p_name),
      description = nullif(trim(coalesce(p_description, '')), ''),
      hero_image_url = nullif(trim(coalesce(p_hero_image_url, '')), ''),
      launch_at = p_launch_at,
      is_active = coalesce(p_is_active, true),
      sort_order = coalesce(p_sort_order, 0),
      updated_at = now()
    where id = p_id
    returning id into v_id;
    if v_id is null then
      raise exception 'Merch drop not found';
    end if;
  end if;

  return v_id;
end;
$$;

create or replace function public.delete_merch_drop_admin(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.assert_admin_access();
  update public.merch_items set drop_id = null where drop_id = p_id;
  delete from public.merch_drops where id = p_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Admin: items
-- ---------------------------------------------------------------------------

create or replace function public.list_merch_items_admin()
returns table (
  id uuid,
  slug text,
  name text,
  description text,
  image_url text,
  price_cents integer,
  points_required integer,
  quantity_total integer,
  quantity_remaining integer,
  drop_id uuid,
  drop_name text,
  highlight_tag_id uuid,
  launch_at timestamptz,
  is_active boolean,
  sort_order integer,
  tag_ids uuid[],
  created_at timestamptz,
  updated_at timestamptz
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
    i.id,
    i.slug,
    i.name,
    i.description,
    i.image_url,
    i.price_cents,
    i.points_required,
    i.quantity_total,
    i.quantity_remaining,
    i.drop_id,
    d.name,
    i.highlight_tag_id,
    i.launch_at,
    i.is_active,
    i.sort_order,
    coalesce(
      (select array_agg(mit.tag_id order by mit.tag_id) from public.merch_item_tags mit where mit.item_id = i.id),
      '{}'::uuid[]
    ),
    i.created_at,
    i.updated_at
  from public.merch_items i
  left join public.merch_drops d on d.id = i.drop_id
  order by i.sort_order asc, i.name asc;
end;
$$;

create or replace function public.upsert_merch_item_admin(
  p_id uuid default null,
  p_slug text default null,
  p_name text default null,
  p_description text default null,
  p_image_url text default null,
  p_price_cents integer default null,
  p_points_required integer default null,
  p_quantity_total integer default null,
  p_quantity_remaining integer default null,
  p_drop_id uuid default null,
  p_highlight_tag_id uuid default null,
  p_launch_at timestamptz default null,
  p_is_active boolean default true,
  p_sort_order integer default 0,
  p_tag_ids uuid[] default '{}'::uuid[]
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_slug text;
  v_total integer;
  v_remaining integer;
  v_old_remaining integer;
  v_tag_id uuid;
begin
  perform public.assert_admin_access();

  if p_slug is null or trim(p_slug) = '' then
    raise exception 'Slug is required';
  end if;
  if p_name is null or trim(p_name) = '' then
    raise exception 'Name is required';
  end if;
  if p_quantity_total is null or p_quantity_total < 0 then
    raise exception 'Quantity total must be zero or greater';
  end if;

  v_slug := lower(trim(p_slug));
  v_total := p_quantity_total;

  if p_id is null then
    v_remaining := coalesce(p_quantity_remaining, v_total);
    if v_remaining < 0 or v_remaining > v_total then
      raise exception 'Quantity remaining must be between 0 and total';
    end if;

    insert into public.merch_items (
      slug, name, description, image_url, price_cents, points_required,
      quantity_total, quantity_remaining, drop_id, highlight_tag_id,
      launch_at, is_active, sort_order
    ) values (
      v_slug, trim(p_name), nullif(trim(coalesce(p_description, '')), ''),
      nullif(trim(coalesce(p_image_url, '')), ''), p_price_cents,
      nullif(p_points_required, 0), v_total, v_remaining, p_drop_id,
      p_highlight_tag_id, p_launch_at, coalesce(p_is_active, true),
      coalesce(p_sort_order, 0)
    )
    returning id into v_id;
  else
    select quantity_remaining into v_old_remaining
    from public.merch_items where id = p_id;
    if not found then
      raise exception 'Merch item not found';
    end if;

    v_remaining := coalesce(p_quantity_remaining, least(v_old_remaining, v_total));
    if v_remaining < 0 or v_remaining > v_total then
      raise exception 'Quantity remaining must be between 0 and total';
    end if;

    update public.merch_items
    set
      slug = v_slug,
      name = trim(p_name),
      description = nullif(trim(coalesce(p_description, '')), ''),
      image_url = nullif(trim(coalesce(p_image_url, '')), ''),
      price_cents = p_price_cents,
      points_required = nullif(p_points_required, 0),
      quantity_total = v_total,
      quantity_remaining = v_remaining,
      drop_id = p_drop_id,
      highlight_tag_id = p_highlight_tag_id,
      launch_at = p_launch_at,
      is_active = coalesce(p_is_active, true),
      sort_order = coalesce(p_sort_order, 0),
      updated_at = now()
    where id = p_id
    returning id into v_id;
  end if;

  if p_highlight_tag_id is not null
     and not (p_highlight_tag_id = any (coalesce(p_tag_ids, '{}'::uuid[]))) then
    raise exception 'Highlight tag must be one of the selected tags';
  end if;

  delete from public.merch_item_tags where item_id = v_id;

  if p_tag_ids is not null then
    foreach v_tag_id in array p_tag_ids loop
      insert into public.merch_item_tags (item_id, tag_id)
      values (v_id, v_tag_id)
      on conflict do nothing;
    end loop;
  end if;

  return v_id;
end;
$$;

create or replace function public.delete_merch_item_admin(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.assert_admin_access();
  if exists (
    select 1 from public.merch_reservations
    where item_id = p_id and status = 'reserved'
  ) then
    raise exception 'Cannot delete item with open reservations';
  end if;
  delete from public.merch_items where id = p_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

grant execute on function public.assert_staff_access() to authenticated;
grant execute on function public.list_merch_catalog() to authenticated;
grant execute on function public.list_merch_drops_coming_soon() to authenticated;
grant execute on function public.get_merch_drop(text) to authenticated;
grant execute on function public.get_merch_item(text) to authenticated;
grant execute on function public.list_my_merch_reservations() to authenticated;
grant execute on function public.list_member_merch_reservations(uuid) to authenticated;
grant execute on function public.reserve_merch_item(uuid) to authenticated;
grant execute on function public.fulfill_merch_reservation(uuid) to authenticated;
grant execute on function public.list_merch_tags_admin() to authenticated;
grant execute on function public.upsert_merch_tag_admin(uuid, text, text, boolean) to authenticated;
grant execute on function public.delete_merch_tag_admin(uuid) to authenticated;
grant execute on function public.list_merch_drops_admin() to authenticated;
grant execute on function public.upsert_merch_drop_admin(uuid, text, text, text, text, timestamptz, boolean, integer) to authenticated;
grant execute on function public.delete_merch_drop_admin(uuid) to authenticated;
grant execute on function public.list_merch_items_admin() to authenticated;
grant execute on function public.upsert_merch_item_admin(uuid, text, text, text, text, integer, integer, integer, integer, uuid, uuid, timestamptz, boolean, integer, uuid[]) to authenticated;
grant execute on function public.delete_merch_item_admin(uuid) to authenticated;
