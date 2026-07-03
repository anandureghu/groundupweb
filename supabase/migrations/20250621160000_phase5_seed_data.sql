-- Phase 5: Seed data for Groundup Society
-- Uses fixed UUIDs so references remain stable across environments.

-- ---------------------------------------------------------------------------
-- Categories
-- ---------------------------------------------------------------------------

insert into public.categories (id, name, slug, description, sort_order)
values
  (
    'a1000000-0000-4000-8000-000000000001',
    'Matcha',
    'matcha',
    'Ceremonial and craft matcha drinks.',
    1
  ),
  (
    'a1000000-0000-4000-8000-000000000002',
    'Espresso',
    'espresso',
    'Espresso-based classics and lattes.',
    2
  ),
  (
    'a1000000-0000-4000-8000-000000000003',
    'Cold',
    'cold',
    'Iced and cold brew selections.',
    3
  ),
  (
    'a1000000-0000-4000-8000-000000000004',
    'Seasonal',
    'seasonal',
    'Limited seasonal collections.',
    4
  )
on conflict (slug) do update set
  name = excluded.name,
  description = excluded.description,
  sort_order = excluded.sort_order,
  is_active = true;
-- ---------------------------------------------------------------------------
-- Stores
-- ---------------------------------------------------------------------------

insert into public.stores (
  id,
  name,
  slug,
  neighborhood,
  address_line1,
  city,
  state,
  postal_code,
  status,
  opens_at,
  closes_at,
  image_url
)
values
  (
    'b2000000-0000-4000-8000-000000000001',
    'Groundup SoHo',
    'groundup-soho',
    'SoHo, Manhattan',
    '125 Spring Street',
    'New York',
    'NY',
    '10012',
    'open',
    '07:00',
    '19:00',
    'https://images.unsplash.com/photo-1493857671505-729ba8a9607b?auto=format&fit=crop&w=600&q=80'
  ),
  (
    'b2000000-0000-4000-8000-000000000002',
    'Groundup Williamsburg',
    'groundup-williamsburg',
    'Williamsburg, Brooklyn',
    '240 Bedford Avenue',
    'Brooklyn',
    'NY',
    '11211',
    'closing_soon',
    '07:30',
    '18:30',
    'https://images.unsplash.com/photo-1554118811-1e0d58224f24?auto=format&fit=crop&w=600&q=80'
  ),
  (
    'b2000000-0000-4000-8000-000000000003',
    'Groundup West Village',
    'groundup-west-village',
    'West Village, Manhattan',
    '48 Christopher Street',
    'New York',
    'NY',
    '10014',
    'open',
    '07:00',
    '20:00',
    'https://images.unsplash.com/photo-1501339846605-531ba89a99e0?auto=format&fit=crop&w=600&q=80'
  )
on conflict (slug) do update set
  name = excluded.name,
  neighborhood = excluded.neighborhood,
  address_line1 = excluded.address_line1,
  status = excluded.status,
  opens_at = excluded.opens_at,
  closes_at = excluded.closes_at,
  image_url = excluded.image_url,
  is_active = true;
-- ---------------------------------------------------------------------------
-- Products
-- ---------------------------------------------------------------------------

insert into public.products (
  id,
  category_id,
  name,
  slug,
  description,
  price_cents,
  image_url,
  is_featured,
  is_seasonal,
  points_earned,
  badge
)
values
  (
    'c3000000-0000-4000-8000-000000000001',
    'a1000000-0000-4000-8000-000000000001',
    'Ceremonial Matcha',
    'ceremonial-matcha',
    'Stone-ground ceremonial grade matcha whisked to order.',
    650,
    'https://images.unsplash.com/photo-1515823064-d6ffc0d066556?auto=format&fit=crop&w=600&q=80',
    true,
    false,
    65,
    'Signature'
  ),
  (
    'c3000000-0000-4000-8000-000000000002',
    'a1000000-0000-4000-8000-000000000002',
    'Oat Flat White',
    'oat-flat-white',
    'Double ristretto with silky oat milk.',
    575,
    'https://images.unsplash.com/photo-1461023058943-07fcbe16d735?auto=format&fit=crop&w=600&q=80',
    true,
    false,
    58,
    null
  ),
  (
    'c3000000-0000-4000-8000-000000000003',
    'a1000000-0000-4000-8000-000000000003',
    'Honey Yuzu Cold Brew',
    'honey-yuzu-cold-brew',
    'Slow-steeped cold brew with honey and yuzu.',
    625,
    'https://images.unsplash.com/photo-1517701551-8566e3e00725?auto=format&fit=crop&w=600&q=80',
    true,
    false,
    63,
    'New'
  ),
  (
    'c3000000-0000-4000-8000-000000000004',
    'a1000000-0000-4000-8000-000000000002',
    'Vanilla Oat Latte',
    'vanilla-oat-latte',
    'Espresso, oat milk, and house vanilla.',
    595,
    'https://images.unsplash.com/photo-1572442388796-11668a67e53d?auto=format&fit=crop&w=600&q=80',
    true,
    false,
    60,
    null
  ),
  (
    'c3000000-0000-4000-8000-000000000005',
    'a1000000-0000-4000-8000-000000000004',
    'Cherry Blossom Matcha',
    'cherry-blossom-matcha',
    'Limited sakura-infused matcha with white chocolate notes.',
    725,
    'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?auto=format&fit=crop&w=600&q=80',
    false,
    true,
    73,
    'Seasonal'
  ),
  (
    'c3000000-0000-4000-8000-000000000006',
    'a1000000-0000-4000-8000-000000000002',
    'Single Origin Espresso',
    'single-origin-espresso',
    'Rotating single-origin espresso shot.',
    425,
    'https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?auto=format&fit=crop&w=600&q=80',
    false,
    false,
    43,
    null
  )
on conflict (slug) do update set
  category_id = excluded.category_id,
  name = excluded.name,
  description = excluded.description,
  price_cents = excluded.price_cents,
  image_url = excluded.image_url,
  is_featured = excluded.is_featured,
  is_seasonal = excluded.is_seasonal,
  points_earned = excluded.points_earned,
  badge = excluded.badge,
  is_active = true;
-- ---------------------------------------------------------------------------
-- Promotions
-- ---------------------------------------------------------------------------

insert into public.promotions (
  id,
  title,
  slug,
  tag,
  description,
  type,
  bonus_points,
  starts_at,
  ends_at,
  is_active,
  metadata
)
values
  (
    'd4000000-0000-4000-8000-000000000001',
    'Matcha Mondays',
    'matcha-mondays',
    'Double points',
    'Earn 2× points on all matcha drinks every Monday before noon.',
    'double_points',
    null,
    now() - interval '7 days',
    now() + interval '30 days',
    true,
    jsonb_build_object(
      'category_slug', 'matcha',
      'day_of_week', 'monday',
      'multiplier', 2
    )
  ),
  (
    'd4000000-0000-4000-8000-000000000002',
    'Refer & sip free',
    'refer-and-sip-free',
    'Member perk',
    'Invite a friend and both enjoy a complimentary drink on us.',
    'referral',
    200,
    now() - interval '30 days',
    null,
    true,
    jsonb_build_object(
      'reward_type', 'free_drink',
      'referral_bonus_points', 200
    )
  ),
  (
    'd4000000-0000-4000-8000-000000000003',
    'Cherry Blossom Collection',
    'cherry-blossom-collection',
    'Seasonal',
    'Limited sakura-infused matcha, white chocolate notes, and soft florals for the season.',
    'seasonal',
    50,
    now() - interval '14 days',
    now() + interval '60 days',
    true,
    jsonb_build_object(
      'collection_slug', 'cherry-blossom',
      'season', 'Spring 2026'
    )
  )
on conflict (slug) do update set
  title = excluded.title,
  tag = excluded.tag,
  description = excluded.description,
  type = excluded.type,
  bonus_points = excluded.bonus_points,
  starts_at = excluded.starts_at,
  ends_at = excluded.ends_at,
  is_active = excluded.is_active,
  metadata = excluded.metadata;
