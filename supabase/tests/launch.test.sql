-- Step 8: the security audit's fixes and the unused photo clean-up.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(19);

-- ---- Test data. Foreign keys and triggers are off only while building it.

set local session_replication_role = replica;

insert into auth.users (id, email) values
  ('44000000-0000-0000-0000-000000000001', 'reporter@example.test'),
  ('44000000-0000-0000-0000-000000000002', 'admin@example.test');
insert into public.profiles (id, avatar_path) values
  ('44000000-0000-0000-0000-000000000001', 'test/used-avatar.jpg'),
  ('44000000-0000-0000-0000-000000000002', null);
insert into public.admin_users (user_id) values ('44000000-0000-0000-0000-000000000002');
insert into public.reports (
  id, reporter_id, target_type, target_id, reason, details, status, resolved_by,
  resolution_note, resolved_at
) values (
  '44000000-0000-0000-0000-0000000000a1', '44000000-0000-0000-0000-000000000001',
  'product', '44000000-0000-0000-0000-0000000000a2', 'fake', 'It looks fake', 'dismissed',
  '44000000-0000-0000-0000-000000000002', 'Private note', now()
);

insert into public.shops (id, seller_id, name, slug, logo_path, banner_path) values (
  '44000000-0000-0000-0000-000000000011', '44000000-0000-0000-0000-000000000001',
  'Audit Shop', 'audit-shop', 'test/used-logo.jpg', 'test/used-banner.jpg'
);
insert into public.products (id, shop_id, category_id, title) values (
  '44000000-0000-0000-0000-000000000021', '44000000-0000-0000-0000-000000000011',
  '44000000-0000-0000-0000-000000000031', 'Audit product'
);
insert into public.product_images (product_id, storage_path)
  values ('44000000-0000-0000-0000-000000000021', 'test/used-listing.jpg');
insert into public.order_items (
  group_id, product_title, variant_name, image_path, unit_price, quantity, line_total,
  commission_rate, commission_amount
) values (
  '44000000-0000-0000-0000-000000000041', 'Old', 'Default', 'test/used-by-order.jpg',
  100, 1, 100, 1, 1
);
insert into public.home_banners (image_path) values ('test/used-promo.jpg');

insert into storage.objects (bucket_id, name, created_at)
select bucket, 'test/' || file, created
from (values
  ('product-images', 'used-listing.jpg', now() - interval '30 days'),
  ('product-images', 'used-by-order.jpg', now() - interval '30 days'),
  ('product-images', 'unused-listing.jpg', now() - interval '30 days'),
  ('product-images', 'just-uploaded.jpg', now() - interval '1 hour'),
  ('shop-assets', 'used-logo.jpg', now() - interval '30 days'),
  ('shop-assets', 'used-banner.jpg', now() - interval '30 days'),
  ('shop-assets', 'old-logo.jpg', now() - interval '30 days'),
  ('avatars', 'used-avatar.jpg', now() - interval '30 days'),
  ('avatars', 'old-avatar.jpg', now() - interval '30 days'),
  ('banners', 'used-promo.jpg', now() - interval '30 days'),
  ('banners', 'old-promo.jpg', now() - interval '30 days')
) as files (bucket, file, created);

set local session_replication_role = origin;

-- ---- Reports stay private to the admin.

set local role authenticated;
set local request.jwt.claims = '{"sub": "44000000-0000-0000-0000-000000000001", "role": "authenticated"}';

select is(
  (select details from public.reports where id = '44000000-0000-0000-0000-0000000000a1'),
  'It looks fake', 'Reporters can still read what they sent');
select throws_ok(
  $$ select resolution_note from public.reports $$, '42501', null,
  'Reporters cannot read the private note');
select throws_ok(
  $$ select resolved_by from public.reports $$, '42501', null,
  'Reporters cannot see which admin handled it');
select throws_ok(
  $$ select status from public.reports $$, '42501', null,
  'Reporters cannot read the outcome');
select throws_ok(
  $$ select * from public.reports $$, '42501', null,
  'Reporters cannot read every column at once');

-- ---- Settings change only through the audited function.

set local request.jwt.claims = '{"sub": "44000000-0000-0000-0000-000000000002", "role": "authenticated"}';

select throws_ok(
  $$ update public.platform_settings set commission_rate = 50 $$, '42501', null,
  'Even admins cannot change settings directly');
select lives_ok(
  $$ select public.admin_update_settings(2, 6000, 40000) $$,
  'Admins can change settings through the function');

reset role;
select is(
  (select commission_rate from public.platform_settings where country_code = 'BD'),
  2.00::numeric(5, 2), 'The function saved the new rate');
select is(
  (select count(*)::integer from public.admin_actions where action = 'update_settings'
     and admin_id = '44000000-0000-0000-0000-000000000002'),
  1, 'The change is in the admin record');

select is(
  (select coalesce(array_agg(name::text order by name), '{}')
   from public.find_unused_photos(1000) where name like 'test/%'),
  array['test/old-avatar.jpg', 'test/old-logo.jpg', 'test/old-promo.jpg', 'test/unused-listing.jpg'],
  'Only old files that nothing uses are found');

-- ---- Each protected file, spelled out, so a failure names what would be lost.

select ok(not exists (select 1 from public.find_unused_photos(1000) where name = 'test/used-by-order.jpg'),
  'A photo on a past order is kept');
select ok(not exists (select 1 from public.find_unused_photos(1000) where name = 'test/used-listing.jpg'),
  'A listing photo is kept');
select ok(not exists (select 1 from public.find_unused_photos(1000) where name = 'test/just-uploaded.jpg'),
  'A new upload is kept, because its listing may not be saved yet');

select is(
  (select count(*)::integer from public.find_unused_photos(1) where name like 'test/%'),
  1, 'The limit is respected');

-- ---- Nobody outside the server can run the clean-up.

set local role authenticated;
select throws_ok(
  $$ select * from public.find_unused_photos(10) $$, '42501', null,
  'Users cannot list unused photos');
select throws_ok(
  $$ select public.run_photo_cleanup() $$, '42501', null,
  'Users cannot start the clean-up');
set local role anon;
select throws_ok(
  $$ select * from public.find_unused_photos(10) $$, '42501', null,
  'Guests cannot list unused photos');
reset role;

select is(
  (select count(*)::integer from cron.job where jobname = 'clean-unused-photos'),
  1, 'The clean-up is scheduled');

set local role service_role;
select lives_ok(
  $$ select * from public.find_unused_photos(10) $$,
  'The server function can list unused photos');
reset role;

select * from finish();
rollback;
