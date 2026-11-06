begin;

create extension if not exists pgtap with schema extensions;

select plan(49);

insert into auth.users (id, email)
values
  ('00000000-0000-0000-0000-0000000003a1', 'adm-admin@example.test'),
  ('00000000-0000-0000-0000-0000000003a2', 'adm-admin2@example.test'),
  ('00000000-0000-0000-0000-0000000003d1', 'adm-buyer@example.test'),
  ('00000000-0000-0000-0000-0000000003e1', 'adm-seller@example.test');

update auth.users
set phone = '88017600003' || right(id::text, 2), phone_confirmed_at = now()
where email like 'adm-%@example.test';

insert into public.admin_users (user_id)
values ('00000000-0000-0000-0000-0000000003a1'), ('00000000-0000-0000-0000-0000000003a2');

insert into public.seller_profiles (user_id) values ('00000000-0000-0000-0000-0000000003e1');
insert into public.shops (id, seller_id, name, slug, delivery_fee)
values ('33000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000003e1', 'Adm Shop', 'adm-shop', 60);
insert into public.categories (id, name, slug)
values ('23000000-0000-0000-0000-0000000000d1', 'Adm test', 'adm-test');
insert into public.products (id, shop_id, category_id, title, description)
values ('43000000-0000-0000-0000-000000000001', '33000000-0000-0000-0000-000000000001', '23000000-0000-0000-0000-0000000000d1', 'Adm Lamp', 'A lamp used for testing.');
insert into public.product_variants (product_id, price, stock)
values ('43000000-0000-0000-0000-000000000001', 1000, 10);
update public.products set status = 'active' where id = '43000000-0000-0000-0000-000000000001';

create function pg_temp.sign_in(p_user uuid)
returns void
language plpgsql
as $$
begin
  perform set_config('role', 'authenticated', true);
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text,
    true
  );
end;
$$;

-- ---- Audit: nothing was forgotten, however many functions get added later.

select is(
  (select coalesce(array_agg(p.proname::text), '{}') from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname like 'admin\_%'
     and has_function_privilege('anon', p.oid, 'execute')),
  '{}'::text[], 'Guests cannot run any admin function');

select is(
  (select coalesce(array_agg(p.proname::text), '{}') from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname like 'admin\_%'
     and p.prosrc !~ '(require_admin|is_admin)\(\)'),
  '{}'::text[], 'Every admin function checks for an admin');

select is(
  (select coalesce(array_agg(p.proname::text), '{}') from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname like 'admin\_%' and not p.prosecdef),
  '{}'::text[], 'Every admin function runs with fixed rights');

select is(
  (select coalesce(array_agg(p.proname::text), '{}') from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.prosecdef
     and not exists (select 1 from unnest(p.proconfig) c where c like 'search_path=%')),
  '{}'::text[], 'Every function with fixed rights has a fixed search path');

select is(
  (select coalesce(array_agg(c.relname::text), '{}') from pg_class c
   join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity),
  '{}'::text[], 'Row Level Security is on for every table');

select is(
  (select coalesce(array_agg(distinct table_name::text), '{}')
   from information_schema.role_table_grants
   where table_schema = 'public' and grantee = 'anon'
     and privilege_type in ('INSERT', 'UPDATE', 'DELETE', 'TRUNCATE')),
  '{}'::text[], 'Guests cannot write to any table');

select is(
  (select coalesce(array_agg(distinct table_name::text order by table_name::text), '{}')
   from information_schema.role_table_grants
   where table_schema = 'public' and grantee = 'authenticated'
     and privilege_type in ('INSERT', 'UPDATE', 'DELETE', 'TRUNCATE')),
  array['addresses', 'wishlist_items'],
  'Users can write to only the expected tables');

select is(
  (select coalesce(array_agg(table_name::text), '{}')
   from information_schema.role_table_grants
   where table_schema = 'public' and grantee in ('anon', 'authenticated')
     and table_name = 'admin_users'),
  '{}'::text[], 'Nobody can read or add admins');

-- ---- A signed-in non-admin is refused by the server.

select pg_temp.sign_in('00000000-0000-0000-0000-0000000003d1');
select throws_ok($$ select public.admin_get_overview() $$, 'NOT_AN_ADMIN', 'Overview is refused');
select throws_ok($$ select * from public.admin_get_review_queue() $$, 'NOT_AN_ADMIN', 'The queue is refused');
select throws_ok($$ select * from public.admin_list_users() $$, 'NOT_AN_ADMIN', 'Users are refused');
select throws_ok($$ select * from public.admin_list_products() $$, 'NOT_AN_ADMIN', 'Products are refused');
select throws_ok($$ select * from public.admin_list_orders() $$, 'NOT_AN_ADMIN', 'Orders are refused');
select throws_ok($$ select * from public.admin_list_categories() $$, 'NOT_AN_ADMIN', 'Categories are refused');
select throws_ok($$ select * from public.admin_list_reports() $$, 'NOT_AN_ADMIN', 'Reports are refused');
select throws_ok($$ select * from public.admin_list_sellers_owing() $$, 'NOT_AN_ADMIN', 'Sellers owing are refused');
select throws_ok($$ select * from public.admin_list_settlements() $$, 'NOT_AN_ADMIN', 'Settlements are refused');
select throws_ok(
  $$ select public.admin_update_settings(0, 1, 1) $$, 'NOT_AN_ADMIN', 'Changing commission is refused');
select throws_ok(
  $$ select public.admin_set_user_status('00000000-0000-0000-0000-0000000003e1', 'suspended', 'x') $$,
  'NOT_AN_ADMIN', 'Suspending is refused');
select throws_ok(
  $$ select public.admin_set_product_removed('43000000-0000-0000-0000-000000000001', true, 'x') $$,
  'NOT_AN_ADMIN', 'Removing a product is refused');
select throws_ok(
  $$ select public.admin_save_category(null, null, 'X', 'x', null, 0, true) $$,
  'NOT_AN_ADMIN', 'Saving a category is refused');
select throws_ok(
  $$ select public.admin_record_settlement('00000000-0000-0000-0000-0000000003e1', 1, 'bank', 'R') $$,
  'NOT_AN_ADMIN', 'Recording a settlement is refused');
select is((select count(*)::integer from public.admin_actions), 0, 'The admin record cannot be read');
select throws_ok(
  $$ update public.platform_settings set commission_rate = 77 $$,
  '42501', null, 'Users are refused when they change settings directly');
reset role;

select isnt(
  (select commission_rate from public.platform_settings where country_code = 'BD'),
  77.00::numeric(5, 2), 'Settings cannot be changed directly');

-- ---- Overview and the queue.

update public.products set status = 'admin_review' where id = '43000000-0000-0000-0000-000000000001';
insert into public.moderation_reviews (product_id, content_hash, status, ai_decision, reason_code, ai_reason)
values ('43000000-0000-0000-0000-000000000001', 'x', 'done', 'suspicious', 'PRICE', 'Looks too cheap');

select pg_temp.sign_in('00000000-0000-0000-0000-0000000003a1');
select ok((public.admin_get_overview() ->> 'review_queue')::integer >= 1, 'The overview counts the queue');
select is(
  (select ai_reason from public.admin_get_review_queue() where id = '43000000-0000-0000-0000-000000000001'),
  'Looks too cheap', 'The queue shows the AI''s reason');
select public.admin_decide_product('43000000-0000-0000-0000-000000000001', 'approve');
select is(
  (select count(*)::integer from public.admin_get_review_queue() where id = '43000000-0000-0000-0000-000000000001'),
  0, 'A decided product leaves the queue');

-- ---- Suspending a seller hides their shop and products.

select throws_ok(
  $$ select public.admin_set_user_status('00000000-0000-0000-0000-0000000003e1', 'suspended') $$,
  'REASON_REQUIRED', 'Suspending needs a reason');
select throws_ok(
  $$ select public.admin_set_user_status('00000000-0000-0000-0000-0000000003a2', 'suspended', 'x') $$,
  'CANNOT_CHANGE_ADMIN', 'An admin cannot be suspended here');
select public.admin_set_user_status('00000000-0000-0000-0000-0000000003e1', 'suspended', 'Fake goods');
reset role;

select is(
  (select is_active from public.shops where id = '33000000-0000-0000-0000-000000000001'),
  false, 'Suspending a seller turns off their shop');
set local role anon;
select is(
  (select count(*)::integer from public.products where id = '43000000-0000-0000-0000-000000000001'),
  0, 'Their products disappear from the marketplace');
reset role;

select pg_temp.sign_in('00000000-0000-0000-0000-0000000003e1');
select is(public.is_active_seller(), false, 'They cannot sell');
select throws_ok(
  $$ select public.start_conversation('43000000-0000-0000-0000-000000000001') $$,
  'ACCOUNT_SUSPENDED', 'They cannot use the marketplace');
reset role;

select pg_temp.sign_in('00000000-0000-0000-0000-0000000003a1');
select public.admin_set_user_status('00000000-0000-0000-0000-0000000003e1', 'active');
select is(
  (select action from public.admin_actions where target_id = '00000000-0000-0000-0000-0000000003e1' order by id limit 1),
  'set_user_status', 'Suspending is on record');
reset role;
select is(
  (select is_active from public.shops where id = '33000000-0000-0000-0000-000000000001'),
  true, 'Lifting a suspension turns the shop back on');

-- ---- Removing and restoring a product.

select pg_temp.sign_in('00000000-0000-0000-0000-0000000003a1');
select throws_ok(
  $$ select public.admin_set_product_removed('43000000-0000-0000-0000-000000000001', true) $$,
  'REASON_REQUIRED', 'Removing needs a reason');
select public.admin_set_product_removed('43000000-0000-0000-0000-000000000001', true, 'Counterfeit');
reset role;
select is(
  (select body from public.notifications
   where user_id = '00000000-0000-0000-0000-0000000003e1' and title = 'Your listing was removed'),
  'Adm Lamp: Counterfeit', 'The seller is told why');

select pg_temp.sign_in('00000000-0000-0000-0000-0000000003e1');
select throws_ok(
  $$ select public.set_product_paused('43000000-0000-0000-0000-000000000001', false) $$,
  'PRODUCT_NOT_PAUSABLE', 'A seller cannot bring back a removed listing');
reset role;

-- ---- Settings, categories.

select pg_temp.sign_in('00000000-0000-0000-0000-0000000003a1');
select throws_ok(
  $$ select public.admin_update_settings(101, 1, 1) $$, 'INVALID_SETTINGS', 'A rate over 100% is refused');
select throws_ok(
  $$ select public.admin_save_category(null, null, 'Bad', 'Not A Slug', null, 0, true) $$,
  'INVALID_SLUG', 'A bad slug is refused');
select throws_ok(
  $$ select public.admin_save_category(null, null, 'Dup', 'adm-test', null, 0, true) $$,
  'SLUG_TAKEN', 'A slug in use is refused');
select lives_ok(
  $$ select public.admin_save_category(null, '23000000-0000-0000-0000-0000000000d1', 'Sub', 'adm-sub', 'category', 1, true) $$,
  'An admin can add a category');
select throws_ok(
  $$ select public.admin_save_category(null, (select id from public.categories where slug = 'adm-sub'), 'Deep', 'adm-deep', null, 0, true) $$,
  'INVALID_PARENT', 'Categories go only two levels deep');
reset role;

-- ---- Banners.

set local role anon;
select is(
  (select count(*)::integer from public.home_banners where title = 'Off'), 0, 'A hidden banner is not public');
reset role;
insert into public.home_banners (image_path, title, is_active) values ('x.jpg', 'Off', false);
insert into public.home_banners (image_path, title, ends_at) values ('y.jpg', 'Ended', now() - interval '1 day');
insert into public.home_banners (image_path, title) values ('z.jpg', 'Showing');
set local role anon;
select is(
  (select array_agg(title) from public.home_banners where title in ('Off', 'Ended', 'Showing')),
  array['Showing'], 'Only banners showing now are public');
reset role;

-- ---- Settlement: what the Done when asks for.

insert into public.commission_ledger (seller_id, type, amount, note)
values ('00000000-0000-0000-0000-0000000003e1', 'adjustment', 25, 'Test balance');

select pg_temp.sign_in('00000000-0000-0000-0000-0000000003a1');
select is(
  (select balance from public.admin_list_sellers_owing('Adm Shop')), 25.00::numeric, 'Sellers owing are listed');
select public.admin_record_settlement('00000000-0000-0000-0000-0000000003e1', 25, 'bkash', 'TX9');
select is(
  (select count(*)::integer from public.admin_list_sellers_owing('Adm Shop')), 0, 'A paid seller leaves the list');
select is(
  (select reference from public.admin_list_settlements() limit 1), 'TX9', 'The settlement is listed');

select * from finish();

rollback;
