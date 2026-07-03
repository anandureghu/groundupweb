-- Phase 5: Core commerce schema for Groundup Society
-- Extends profiles and adds stores, catalog, orders, rewards, and promotions.
-- RLS is intentionally disabled for development (see grants at end of file).

-- ---------------------------------------------------------------------------
-- Profiles (extend existing)
-- ---------------------------------------------------------------------------

alter table public.profiles
  add column if not exists points_balance integer not null default 0
    check (points_balance >= 0);
comment on column public.profiles.points_balance is
  'Current reward points balance for the member.';
-- ---------------------------------------------------------------------------
-- Stores
-- ---------------------------------------------------------------------------

create table public.stores (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  neighborhood text,
  address_line1 text,
  city text not null default 'New York',
  state text not null default 'NY',
  postal_code text,
  latitude numeric(10, 7),
  longitude numeric(10, 7),
  phone text,
  status text not null default 'open'
    check (status in ('open', 'closing_soon', 'closed')),
  opens_at time,
  closes_at time,
  image_url text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index stores_slug_idx on public.stores (slug);
create index stores_status_idx on public.stores (status) where is_active = true;
create index stores_city_idx on public.stores (city);
-- ---------------------------------------------------------------------------
-- Categories
-- ---------------------------------------------------------------------------

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  description text,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index categories_slug_idx on public.categories (slug);
create index categories_sort_order_idx on public.categories (sort_order) where is_active = true;
-- ---------------------------------------------------------------------------
-- Products
-- ---------------------------------------------------------------------------

create table public.products (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references public.categories (id) on delete restrict,
  name text not null,
  slug text not null unique,
  description text,
  price_cents integer not null check (price_cents >= 0),
  image_url text,
  is_featured boolean not null default false,
  is_seasonal boolean not null default false,
  is_active boolean not null default true,
  points_earned integer not null default 0 check (points_earned >= 0),
  badge text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index products_category_id_idx on public.products (category_id);
create index products_slug_idx on public.products (slug);
create index products_featured_idx on public.products (is_featured) where is_active = true;
create index products_seasonal_idx on public.products (is_seasonal) where is_active = true;
-- ---------------------------------------------------------------------------
-- Orders
-- ---------------------------------------------------------------------------

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  order_number text not null unique,
  profile_id uuid not null references public.profiles (id) on delete restrict,
  store_id uuid not null references public.stores (id) on delete restrict,
  status text not null default 'pending'
    check (status in ('pending', 'confirmed', 'preparing', 'ready', 'completed', 'cancelled')),
  subtotal_cents integer not null default 0 check (subtotal_cents >= 0),
  tax_cents integer not null default 0 check (tax_cents >= 0),
  total_cents integer not null default 0 check (total_cents >= 0),
  points_earned integer not null default 0 check (points_earned >= 0),
  notes text,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index orders_profile_id_idx on public.orders (profile_id);
create index orders_store_id_idx on public.orders (store_id);
create index orders_status_idx on public.orders (status);
create index orders_created_at_idx on public.orders (created_at desc);
create index orders_order_number_idx on public.orders (order_number);
-- ---------------------------------------------------------------------------
-- Order items
-- ---------------------------------------------------------------------------

create table public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders (id) on delete cascade,
  product_id uuid references public.products (id) on delete set null,
  product_name text not null,
  unit_price_cents integer not null check (unit_price_cents >= 0),
  quantity integer not null check (quantity > 0),
  line_total_cents integer not null check (line_total_cents >= 0),
  created_at timestamptz not null default now()
);
create index order_items_order_id_idx on public.order_items (order_id);
create index order_items_product_id_idx on public.order_items (product_id);
-- ---------------------------------------------------------------------------
-- Reward transactions
-- ---------------------------------------------------------------------------

create table public.reward_transactions (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  order_id uuid references public.orders (id) on delete set null,
  type text not null
    check (type in ('earn', 'redeem', 'bonus', 'referral', 'adjustment')),
  points integer not null check (points <> 0),
  balance_after integer not null check (balance_after >= 0),
  description text not null,
  created_at timestamptz not null default now()
);
create index reward_transactions_profile_id_idx on public.reward_transactions (profile_id);
create index reward_transactions_order_id_idx on public.reward_transactions (order_id);
create index reward_transactions_created_at_idx on public.reward_transactions (created_at desc);
create index reward_transactions_type_idx on public.reward_transactions (type);
-- ---------------------------------------------------------------------------
-- Promotions
-- ---------------------------------------------------------------------------

create table public.promotions (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  slug text not null unique,
  tag text,
  description text not null,
  type text not null
    check (type in ('double_points', 'discount', 'referral', 'seasonal', 'member_perk')),
  discount_percent integer check (discount_percent is null or (discount_percent >= 0 and discount_percent <= 100)),
  bonus_points integer check (bonus_points is null or bonus_points >= 0),
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  is_active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index promotions_slug_idx on public.promotions (slug);
create index promotions_active_idx on public.promotions (is_active, starts_at, ends_at);
create index promotions_type_idx on public.promotions (type);
-- ---------------------------------------------------------------------------
-- Disable RLS (development mode — no manual policy setup required)
-- ---------------------------------------------------------------------------

alter table public.profiles disable row level security;
alter table public.stores disable row level security;
alter table public.categories disable row level security;
alter table public.products disable row level security;
alter table public.orders disable row level security;
alter table public.order_items disable row level security;
alter table public.reward_transactions disable row level security;
alter table public.promotions disable row level security;
grant select, insert, update, delete on table public.profiles to anon, authenticated, service_role;
grant select, insert, update, delete on table public.stores to anon, authenticated, service_role;
grant select, insert, update, delete on table public.categories to anon, authenticated, service_role;
grant select, insert, update, delete on table public.products to anon, authenticated, service_role;
grant select, insert, update, delete on table public.orders to anon, authenticated, service_role;
grant select, insert, update, delete on table public.order_items to anon, authenticated, service_role;
grant select, insert, update, delete on table public.reward_transactions to anon, authenticated, service_role;
grant select, insert, update, delete on table public.promotions to anon, authenticated, service_role;
grant usage, select on all sequences in schema public to anon, authenticated, service_role;
