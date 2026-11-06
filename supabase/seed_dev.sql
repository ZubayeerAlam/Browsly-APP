-- DEVELOPMENT ONLY: demo sellers and products. Never apply this to production.
--
-- The demo sellers have no password, so nobody can sign in as them. The photos
-- are plain generated images from supabase/seed_images/demo.

-- A local admin for the web panel. In production, admins are added by hand:
--   insert into public.admin_users (user_id) values ('<their account id>');
insert into auth.users (
  id, instance_id, aud, role, email, email_confirmed_at, encrypted_password,
  raw_user_meta_data, raw_app_meta_data,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  email_change_token_current, phone_change, phone_change_token, reauthentication_token,
  created_at, updated_at
)
values (
  'a0000000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated', 'admin@browsly.test', now(),
  extensions.crypt('local-admin-password', extensions.gen_salt('bf')),
  '{"full_name": "Local Admin"}', '{"provider": "email", "providers": ["email"]}',
  '', '', '', '', '', '', '', '',
  now(), now()
)
on conflict (id) do nothing;

insert into auth.identities (
  id, user_id, provider_id, provider, identity_data, last_sign_in_at, created_at, updated_at
)
values (
  'a0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000001',
  'a0000000-0000-4000-8000-000000000001', 'email',
  '{"sub": "a0000000-0000-4000-8000-000000000001", "email": "admin@browsly.test", "email_verified": true}',
  now(), now(), now()
)
on conflict do nothing;

insert into public.admin_users (user_id)
values ('a0000000-0000-4000-8000-000000000001')
on conflict (user_id) do nothing;

insert into auth.users (
  id, instance_id, aud, role, email, email_confirmed_at, raw_user_meta_data,
  confirmation_token, recovery_token, email_change_token_new, email_change
)
values
  ('d0000000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'demo-seller-1@example.test', now(),
   '{"full_name": "Demo Seller One"}', '', '', '', ''),
  ('d0000000-0000-4000-8000-000000000002', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'demo-seller-2@example.test', now(),
   '{"full_name": "Demo Seller Two"}', '', '', '', ''),
  ('d0000000-0000-4000-8000-000000000003', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'demo-seller-3@example.test', now(),
   '{"full_name": "Demo Seller Three"}', '', '', '', '')
on conflict (id) do nothing;

insert into public.seller_profiles (user_id, terms_accepted_at)
select id, now() from auth.users
where id in (
  'd0000000-0000-4000-8000-000000000001',
  'd0000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000003'
)
on conflict (user_id) do nothing;

insert into public.shops (
  id, seller_id, name, slug, description, region_id, delivery_fee, rating_avg, rating_count
)
select
  shop.id::uuid, shop.seller_id::uuid, shop.name, shop.slug, shop.description,
  (select r.id from public.regions r where r.level = 'district' and r.name = shop.district),
  shop.delivery_fee, shop.rating_avg, shop.rating_count
from (
  values
    ('5a000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8000-000000000001',
     'Dhaka Style House', 'dhaka-style-house',
     'Everyday clothing and shoes, packed with care in Dhaka.',
     'Dhaka', 60.00, 4.60, 128),
    ('5a000000-0000-4000-8000-000000000002', 'd0000000-0000-4000-8000-000000000002',
     'Sylhet Gadget Corner', 'sylhet-gadget-corner',
     'Phones, audio and accessories at fair fixed prices.',
     'Sylhet', 80.00, 4.30, 57),
    ('5a000000-0000-4000-8000-000000000003', 'd0000000-0000-4000-8000-000000000003',
     'Khulna Home & Books', 'khulna-home-books',
     'Home goods, beauty, sports gear and books.',
     'Khulna', 100.00, 4.80, 203)
) as shop (id, seller_id, name, slug, description, district, delivery_fee, rating_avg, rating_count)
on conflict (id) do nothing;

-- All are live unless a status is given. Older products get an earlier date.
insert into public.products (
  id, shop_id, category_id, title, description, condition, status,
  rating_avg, rating_count, sold_count, created_at
)
select
  ('b0000000-0000-4000-8000-' || lpad(p.n::text, 12, '0'))::uuid,
  ('5a000000-0000-4000-8000-00000000000' || p.shop)::uuid,
  (select c.id from public.categories c where c.slug = p.category),
  p.title, p.description, p.condition::public.product_condition, 'draft',
  p.rating, p.rating_count, p.sold,
  now() - make_interval(hours => p.n * 5)
from (
  values
    (1, 1, 'fashion-men', 'Classic Cotton Panjabi', 'Soft cotton panjabi for everyday wear and festivals.', 'new', 4.7, 42, 310),
    (2, 1, 'fashion-men', 'Slim Fit Denim Jeans', 'Stretch denim with a comfortable slim fit.', 'new', 4.4, 31, 185),
    (3, 1, 'fashion-women', 'Printed Georgette Kurti', 'Light georgette kurti with a soft floral print.', 'new', 4.8, 64, 402),
    (4, 1, 'fashion-women', 'Handloom Cotton Saree', 'Breathable handloom saree in bright colours.', 'new', 4.9, 88, 256),
    (5, 1, 'fashion-shoes', 'Leather Everyday Sandals', 'Durable leather sandals with a cushioned sole.', 'new', 4.2, 18, 97),
    (6, 1, 'fashion-shoes', 'Running Sneakers', 'Light sneakers with a breathable mesh upper.', 'used', 3.9, 7, 21),
    (7, 2, 'electronics-audio', 'Wireless Bluetooth Headphones', 'Over-ear headphones with 30 hours of battery life.', 'new', 4.6, 53, 340),
    (8, 2, 'electronics-audio', 'Portable Bluetooth Speaker', 'Pocket speaker with deep bass and a splash-proof body.', 'new', 4.3, 26, 148),
    (9, 2, 'electronics-audio', 'Wired Earphones with Mic', 'Clear sound and a built-in microphone for calls.', 'new', 3.8, 12, 75),
    (10, 2, 'electronics-phones', 'Refurbished Android Phone 128GB', 'Tested and cleaned, with a 128GB drive and a good battery.', 'used', 4.1, 9, 33),
    (11, 2, 'electronics-accessories', 'Fast Charging Power Bank 20000mAh', 'Charges two devices at once, with a fast-charge port.', 'new', 4.5, 37, 221),
    (12, 2, 'electronics-accessories', 'Silicone Phone Case', 'Slim case with soft-touch grip and raised edges.', 'new', 4.0, 15, 130),
    (13, 3, 'home-furniture', 'Wooden Study Table', 'Solid wood table with a drawer, for small rooms.', 'new', 4.7, 21, 44),
    (14, 3, 'home-furniture', 'Used Bamboo Bookshelf', 'Five-shelf bamboo unit in good used condition.', 'used', 4.2, 4, 6),
    (15, 3, 'home-kitchen', 'Non-Stick Fry Pan 28cm', 'Even heat and an easy-clean non-stick coating.', 'new', 4.4, 29, 172),
    (16, 3, 'home-kitchen', 'Stainless Steel Water Bottle', 'Keeps drinks cold for 12 hours. Leak-proof lid.', 'new', 4.6, 40, 263),
    (17, 3, 'beauty', 'Herbal Face Wash', 'Gentle daily face wash with neem and aloe.', 'new', 4.3, 33, 289),
    (18, 3, 'beauty', 'Coconut Hair Oil 200ml', 'Pure coconut oil for strong and shiny hair.', 'new', 4.5, 47, 371),
    (19, 3, 'sports', 'Cricket Bat for Practice', 'Kashmir willow bat, suited to tape-ball and practice.', 'new', 4.4, 22, 91),
    (20, 3, 'sports', 'Football Size 5', 'Hand-stitched match football for grass and turf.', 'new', 4.1, 16, 118),
    (21, 3, 'books', 'Bangla Short Story Collection', 'A collection of modern Bangla short stories.', 'used', 4.8, 11, 52),
    (22, 3, 'books', 'হাতে বোনা নকশি কাঁথা', 'ঐতিহ্যবাহী নকশায় হাতে বোনা নরম সুতির কাঁথা।', 'new', 5.0, 6, 14),
    -- Never shown publicly: these prove that hidden statuses stay hidden.
    (23, 1, 'fashion-men', 'Hidden Paused Shirt', 'A paused product.', 'new', 0, 0, 0),
    (24, 2, 'electronics-audio', 'Hidden Draft Earbuds', 'A draft product.', 'new', 0, 0, 0)
) as p (n, shop, category, title, description, condition, rating, rating_count, sold)
on conflict (id) do nothing;

-- Products with colours and sizes, including a sold-out combination and a
-- discount on the cheapest variant. Those with no special variants come after.
insert into public.product_variants (product_id, name, options, price, compare_at_price, stock)
select
  ('b0000000-0000-4000-8000-' || lpad(v.n::text, 12, '0'))::uuid,
  concat_ws(' / ', v.colour, v.size),
  jsonb_strip_nulls(jsonb_build_object('colour', v.colour, 'size', v.size)),
  v.price, v.compare_at, v.stock
from (
  values
    (1, 'White', 'M', 1450.00, 1800.00, 12),
    (1, 'White', 'L', 1450.00, 1800.00, 9),
    (1, 'White', 'XL', 1550.00, 1900.00, 0),
    (1, 'Navy', 'M', 1500.00, null, 6),
    (1, 'Navy', 'L', 1500.00, null, 4),
    (2, 'Blue', '30', 1950.00, 2400.00, 8),
    (2, 'Blue', '32', 1950.00, 2400.00, 10),
    (2, 'Black', '32', 2050.00, null, 5),
    (3, 'Rose', 'S', 1250.00, 1600.00, 7),
    (3, 'Rose', 'M', 1250.00, 1600.00, 11),
    (3, 'Teal', 'M', 1250.00, null, 3),
    (5, 'Brown', '41', 1100.00, null, 6),
    (5, 'Brown', '42', 1100.00, null, 4),
    (5, 'Black', '42', 1150.00, null, 2),
    (6, 'Grey', '42', 900.00, null, 1),
    (7, 'Black', null, 3200.00, 4000.00, 15),
    (7, 'White', null, 3300.00, null, 5),
    (12, 'Black', null, 250.00, null, 40),
    (12, 'Clear', null, 220.00, 300.00, 25)
) as v (n, colour, size, price, compare_at, stock)
on conflict (product_id, options) do nothing;

insert into public.product_variants (product_id, price, compare_at_price, stock)
select
  ('b0000000-0000-4000-8000-' || lpad(v.n::text, 12, '0'))::uuid,
  v.price, v.compare_at, v.stock
from (
  values
    (4, 3800.00, 4500.00, 5), (8, 1650.00, null, 18), (9, 350.00, 450.00, 60),
    (10, 11500.00, 13000.00, 2), (11, 2100.00, 2500.00, 22), (13, 8500.00, null, 3),
    (14, 2200.00, null, 1), (15, 1250.00, 1500.00, 14), (16, 780.00, null, 35),
    (17, 320.00, null, 50), (18, 260.00, 300.00, 70), (19, 1400.00, null, 9),
    (20, 950.00, 1200.00, 0), (21, 280.00, null, 4), (22, 2600.00, null, 2),
    (23, 800.00, null, 3), (24, 1200.00, null, 3)
) as v (n, price, compare_at, stock)
on conflict (product_id, options) do nothing;

insert into public.product_images (product_id, storage_path, sort_order)
select
  ('b0000000-0000-4000-8000-' || lpad(p.n::text, 12, '0'))::uuid,
  'demo/' || p.prefix || '-' || (((p.n + i) % 3) + 1) || '.jpg',
  i
from (
  values
    (1, 'fashion'), (2, 'fashion'), (3, 'fashion'), (4, 'fashion'), (5, 'fashion'), (6, 'fashion'),
    (7, 'electronics'), (8, 'electronics'), (9, 'electronics'), (10, 'electronics'),
    (11, 'electronics'), (12, 'electronics'), (13, 'home'), (14, 'home'), (15, 'home'),
    (16, 'home'), (17, 'beauty'), (18, 'beauty'), (19, 'sports'), (20, 'sports'),
    (21, 'books'), (22, 'books'), (23, 'fashion'), (24, 'electronics')
) as p (n, prefix)
cross join generate_series(0, 2) as i
on conflict (product_id, sort_order) do nothing;

-- Publish last, now that every product has a price.
update public.products
set status = case title
  when 'Hidden Paused Shirt' then 'paused'::public.product_status
  when 'Hidden Draft Earbuds' then 'draft'::public.product_status
  else 'active'::public.product_status
end
where id::text like 'b0000000-0000-4000-8000-%';

-- Lets the database wake the local moderate-product function. These values are
-- for local development only. Production has its own secrets in the Vault.
select vault.create_secret('http://supabase_kong_browsly:8000', 'project_url')
where not exists (select 1 from vault.secrets where name = 'project_url');
select vault.create_secret('local-dev-moderation-secret', 'moderation_secret')
where not exists (select 1 from vault.secrets where name = 'moderation_secret');
