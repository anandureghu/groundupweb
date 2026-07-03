-- Coupon definitions, member wallet, redemptions, and staff order discounts

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table public.coupon_definitions (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  title text not null,
  description text not null default '',
  discount_type text not null check (discount_type in ('percent', 'fixed_amount')),
  discount_percent integer check (
    discount_percent is null or (discount_percent >= 1 and discount_percent <= 100)
  ),
  discount_amount_cents integer check (
    discount_amount_cents is null or discount_amount_cents > 0
  ),
  min_order_cents integer check (min_order_cents is null or min_order_cents >= 0),
  max_discount_cents integer check (max_discount_cents is null or max_discount_cents > 0),
  starts_at timestamptz,
  ends_at timestamptz,
  max_total_redemptions integer check (max_total_redemptions is null or max_total_redemptions > 0),
  per_member_max_uses integer not null default 1 check (per_member_max_uses > 0),
  validity_days_after_assign integer check (
    validity_days_after_assign is null or validity_days_after_assign > 0
  ),
  terms_content text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint coupon_definitions_discount_check check (
    (discount_type = 'percent' and discount_percent is not null and discount_amount_cents is null)
    or (
      discount_type = 'fixed_amount'
      and discount_amount_cents is not null
      and discount_percent is null
    )
  )
);
create index coupon_definitions_active_idx
  on public.coupon_definitions (is_active, starts_at, ends_at);
create trigger coupon_definitions_set_updated_at
before update on public.coupon_definitions
for each row
execute function public.set_updated_at();
create table public.member_coupons (
  id uuid primary key default gen_random_uuid(),
  coupon_definition_id uuid not null references public.coupon_definitions (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  assigned_at timestamptz not null default now(),
  assigned_by uuid references public.profiles (id) on delete set null,
  source_banner_id uuid references public.marketing_banners (id) on delete set null,
  expires_at timestamptz,
  times_used integer not null default 0 check (times_used >= 0),
  status text not null default 'active'
    check (status in ('active', 'used', 'expired', 'revoked')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index member_coupons_active_unique_idx
  on public.member_coupons (profile_id, coupon_definition_id)
  where status = 'active';
create index member_coupons_profile_status_idx
  on public.member_coupons (profile_id, status);
create trigger member_coupons_set_updated_at
before update on public.member_coupons
for each row
execute function public.set_updated_at();
create table public.coupon_redemptions (
  id uuid primary key default gen_random_uuid(),
  member_coupon_id uuid not null references public.member_coupons (id) on delete restrict,
  order_id uuid not null references public.orders (id) on delete restrict,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  discount_cents integer not null check (discount_cents > 0),
  redeemed_by uuid references public.profiles (id) on delete set null,
  snapshot jsonb not null default '{}'::jsonb,
  redeemed_at timestamptz not null default now()
);
create index coupon_redemptions_member_coupon_idx
  on public.coupon_redemptions (member_coupon_id);
create index coupon_redemptions_order_idx
  on public.coupon_redemptions (order_id);
create index coupon_redemptions_profile_idx
  on public.coupon_redemptions (profile_id);
-- ---------------------------------------------------------------------------
-- Orders + banners extensions
-- ---------------------------------------------------------------------------

alter table public.orders
  add column if not exists discount_cents integer not null default 0
    check (discount_cents >= 0),
  add column if not exists discount_type text
    check (discount_type is null or discount_type in ('coupon', 'manual_percent', 'manual_fixed')),
  add column if not exists discount_metadata jsonb not null default '{}'::jsonb,
  add column if not exists member_coupon_id uuid references public.member_coupons (id) on delete set null;
alter table public.marketing_banners
  add column if not exists coupon_definition_id uuid
    references public.coupon_definitions (id) on delete set null;
-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

create or replace function public.is_coupon_definition_active(p_coupon public.coupon_definitions)
returns boolean
language sql
stable
as $$
  select
    p_coupon.is_active
    and (p_coupon.starts_at is null or now() >= p_coupon.starts_at)
    and (p_coupon.ends_at is null or now() <= p_coupon.ends_at);
$$;
create or replace function public.compute_member_coupon_expires_at(
  p_definition public.coupon_definitions,
  p_assigned_at timestamptz
)
returns timestamptz
language plpgsql
immutable
as $$
declare
  v_expires_at timestamptz;
  v_member_expires timestamptz;
begin
  v_expires_at := p_definition.ends_at;

  if p_definition.validity_days_after_assign is not null then
    v_member_expires := p_assigned_at + make_interval(days => p_definition.validity_days_after_assign);

    if v_expires_at is null then
      v_expires_at := v_member_expires;
    elsif v_member_expires < v_expires_at then
      v_expires_at := v_member_expires;
    end if;
  end if;

  return v_expires_at;
end;
$$;
create or replace function public.is_member_coupon_usable(
  p_member_coupon public.member_coupons,
  p_definition public.coupon_definitions,
  p_payable_cents integer default 0
)
returns boolean
language plpgsql
stable
as $$
declare
  v_total_redemptions integer;
begin
  if p_member_coupon.status <> 'active' then
    return false;
  end if;

  if p_member_coupon.expires_at is not null and now() > p_member_coupon.expires_at then
    return false;
  end if;

  if p_member_coupon.times_used >= p_definition.per_member_max_uses then
    return false;
  end if;

  if not public.is_coupon_definition_active(p_definition) then
    return false;
  end if;

  if p_definition.min_order_cents is not null and p_payable_cents < p_definition.min_order_cents then
    return false;
  end if;

  if p_definition.max_total_redemptions is not null then
    select count(*)::integer
    into v_total_redemptions
    from public.coupon_redemptions cr
    join public.member_coupons mc on mc.id = cr.member_coupon_id
    where mc.coupon_definition_id = p_definition.id;

    if v_total_redemptions >= p_definition.max_total_redemptions then
      return false;
    end if;
  end if;

  return true;
end;
$$;
create or replace function public.calculate_coupon_discount_cents(
  p_definition public.coupon_definitions,
  p_payable_cents integer
)
returns integer
language plpgsql
immutable
as $$
declare
  v_discount integer;
begin
  if p_payable_cents <= 0 then
    return 0;
  end if;

  if p_definition.discount_type = 'percent' then
    v_discount := floor(p_payable_cents * p_definition.discount_percent::numeric / 100)::integer;

    if p_definition.max_discount_cents is not null then
      v_discount := least(v_discount, p_definition.max_discount_cents);
    end if;
  else
    v_discount := p_definition.discount_amount_cents;
  end if;

  return greatest(least(v_discount, p_payable_cents), 0);
end;
$$;
create or replace function public.validate_coupon_slug(p_slug text)
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
create or replace function public.recalculate_order_totals(p_order_id uuid)
returns void
language plpgsql
as $$
declare
  v_subtotal integer;
  v_tax integer;
  v_discount integer;
begin
  select coalesce(sum(line_total_cents), 0)
  into v_subtotal
  from public.order_items
  where order_id = p_order_id;

  select tax_cents, discount_cents
  into v_tax, v_discount
  from public.orders
  where id = p_order_id;

  update public.orders
  set
    subtotal_cents = v_subtotal,
    total_cents = greatest(v_subtotal - coalesce(v_discount, 0), 0) + coalesce(v_tax, 0),
    updated_at = now()
  where id = p_order_id;
end;
$$;
-- ---------------------------------------------------------------------------
-- Admin RPCs
-- ---------------------------------------------------------------------------

create or replace function public.list_coupons_admin()
returns setof public.coupon_definitions
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform public.assert_admin_access();

  return query
  select *
  from public.coupon_definitions
  order by created_at desc;
end;
$$;
create or replace function public.upsert_coupon_admin(
  p_id uuid default null,
  p_slug text default null,
  p_title text default null,
  p_description text default null,
  p_discount_type text default null,
  p_discount_percent integer default null,
  p_discount_amount_cents integer default null,
  p_min_order_cents integer default null,
  p_max_discount_cents integer default null,
  p_starts_at timestamptz default null,
  p_ends_at timestamptz default null,
  p_max_total_redemptions integer default null,
  p_per_member_max_uses integer default 1,
  p_validity_days_after_assign integer default null,
  p_terms_content text default null,
  p_is_active boolean default true
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_slug text;
  v_title text;
  v_terms text;
  v_id uuid;
begin
  perform public.assert_admin_access();

  v_slug := public.validate_coupon_slug(p_slug);
  v_title := trim(p_title);
  v_terms := trim(p_terms_content);

  if v_title = '' then
    raise exception 'Title is required';
  end if;

  if v_terms = '' then
    raise exception 'Terms and conditions are required';
  end if;

  if p_discount_type not in ('percent', 'fixed_amount') then
    raise exception 'Invalid discount type: %', p_discount_type;
  end if;

  if p_discount_type = 'percent' and (p_discount_percent is null or p_discount_percent < 1 or p_discount_percent > 100) then
    raise exception 'Percent coupons require a discount between 1 and 100';
  end if;

  if p_discount_type = 'fixed_amount' and (p_discount_amount_cents is null or p_discount_amount_cents <= 0) then
    raise exception 'Fixed amount coupons require a positive discount amount';
  end if;

  if p_starts_at is not null and p_ends_at is not null and p_ends_at <= p_starts_at then
    raise exception 'End date must be after start date';
  end if;

  if p_per_member_max_uses is null or p_per_member_max_uses < 1 then
    raise exception 'Per-member max uses must be at least 1';
  end if;

  if p_id is null then
    insert into public.coupon_definitions (
      slug,
      title,
      description,
      discount_type,
      discount_percent,
      discount_amount_cents,
      min_order_cents,
      max_discount_cents,
      starts_at,
      ends_at,
      max_total_redemptions,
      per_member_max_uses,
      validity_days_after_assign,
      terms_content,
      is_active
    )
    values (
      v_slug,
      v_title,
      coalesce(trim(p_description), ''),
      p_discount_type,
      case when p_discount_type = 'percent' then p_discount_percent else null end,
      case when p_discount_type = 'fixed_amount' then p_discount_amount_cents else null end,
      p_min_order_cents,
      p_max_discount_cents,
      p_starts_at,
      p_ends_at,
      p_max_total_redemptions,
      p_per_member_max_uses,
      p_validity_days_after_assign,
      v_terms,
      coalesce(p_is_active, true)
    )
    returning id into v_id;
  else
    update public.coupon_definitions
    set
      slug = v_slug,
      title = v_title,
      description = coalesce(trim(p_description), ''),
      discount_type = p_discount_type,
      discount_percent = case when p_discount_type = 'percent' then p_discount_percent else null end,
      discount_amount_cents = case when p_discount_type = 'fixed_amount' then p_discount_amount_cents else null end,
      min_order_cents = p_min_order_cents,
      max_discount_cents = p_max_discount_cents,
      starts_at = p_starts_at,
      ends_at = p_ends_at,
      max_total_redemptions = p_max_total_redemptions,
      per_member_max_uses = p_per_member_max_uses,
      validity_days_after_assign = p_validity_days_after_assign,
      terms_content = v_terms,
      is_active = coalesce(p_is_active, true),
      updated_at = now()
    where id = p_id
    returning id into v_id;

    if v_id is null then
      raise exception 'Coupon not found: %', p_id;
    end if;
  end if;

  return v_id;
end;
$$;
create or replace function public.assign_coupon_to_members(
  p_coupon_id uuid,
  p_profile_ids uuid[]
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_definition public.coupon_definitions;
  v_profile_id uuid;
  v_assigned integer := 0;
  v_expires_at timestamptz;
begin
  perform public.assert_admin_access();

  select * into v_definition
  from public.coupon_definitions
  where id = p_coupon_id;

  if not found then
    raise exception 'Coupon not found: %', p_coupon_id;
  end if;

  if not public.is_coupon_definition_active(v_definition) then
    raise exception 'Coupon is not active';
  end if;

  foreach v_profile_id in array p_profile_ids
  loop
    if exists (
      select 1
      from public.member_coupons mc
      where mc.profile_id = v_profile_id
        and mc.coupon_definition_id = p_coupon_id
        and mc.status = 'active'
    ) then
      continue;
    end if;

    v_expires_at := public.compute_member_coupon_expires_at(v_definition, now());

    insert into public.member_coupons (
      coupon_definition_id,
      profile_id,
      assigned_by,
      expires_at,
      status
    )
    values (
      p_coupon_id,
      v_profile_id,
      auth.uid(),
      v_expires_at,
      'active'
    );

    v_assigned := v_assigned + 1;
  end loop;

  return v_assigned;
end;
$$;
-- ---------------------------------------------------------------------------
-- Customer / staff read RPCs
-- ---------------------------------------------------------------------------

create or replace function public.list_member_coupons(
  p_profile_id uuid,
  p_status text default null
)
returns table (
  id uuid,
  coupon_definition_id uuid,
  profile_id uuid,
  assigned_at timestamptz,
  assigned_by uuid,
  source_banner_id uuid,
  expires_at timestamptz,
  times_used integer,
  status text,
  created_at timestamptz,
  updated_at timestamptz,
  slug text,
  title text,
  description text,
  discount_type text,
  discount_percent integer,
  discount_amount_cents integer,
  min_order_cents integer,
  max_discount_cents integer,
  per_member_max_uses integer,
  terms_content text
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_caller_role text;
begin
  if auth.uid() is distinct from p_profile_id then
    select staff_role into v_caller_role
    from public.profiles
    where id = auth.uid();

    if v_caller_role is null then
      raise exception 'Not authorized to view coupons for this profile';
    end if;
  end if;

  return query
  select
    mc.id,
    mc.coupon_definition_id,
    mc.profile_id,
    mc.assigned_at,
    mc.assigned_by,
    mc.source_banner_id,
    mc.expires_at,
    mc.times_used,
    mc.status,
    mc.created_at,
    mc.updated_at,
    cd.slug,
    cd.title,
    cd.description,
    cd.discount_type,
    cd.discount_percent,
    cd.discount_amount_cents,
    cd.min_order_cents,
    cd.max_discount_cents,
    cd.per_member_max_uses,
    cd.terms_content
  from public.member_coupons mc
  join public.coupon_definitions cd on cd.id = mc.coupon_definition_id
  where mc.profile_id = p_profile_id
    and (p_status is null or mc.status = p_status)
  order by mc.created_at desc;
end;
$$;
create or replace function public.list_applicable_coupons(
  p_profile_id uuid,
  p_payable_cents integer
)
returns table (
  id uuid,
  coupon_definition_id uuid,
  profile_id uuid,
  assigned_at timestamptz,
  assigned_by uuid,
  source_banner_id uuid,
  expires_at timestamptz,
  times_used integer,
  status text,
  created_at timestamptz,
  updated_at timestamptz,
  slug text,
  title text,
  description text,
  discount_type text,
  discount_percent integer,
  discount_amount_cents integer,
  min_order_cents integer,
  max_discount_cents integer,
  per_member_max_uses integer,
  terms_content text,
  estimated_discount_cents integer
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_caller_role text;
begin
  select staff_role into v_caller_role
  from public.profiles
  where id = auth.uid();

  if v_caller_role is null then
    raise exception 'Only staff can list applicable coupons';
  end if;

  return query
  select
    mc.id,
    mc.coupon_definition_id,
    mc.profile_id,
    mc.assigned_at,
    mc.assigned_by,
    mc.source_banner_id,
    mc.expires_at,
    mc.times_used,
    mc.status,
    mc.created_at,
    mc.updated_at,
    cd.slug,
    cd.title,
    cd.description,
    cd.discount_type,
    cd.discount_percent,
    cd.discount_amount_cents,
    cd.min_order_cents,
    cd.max_discount_cents,
    cd.per_member_max_uses,
    cd.terms_content,
    public.calculate_coupon_discount_cents(cd, p_payable_cents)
  from public.member_coupons mc
  join public.coupon_definitions cd on cd.id = mc.coupon_definition_id
  where mc.profile_id = p_profile_id
    and mc.status = 'active'
    and public.is_member_coupon_usable(mc, cd, p_payable_cents)
  order by mc.created_at desc;
end;
$$;
create or replace function public.collect_banner_coupon(p_banner_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_banner public.marketing_banners;
  v_definition public.coupon_definitions;
  v_member_coupon_id uuid;
  v_expires_at timestamptz;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select * into v_banner
  from public.marketing_banners
  where id = p_banner_id;

  if not found then
    raise exception 'Banner not found: %', p_banner_id;
  end if;

  if not public.is_marketing_banner_active(v_banner) then
    raise exception 'Banner is not active';
  end if;

  if v_banner.coupon_definition_id is null then
    raise exception 'This banner does not offer a coupon';
  end if;

  select * into v_definition
  from public.coupon_definitions
  where id = v_banner.coupon_definition_id;

  if not found then
    raise exception 'Linked coupon not found';
  end if;

  if not public.is_coupon_definition_active(v_definition) then
    raise exception 'Coupon is not currently available';
  end if;

  if exists (
    select 1
    from public.member_coupons mc
    where mc.profile_id = auth.uid()
      and mc.coupon_definition_id = v_definition.id
      and mc.status = 'active'
  ) then
    raise exception 'Coupon already collected';
  end if;

  if v_definition.max_total_redemptions is not null then
    if (
      select count(*)::integer
      from public.coupon_redemptions cr
      join public.member_coupons mc on mc.id = cr.member_coupon_id
      where mc.coupon_definition_id = v_definition.id
    ) >= v_definition.max_total_redemptions then
      raise exception 'Coupon redemption limit reached';
    end if;
  end if;

  v_expires_at := public.compute_member_coupon_expires_at(v_definition, now());

  insert into public.member_coupons (
    coupon_definition_id,
    profile_id,
    source_banner_id,
    expires_at,
    status
  )
  values (
    v_definition.id,
    auth.uid(),
    p_banner_id,
    v_expires_at,
    'active'
  )
  returning id into v_member_coupon_id;

  return v_member_coupon_id;
end;
$$;
create or replace function public.get_coupon_definition(p_id uuid)
returns public.coupon_definitions
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_coupon public.coupon_definitions;
begin
  select * into v_coupon
  from public.coupon_definitions
  where id = p_id;

  if not found then
    raise exception 'Coupon not found: %', p_id;
  end if;

  return v_coupon;
end;
$$;
-- ---------------------------------------------------------------------------
-- Staff order creation with discounts
-- ---------------------------------------------------------------------------

create or replace function public.create_staff_order(
  p_profile_id uuid,
  p_store_id uuid,
  p_notes text default null,
  p_items jsonb default '[]'::jsonb,
  p_member_coupon_id uuid default null,
  p_manual_discount_type text default null,
  p_manual_discount_value integer default null,
  p_manual_discount_reason text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_caller_role text;
  v_order_id uuid;
  v_item jsonb;
  v_subtotal integer := 0;
  v_payable integer := 0;
  v_discount integer := 0;
  v_member_coupon public.member_coupons;
  v_definition public.coupon_definitions;
  v_has_redemption boolean := false;
  v_has_paid boolean := false;
  v_is_redemption_only boolean := false;
  v_discount_type text;
  v_discount_metadata jsonb := '{}'::jsonb;
begin
  select staff_role into v_caller_role
  from public.profiles
  where id = auth.uid();

  if v_caller_role is null then
    raise exception 'Only staff can create orders';
  end if;

  if p_member_coupon_id is not null
    and p_manual_discount_type is not null then
    raise exception 'Apply either a coupon or a manual discount, not both';
  end if;

  insert into public.orders (
    profile_id,
    store_id,
    status,
    notes,
    tax_cents,
    is_redemption,
    order_number
  )
  values (
    p_profile_id,
    p_store_id,
    'pending',
    nullif(trim(coalesce(p_notes, '')), ''),
    0,
    false,
    ''
  )
  returning id into v_order_id;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    insert into public.order_items (
      order_id,
      product_id,
      product_name,
      unit_price_cents,
      points_earned,
      points_redeemed,
      quantity,
      variant_id,
      variant_name,
      addons
    )
    values (
      v_order_id,
      (v_item->>'product_id')::uuid,
      v_item->>'product_name',
      coalesce((v_item->>'unit_price_cents')::integer, 0),
      coalesce((v_item->>'points_earned')::integer, 0),
      coalesce((v_item->>'points_redeemed')::integer, 0),
      coalesce((v_item->>'quantity')::integer, 1),
      nullif(v_item->>'variant_id', '')::uuid,
      nullif(v_item->>'variant_name', ''),
      coalesce(v_item->'addons', '[]'::jsonb)
    );

    if coalesce((v_item->>'points_redeemed')::integer, 0) > 0 then
      v_has_redemption := true;
    end if;

    if coalesce((v_item->>'unit_price_cents')::integer, 0) > 0 then
      v_has_paid := true;
    end if;
  end loop;

  select coalesce(sum(line_total_cents), 0)
  into v_subtotal
  from public.order_items
  where order_id = v_order_id;

  select coalesce(sum(line_total_cents), 0)
  into v_payable
  from public.order_items
  where order_id = v_order_id
    and unit_price_cents > 0;

  v_is_redemption_only := v_has_redemption and not v_has_paid and v_payable = 0;

  if p_member_coupon_id is not null then
    select mc.*
    into v_member_coupon
    from public.member_coupons mc
    where mc.id = p_member_coupon_id
      and mc.profile_id = p_profile_id
    for update;

    if not found then
      raise exception 'Coupon not found for this customer';
    end if;

    select cd.*
    into v_definition
    from public.coupon_definitions cd
    where cd.id = v_member_coupon.coupon_definition_id;

    if not public.is_member_coupon_usable(v_member_coupon, v_definition, v_payable) then
      raise exception 'Coupon is not applicable to this order';
    end if;

    v_discount := public.calculate_coupon_discount_cents(v_definition, v_payable);

    if v_discount <= 0 then
      raise exception 'Coupon does not apply to this order total';
    end if;

    v_discount_type := 'coupon';
    v_discount_metadata := jsonb_build_object(
      'coupon_title', v_definition.title,
      'coupon_slug', v_definition.slug,
      'discount_type', v_definition.discount_type,
      'staff_id', auth.uid(),
      'reason', null
    );

    update public.member_coupons
    set
      times_used = times_used + 1,
      status = case
        when times_used + 1 >= v_definition.per_member_max_uses then 'used'
        else status
      end,
      updated_at = now()
    where id = v_member_coupon.id;

    insert into public.coupon_redemptions (
      member_coupon_id,
      order_id,
      profile_id,
      discount_cents,
      redeemed_by,
      snapshot
    )
    values (
      v_member_coupon.id,
      v_order_id,
      p_profile_id,
      v_discount,
      auth.uid(),
      jsonb_build_object(
        'title', v_definition.title,
        'slug', v_definition.slug,
        'discount_type', v_definition.discount_type,
        'terms_content', v_definition.terms_content
      )
    );
  elsif p_manual_discount_type is not null then
    if p_manual_discount_type = 'percent' then
      if p_manual_discount_value is null or p_manual_discount_value < 1 or p_manual_discount_value > 100 then
        raise exception 'Manual percent discount must be between 1 and 100';
      end if;

      v_discount := floor(v_payable * p_manual_discount_value::numeric / 100)::integer;
      v_discount_type := 'manual_percent';
    elsif p_manual_discount_type = 'fixed' then
      if p_manual_discount_value is null or p_manual_discount_value <= 0 then
        raise exception 'Manual fixed discount must be greater than zero';
      end if;

      v_discount := least(p_manual_discount_value, v_payable);
      v_discount_type := 'manual_fixed';
    else
      raise exception 'Invalid manual discount type: %', p_manual_discount_type;
    end if;

    v_discount_metadata := jsonb_build_object(
      'staff_id', auth.uid(),
      'reason', nullif(trim(coalesce(p_manual_discount_reason, '')), ''),
      'manual_value', p_manual_discount_value
    );
  end if;

  update public.orders
  set
    discount_cents = v_discount,
    discount_type = v_discount_type,
    discount_metadata = v_discount_metadata,
    member_coupon_id = p_member_coupon_id,
    is_redemption = v_is_redemption_only,
    total_cents = greatest(v_subtotal - v_discount, 0)
  where id = v_order_id;

  return v_order_id;
end;
$$;
-- ---------------------------------------------------------------------------
-- Update banner upsert to support coupon link
-- ---------------------------------------------------------------------------

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
  p_sort_order integer default 0,
  p_coupon_definition_id uuid default null
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

  if p_coupon_definition_id is not null then
    if not exists (
      select 1 from public.coupon_definitions where id = p_coupon_definition_id
    ) then
      raise exception 'Coupon definition not found: %', p_coupon_definition_id;
    end if;
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
      sort_order,
      coupon_definition_id
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
      p_sort_order,
      p_coupon_definition_id
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
      coupon_definition_id = p_coupon_definition_id,
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
-- ---------------------------------------------------------------------------
-- RLS + grants
-- ---------------------------------------------------------------------------

alter table public.coupon_definitions enable row level security;
alter table public.member_coupons enable row level security;
alter table public.coupon_redemptions enable row level security;
create policy coupon_definitions_select_authenticated
  on public.coupon_definitions
  for select
  to authenticated
  using (true);
create policy member_coupons_select_own_or_staff
  on public.member_coupons
  for select
  to authenticated
  using (
    profile_id = auth.uid()
    or exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.staff_role is not null
    )
  );
create policy coupon_redemptions_select_own_or_staff
  on public.coupon_redemptions
  for select
  to authenticated
  using (
    profile_id = auth.uid()
    or exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.staff_role is not null
    )
  );
grant select on table public.coupon_definitions to authenticated;
grant select on table public.member_coupons to authenticated;
grant select on table public.coupon_redemptions to authenticated;
grant execute on function public.list_coupons_admin() to authenticated;
grant execute on function public.upsert_coupon_admin(
  uuid, text, text, text, text, integer, integer, integer, integer,
  timestamptz, timestamptz, integer, integer, integer, text, boolean
) to authenticated;
grant execute on function public.assign_coupon_to_members(uuid, uuid[]) to authenticated;
grant execute on function public.list_member_coupons(uuid, text) to authenticated;
grant execute on function public.list_applicable_coupons(uuid, integer) to authenticated;
grant execute on function public.collect_banner_coupon(uuid) to authenticated;
grant execute on function public.get_coupon_definition(uuid) to authenticated;
grant execute on function public.create_staff_order(
  uuid, uuid, text, jsonb, uuid, text, integer, text
) to authenticated;
grant execute on function public.upsert_marketing_banner_admin(
  uuid, text, text, text, text, text, text, text, text, text, text,
  integer, timestamptz, timestamptz, boolean, integer, uuid
) to authenticated;
