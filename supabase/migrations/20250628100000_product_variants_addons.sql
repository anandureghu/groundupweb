-- Product size variants, add-ons, and order line snapshots

create table public.addons (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  price_cents integer not null check (price_cents >= 0),
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.product_variants (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products (id) on delete cascade,
  name text not null,
  price_cents integer not null check (price_cents >= 0),
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (product_id, name)
);
create index product_variants_product_id_idx on public.product_variants (product_id);
create table public.category_addons (
  category_id uuid not null references public.categories (id) on delete cascade,
  addon_id uuid not null references public.addons (id) on delete cascade,
  price_cents integer check (price_cents is null or price_cents >= 0),
  primary key (category_id, addon_id)
);
alter table public.order_items
  add column if not exists variant_id uuid references public.product_variants (id) on delete set null,
  add column if not exists variant_name text,
  add column if not exists addons jsonb not null default '[]'::jsonb;
create index order_items_variant_id_idx on public.order_items (variant_id);
alter table public.addons disable row level security;
alter table public.product_variants disable row level security;
alter table public.category_addons disable row level security;
grant select, insert, update, delete on table public.addons to anon, authenticated, service_role;
grant select, insert, update, delete on table public.product_variants to anon, authenticated, service_role;
grant select, insert, update, delete on table public.category_addons to anon, authenticated, service_role;
