-- Groundup menu catalog seed (categories, products, variants, add-ons)

-- Deactivate legacy demo catalog
update public.categories set is_active = false where slug in ('matcha', 'espresso', 'cold', 'seasonal');
update public.products set is_active = false where category_id in (
  select id from public.categories where slug in ('matcha', 'espresso', 'cold', 'seasonal')
);
-- Categories
insert into public.categories (id, name, slug, description, sort_order, is_active)
values
  ('d1000000-0000-4000-8000-000000000001', 'Basics · Coffee', 'basics-coffee', null, 1, true),
  ('d1000000-0000-4000-8000-000000000002', 'Basics · Non-Coffee', 'basics-non-coffee', null, 2, true),
  ('d1000000-0000-4000-8000-000000000003', 'Society · Lattes', 'society-lattes', null, 3, true),
  ('d1000000-0000-4000-8000-000000000004', 'Matcha · Lattes', 'matcha-lattes', null, 4, true),
  ('d1000000-0000-4000-8000-000000000005', 'Bagels', 'bagels', null, 5, true),
  ('d1000000-0000-4000-8000-000000000006', 'Smoothies', 'smoothies', null, 6, true)
on conflict (slug) do update set
  name = excluded.name,
  sort_order = excluded.sort_order,
  is_active = true;
-- Add-ons
insert into public.addons (id, name, slug, price_cents, sort_order, is_active)
values
  ('e2000000-0000-4000-8000-000000000001', '+ Syrup', 'syrup', 55, 1, true),
  ('e2000000-0000-4000-8000-000000000002', '+ CBD Shot', 'cbd-shot', 300, 2, true),
  ('e2000000-0000-4000-8000-000000000003', '+ Collagen', 'collagen', 100, 3, true),
  ('e2000000-0000-4000-8000-000000000004', '+ Extra Shot', 'extra-shot', 100, 4, true),
  ('e2000000-0000-4000-8000-000000000005', '+ Cold Foam', 'cold-foam', 55, 5, true)
on conflict (slug) do update set
  name = excluded.name,
  price_cents = excluded.price_cents,
  sort_order = excluded.sort_order,
  is_active = true;
-- Category add-ons
insert into public.category_addons (category_id, addon_id, price_cents)
values
  ('d1000000-0000-4000-8000-000000000001', 'e2000000-0000-4000-8000-000000000001', null),
  ('d1000000-0000-4000-8000-000000000001', 'e2000000-0000-4000-8000-000000000002', null),
  ('d1000000-0000-4000-8000-000000000001', 'e2000000-0000-4000-8000-000000000003', null),
  ('d1000000-0000-4000-8000-000000000001', 'e2000000-0000-4000-8000-000000000004', null),
  ('d1000000-0000-4000-8000-000000000001', 'e2000000-0000-4000-8000-000000000005', null),
  ('d1000000-0000-4000-8000-000000000002', 'e2000000-0000-4000-8000-000000000001', null),
  ('d1000000-0000-4000-8000-000000000002', 'e2000000-0000-4000-8000-000000000002', null),
  ('d1000000-0000-4000-8000-000000000002', 'e2000000-0000-4000-8000-000000000003', null),
  ('d1000000-0000-4000-8000-000000000002', 'e2000000-0000-4000-8000-000000000004', null),
  ('d1000000-0000-4000-8000-000000000002', 'e2000000-0000-4000-8000-000000000005', null),
  ('d1000000-0000-4000-8000-000000000004', 'e2000000-0000-4000-8000-000000000005', 50)
on conflict (category_id, addon_id) do update set
  price_cents = excluded.price_cents;
-- Products
insert into public.products (id, category_id, name, slug, description, price_cents, image_url, is_featured, is_seasonal, points_earned, is_active)
values
  ('f3000000-0000-4000-8000-000000000001', 'd1000000-0000-4000-8000-000000000001', 'Double Espresso', 'double-espresso', null, 315, 'https://images.unsplash.com/photo-1461023058943-07fcbe16d735?auto=format&fit=crop&w=600&q=80', false, false, 32, true),
  ('f3000000-0000-4000-8000-000000000002', 'd1000000-0000-4000-8000-000000000001', 'Americano / Ice', 'americano-ice', null, 355, 'https://images.unsplash.com/photo-1461023058943-07fcbe16d735?auto=format&fit=crop&w=600&q=80', false, false, 36, true),
  ('f3000000-0000-4000-8000-000000000003', 'd1000000-0000-4000-8000-000000000001', 'Macchiato', 'macchiato', null, 335, 'https://images.unsplash.com/photo-1461023058943-07fcbe16d735?auto=format&fit=crop&w=600&q=80', false, false, 34, true),
  ('f3000000-0000-4000-8000-000000000004', 'd1000000-0000-4000-8000-000000000001', 'Cortado', 'cortado', null, 370, 'https://images.unsplash.com/photo-1461023058943-07fcbe16d735?auto=format&fit=crop&w=600&q=80', false, false, 37, true),
  ('f3000000-0000-4000-8000-000000000005', 'd1000000-0000-4000-8000-000000000001', 'Flat White', 'flat-white', null, 395, 'https://images.unsplash.com/photo-1461023058943-07fcbe16d735?auto=format&fit=crop&w=600&q=80', false, false, 40, true),
  ('f3000000-0000-4000-8000-000000000006', 'd1000000-0000-4000-8000-000000000001', 'Latte / Ice', 'latte-ice', null, 425, 'https://images.unsplash.com/photo-1461023058943-07fcbe16d735?auto=format&fit=crop&w=600&q=80', false, false, 43, true),
  ('f3000000-0000-4000-8000-000000000007', 'd1000000-0000-4000-8000-000000000001', 'Cappuccino', 'cappuccino', null, 425, 'https://images.unsplash.com/photo-1461023058943-07fcbe16d735?auto=format&fit=crop&w=600&q=80', false, false, 43, true),
  ('f3000000-0000-4000-8000-000000000008', 'd1000000-0000-4000-8000-000000000001', 'Mocha / Ice', 'mocha-ice', null, 435, 'https://images.unsplash.com/photo-1461023058943-07fcbe16d735?auto=format&fit=crop&w=600&q=80', false, false, 44, true),
  ('f4000000-0000-4000-8000-000000000001', 'd1000000-0000-4000-8000-000000000002', 'Matcha Latte', 'matcha-latte-basics', null, 425, 'https://images.unsplash.com/photo-1515823064-d6ffc0d066556?auto=format&fit=crop&w=600&q=80', false, false, 43, true),
  ('f4000000-0000-4000-8000-000000000002', 'd1000000-0000-4000-8000-000000000002', 'Hot Chocolate', 'hot-chocolate', null, 425, 'https://images.unsplash.com/photo-1461023058943-07fcbe16d735?auto=format&fit=crop&w=600&q=80', false, false, 43, true),
  ('f4000000-0000-4000-8000-000000000003', 'd1000000-0000-4000-8000-000000000002', 'Chai Latte', 'chai-latte', null, 425, 'https://images.unsplash.com/photo-1461023058943-07fcbe16d735?auto=format&fit=crop&w=600&q=80', false, false, 43, true),
  ('f4000000-0000-4000-8000-000000000004', 'd1000000-0000-4000-8000-000000000002', 'Iced Tea', 'iced-tea', null, 425, 'https://images.unsplash.com/photo-1461023058943-07fcbe16d735?auto=format&fit=crop&w=600&q=80', false, false, 43, true),
  ('f4000000-0000-4000-8000-000000000005', 'd1000000-0000-4000-8000-000000000002', 'Hot Tea', 'hot-tea', null, 365, 'https://images.unsplash.com/photo-1461023058943-07fcbe16d735?auto=format&fit=crop&w=600&q=80', false, false, 37, true),
  ('f4000000-0000-4000-8000-000000000006', 'd1000000-0000-4000-8000-000000000002', 'Karak Chai', 'karak-chai', null, 425, 'https://images.unsplash.com/photo-1461023058943-07fcbe16d735?auto=format&fit=crop&w=600&q=80', false, false, 43, true),
  ('f5000000-0000-4000-8000-000000000001', 'd1000000-0000-4000-8000-000000000003', 'Doubletrouble', 'doubletrouble', 'Double shot arabica coffee, spicy chai', 445, 'https://images.unsplash.com/photo-1572442388796-11668a67e53d?auto=format&fit=crop&w=600&q=80', false, false, 45, true),
  ('f5000000-0000-4000-8000-000000000002', 'd1000000-0000-4000-8000-000000000003', 'Lighthearted', 'lighthearted', 'Vanilla bean, honey, brown sugar', 445, 'https://images.unsplash.com/photo-1572442388796-11668a67e53d?auto=format&fit=crop&w=600&q=80', false, false, 45, true),
  ('f5000000-0000-4000-8000-000000000003', 'd1000000-0000-4000-8000-000000000003', 'Sweettooth', 'sweettooth', 'Cookie butter, caramel, brown sugar', 445, 'https://images.unsplash.com/photo-1572442388796-11668a67e53d?auto=format&fit=crop&w=600&q=80', false, false, 45, true),
  ('f5000000-0000-4000-8000-000000000004', 'd1000000-0000-4000-8000-000000000003', 'Coffee Date', 'coffee-date', 'Medjool date, honey, brown sugar', 445, 'https://images.unsplash.com/photo-1572442388796-11668a67e53d?auto=format&fit=crop&w=600&q=80', false, false, 45, true),
  ('f5000000-0000-4000-8000-000000000005', 'd1000000-0000-4000-8000-000000000003', 'Pistachio Latte', 'pistachio-latte', 'Pistachio milk, honey, vanilla bean', 445, 'https://images.unsplash.com/photo-1572442388796-11668a67e53d?auto=format&fit=crop&w=600&q=80', false, false, 45, true),
  ('f5000000-0000-4000-8000-000000000006', 'd1000000-0000-4000-8000-000000000003', 'Spanish Latte', 'spanish-latte', 'Condensed milk, add caramel', 445, 'https://images.unsplash.com/photo-1572442388796-11668a67e53d?auto=format&fit=crop&w=600&q=80', false, false, 45, true),
  ('f6000000-0000-4000-8000-000000000001', 'd1000000-0000-4000-8000-000000000004', 'Pistachio Cream', 'pistachio-cream', 'Vanilla bean, pistachio, honey', 445, 'https://images.unsplash.com/photo-1515823064-d6ffc0d066556?auto=format&fit=crop&w=600&q=80', false, false, 45, true),
  ('f6000000-0000-4000-8000-000000000002', 'd1000000-0000-4000-8000-000000000004', 'Milky Matcha', 'milky-matcha', 'White chocolate, vanilla bean', 445, 'https://images.unsplash.com/photo-1515823064-d6ffc0d066556?auto=format&fit=crop&w=600&q=80', false, false, 45, true),
  ('f6000000-0000-4000-8000-000000000003', 'd1000000-0000-4000-8000-000000000004', 'Blueberry Society', 'blueberry-society', 'Blueberry puree, blueberries', 445, 'https://images.unsplash.com/photo-1515823064-d6ffc0d066556?auto=format&fit=crop&w=600&q=80', false, false, 45, true),
  ('f6000000-0000-4000-8000-000000000004', 'd1000000-0000-4000-8000-000000000004', 'Strawberry Bean', 'strawberry-bean', 'Strawberry, vanilla bean', 445, 'https://images.unsplash.com/photo-1515823064-d6ffc0d066556?auto=format&fit=crop&w=600&q=80', false, false, 45, true),
  ('f6000000-0000-4000-8000-000000000005', 'd1000000-0000-4000-8000-000000000004', 'Mango Matcha', 'mango-matcha', 'Mango puree, honey', 445, 'https://images.unsplash.com/photo-1515823064-d6ffc0d066556?auto=format&fit=crop&w=600&q=80', false, false, 45, true),
  ('f6000000-0000-4000-8000-000000000006', 'd1000000-0000-4000-8000-000000000004', 'Banana Bliss', 'banana-bliss', 'Banana puree, brown sugar', 445, 'https://images.unsplash.com/photo-1515823064-d6ffc0d066556?auto=format&fit=crop&w=600&q=80', false, false, 45, true),
  ('f6000000-0000-4000-8000-000000000007', 'd1000000-0000-4000-8000-000000000004', 'Matcha Date', 'matcha-date', 'Medjool date, honey, brown sugar', 445, 'https://images.unsplash.com/photo-1515823064-d6ffc0d066556?auto=format&fit=crop&w=600&q=80', false, false, 45, true),
  ('f7000000-0000-4000-8000-000000000001', 'd1000000-0000-4000-8000-000000000005', 'Cream Cheese', 'cream-cheese-bagel', 'Cream cheese spread, sliced cucumber & chilli flakes', 650, 'https://images.unsplash.com/photo-1553909489-cd47e0907980?auto=format&fit=crop&w=600&q=80', false, false, 65, true),
  ('f7000000-0000-4000-8000-000000000002', 'd1000000-0000-4000-8000-000000000005', 'Smoked Salmon', 'smoked-salmon-bagel', 'Oak-smoked salmon with cream cheese, cucumber, red onion, capers & dill', 695, 'https://images.unsplash.com/photo-1553909489-cd47e0907980?auto=format&fit=crop&w=600&q=80', false, false, 70, true),
  ('f7000000-0000-4000-8000-000000000003', 'd1000000-0000-4000-8000-000000000005', 'Tuna Melt', 'tuna-melt-bagel', 'Tuna mayo mix, topped with melted cheese & red onions', 695, 'https://images.unsplash.com/photo-1553909489-cd47e0907980?auto=format&fit=crop&w=600&q=80', false, false, 70, true),
  ('f7000000-0000-4000-8000-000000000004', 'd1000000-0000-4000-8000-000000000005', 'Spicy Tuna', 'spicy-tuna-bagel', 'Tuna, mayo, vegan pesto, sliced tomatoes & jalapeños', 695, 'https://images.unsplash.com/photo-1553909489-cd47e0907980?auto=format&fit=crop&w=600&q=80', false, false, 70, true),
  ('f7000000-0000-4000-8000-000000000005', 'd1000000-0000-4000-8000-000000000005', 'Hummus', 'hummus-bagel', 'Hummus, sun-dried tomatoes & chilli flakes', 650, 'https://images.unsplash.com/photo-1553909489-cd47e0907980?auto=format&fit=crop&w=600&q=80', false, false, 65, true),
  ('f8000000-0000-4000-8000-000000000001', 'd1000000-0000-4000-8000-000000000006', 'Strawberry & Banana', 'strawberry-banana-smoothie', 'Strawberry, banana & vanilla milk', 650, 'https://images.unsplash.com/photo-1502740682-4814588c8a0a?auto=format&fit=crop&w=600&q=80', false, false, 65, true),
  ('f8000000-0000-4000-8000-000000000002', 'd1000000-0000-4000-8000-000000000006', 'Avocado & Dates', 'avocado-dates-smoothie', 'Avocado, medjool dates, banana, milk & walnut nuts', 650, 'https://images.unsplash.com/photo-1502740682-4814588c8a0a?auto=format&fit=crop&w=600&q=80', false, false, 65, true),
  ('f8000000-0000-4000-8000-000000000003', 'd1000000-0000-4000-8000-000000000006', 'Berry-Based', 'berry-based-smoothie', 'Blueberries, raspberries, pomegranate & cherries', 650, 'https://images.unsplash.com/photo-1502740682-4814588c8a0a?auto=format&fit=crop&w=600&q=80', false, false, 65, true),
  ('f8000000-0000-4000-8000-000000000004', 'd1000000-0000-4000-8000-000000000006', 'Lean Green', 'lean-green-smoothie', 'Spinach, pineapple, kale, apple juice, lemon & kiwi', 650, 'https://images.unsplash.com/photo-1502740682-4814588c8a0a?auto=format&fit=crop&w=600&q=80', false, false, 65, true),
  ('f8000000-0000-4000-8000-000000000005', 'd1000000-0000-4000-8000-000000000006', 'Mango & Banana', 'mango-banana-smoothie', 'Mango, banana & vanilla milk', 650, 'https://images.unsplash.com/photo-1502740682-4814588c8a0a?auto=format&fit=crop&w=600&q=80', false, false, 65, true)
on conflict (slug) do update set
  category_id = excluded.category_id,
  name = excluded.name,
  description = excluded.description,
  price_cents = excluded.price_cents,
  image_url = excluded.image_url,
  points_earned = excluded.points_earned,
  is_active = true;
-- Product variants
insert into public.product_variants (id, product_id, name, price_cents, sort_order, is_active)
values
  ('f9000000-0000-4000-8000-000000000001', 'f3000000-0000-4000-8000-000000000001', 'Small', 315, 0, true),
  ('f9000000-0000-4000-8000-000000000002', 'f3000000-0000-4000-8000-000000000002', 'Large', 355, 0, true),
  ('f9000000-0000-4000-8000-000000000003', 'f3000000-0000-4000-8000-000000000003', 'Small', 335, 0, true),
  ('f9000000-0000-4000-8000-000000000004', 'f3000000-0000-4000-8000-000000000004', 'Small', 370, 0, true),
  ('f9000000-0000-4000-8000-000000000005', 'f3000000-0000-4000-8000-000000000005', 'Small', 395, 0, true),
  ('f9000000-0000-4000-8000-000000000006', 'f3000000-0000-4000-8000-000000000006', 'Small', 425, 0, true),
  ('f9000000-0000-4000-8000-000000000007', 'f3000000-0000-4000-8000-000000000006', 'Large', 465, 1, true),
  ('f9000000-0000-4000-8000-000000000008', 'f3000000-0000-4000-8000-000000000007', 'Small', 425, 0, true),
  ('f9000000-0000-4000-8000-000000000009', 'f3000000-0000-4000-8000-000000000007', 'Large', 465, 1, true),
  ('f9000000-0000-4000-8000-000000000010', 'f3000000-0000-4000-8000-000000000008', 'Small', 435, 0, true),
  ('f9000000-0000-4000-8000-000000000011', 'f3000000-0000-4000-8000-000000000008', 'Large', 485, 1, true),
  ('f9000000-0000-4000-8000-000000000012', 'f4000000-0000-4000-8000-000000000001', 'Small', 425, 0, true),
  ('f9000000-0000-4000-8000-000000000013', 'f4000000-0000-4000-8000-000000000001', 'Large', 465, 1, true),
  ('f9000000-0000-4000-8000-000000000014', 'f4000000-0000-4000-8000-000000000002', 'Small', 425, 0, true),
  ('f9000000-0000-4000-8000-000000000015', 'f4000000-0000-4000-8000-000000000002', 'Large', 465, 1, true),
  ('f9000000-0000-4000-8000-000000000016', 'f4000000-0000-4000-8000-000000000003', 'Small', 425, 0, true),
  ('f9000000-0000-4000-8000-000000000017', 'f4000000-0000-4000-8000-000000000003', 'Large', 465, 1, true),
  ('f9000000-0000-4000-8000-000000000018', 'f4000000-0000-4000-8000-000000000004', 'Large', 425, 0, true),
  ('f9000000-0000-4000-8000-000000000019', 'f4000000-0000-4000-8000-000000000005', 'Small', 365, 0, true),
  ('f9000000-0000-4000-8000-000000000020', 'f4000000-0000-4000-8000-000000000005', 'Large', 425, 1, true),
  ('f9000000-0000-4000-8000-000000000021', 'f4000000-0000-4000-8000-000000000006', 'Small', 425, 0, true),
  ('f9000000-0000-4000-8000-000000000022', 'f4000000-0000-4000-8000-000000000006', 'Large', 465, 1, true),
  ('f9000000-0000-4000-8000-000000000023', 'f5000000-0000-4000-8000-000000000001', 'Small', 445, 0, true),
  ('f9000000-0000-4000-8000-000000000024', 'f5000000-0000-4000-8000-000000000001', 'Large', 490, 1, true),
  ('f9000000-0000-4000-8000-000000000025', 'f5000000-0000-4000-8000-000000000002', 'Small', 445, 0, true),
  ('f9000000-0000-4000-8000-000000000026', 'f5000000-0000-4000-8000-000000000002', 'Large', 490, 1, true),
  ('f9000000-0000-4000-8000-000000000027', 'f5000000-0000-4000-8000-000000000003', 'Small', 445, 0, true),
  ('f9000000-0000-4000-8000-000000000028', 'f5000000-0000-4000-8000-000000000003', 'Large', 490, 1, true),
  ('f9000000-0000-4000-8000-000000000029', 'f5000000-0000-4000-8000-000000000004', 'Small', 445, 0, true),
  ('f9000000-0000-4000-8000-000000000030', 'f5000000-0000-4000-8000-000000000004', 'Large', 490, 1, true),
  ('f9000000-0000-4000-8000-000000000031', 'f5000000-0000-4000-8000-000000000005', 'Small', 445, 0, true),
  ('f9000000-0000-4000-8000-000000000032', 'f5000000-0000-4000-8000-000000000005', 'Large', 490, 1, true),
  ('f9000000-0000-4000-8000-000000000033', 'f5000000-0000-4000-8000-000000000006', 'Small', 445, 0, true),
  ('f9000000-0000-4000-8000-000000000034', 'f5000000-0000-4000-8000-000000000006', 'Large', 490, 1, true),
  ('f9000000-0000-4000-8000-000000000035', 'f6000000-0000-4000-8000-000000000001', 'Small', 445, 0, true),
  ('f9000000-0000-4000-8000-000000000036', 'f6000000-0000-4000-8000-000000000001', 'Large', 490, 1, true),
  ('f9000000-0000-4000-8000-000000000037', 'f6000000-0000-4000-8000-000000000002', 'Small', 445, 0, true),
  ('f9000000-0000-4000-8000-000000000038', 'f6000000-0000-4000-8000-000000000002', 'Large', 490, 1, true),
  ('f9000000-0000-4000-8000-000000000039', 'f6000000-0000-4000-8000-000000000003', 'Small', 445, 0, true),
  ('f9000000-0000-4000-8000-000000000040', 'f6000000-0000-4000-8000-000000000003', 'Large', 490, 1, true),
  ('f9000000-0000-4000-8000-000000000041', 'f6000000-0000-4000-8000-000000000004', 'Small', 445, 0, true),
  ('f9000000-0000-4000-8000-000000000042', 'f6000000-0000-4000-8000-000000000004', 'Large', 490, 1, true),
  ('f9000000-0000-4000-8000-000000000043', 'f6000000-0000-4000-8000-000000000005', 'Small', 445, 0, true),
  ('f9000000-0000-4000-8000-000000000044', 'f6000000-0000-4000-8000-000000000005', 'Large', 490, 1, true),
  ('f9000000-0000-4000-8000-000000000045', 'f6000000-0000-4000-8000-000000000006', 'Small', 445, 0, true),
  ('f9000000-0000-4000-8000-000000000046', 'f6000000-0000-4000-8000-000000000006', 'Large', 490, 1, true),
  ('f9000000-0000-4000-8000-000000000047', 'f6000000-0000-4000-8000-000000000007', 'Small', 445, 0, true),
  ('f9000000-0000-4000-8000-000000000048', 'f6000000-0000-4000-8000-000000000007', 'Large', 490, 1, true),
  ('f9000000-0000-4000-8000-000000000049', 'f7000000-0000-4000-8000-000000000001', 'Take', 650, 0, true),
  ('f9000000-0000-4000-8000-000000000050', 'f7000000-0000-4000-8000-000000000002', 'Take', 695, 0, true),
  ('f9000000-0000-4000-8000-000000000051', 'f7000000-0000-4000-8000-000000000003', 'Take', 695, 0, true),
  ('f9000000-0000-4000-8000-000000000052', 'f7000000-0000-4000-8000-000000000004', 'Take', 695, 0, true),
  ('f9000000-0000-4000-8000-000000000053', 'f7000000-0000-4000-8000-000000000005', 'Take', 650, 0, true),
  ('f9000000-0000-4000-8000-000000000054', 'f8000000-0000-4000-8000-000000000001', 'Small', 650, 0, true),
  ('f9000000-0000-4000-8000-000000000055', 'f8000000-0000-4000-8000-000000000001', 'Large', 695, 1, true),
  ('f9000000-0000-4000-8000-000000000056', 'f8000000-0000-4000-8000-000000000002', 'Small', 650, 0, true),
  ('f9000000-0000-4000-8000-000000000057', 'f8000000-0000-4000-8000-000000000002', 'Large', 695, 1, true),
  ('f9000000-0000-4000-8000-000000000058', 'f8000000-0000-4000-8000-000000000003', 'Small', 650, 0, true),
  ('f9000000-0000-4000-8000-000000000059', 'f8000000-0000-4000-8000-000000000003', 'Large', 695, 1, true),
  ('f9000000-0000-4000-8000-000000000060', 'f8000000-0000-4000-8000-000000000004', 'Small', 650, 0, true),
  ('f9000000-0000-4000-8000-000000000061', 'f8000000-0000-4000-8000-000000000004', 'Large', 695, 1, true),
  ('f9000000-0000-4000-8000-000000000062', 'f8000000-0000-4000-8000-000000000005', 'Small', 650, 0, true),
  ('f9000000-0000-4000-8000-000000000063', 'f8000000-0000-4000-8000-000000000005', 'Large', 695, 1, true)
on conflict (product_id, name) do update set
  price_cents = excluded.price_cents,
  sort_order = excluded.sort_order,
  is_active = true;
