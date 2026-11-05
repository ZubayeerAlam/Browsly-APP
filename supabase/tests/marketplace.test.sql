begin;

create extension if not exists pgtap with schema extensions;

select plan(58);

-- Two sellers, a hidden shop and a normal buyer, separate from any demo data.
insert into auth.users (id, email)
values
  ('00000000-0000-0000-0000-0000000000a1', 'seller-a@example.test'),
  ('00000000-0000-0000-0000-0000000000a2', 'seller-b@example.test'),
  ('00000000-0000-0000-0000-0000000000a3', 'buyer@example.test'),
  ('00000000-0000-0000-0000-0000000000a4', 'other-buyer@example.test');

insert into public.seller_profiles (user_id, payout_number)
values
  ('00000000-0000-0000-0000-0000000000a1', '01711111111'),
  ('00000000-0000-0000-0000-0000000000a2', '01722222222');

insert into public.shops (id, seller_id, name, slug, is_active)
values
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000a1', 'Shop A', 'test-shop-a', true),
  ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-0000000000a2', 'Shop B', 'test-shop-b', false);

insert into public.categories (id, parent_id, name, slug)
values
  ('20000000-0000-0000-0000-000000000001', null, 'Test parent', 'test-parent'),
  ('20000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000001', 'Test child', 'test-child');
insert into public.categories (id, name, slug, is_active)
values ('20000000-0000-0000-0000-000000000003', 'Test hidden', 'test-hidden', false);

insert into public.products (id, shop_id, category_id, title, description, condition, created_at, rating_avg, sold_count)
values
  ('30000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000002',
   'Zebrawood Guitar', 'Handmade acoustic instrument', 'new', now() - interval '1 day', 4.5, 10),
  ('30000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001',
   'Zebrawood Stool', 'Small seat', 'used', now() - interval '2 days', 3.0, 50),
  ('30000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001',
   'নকশি জেব্রা', 'হাতে তৈরি', 'new', now() - interval '3 days', 5.0, 1),
  ('30000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001',
   'Zebrawood Draft', 'Not published', 'new', now(), 0, 0),
  ('30000000-0000-0000-0000-000000000005', '10000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000001',
   'Zebrawood In Hidden Shop', 'Shop is off', 'new', now(), 0, 0),
  ('30000000-0000-0000-0000-000000000006', '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000003',
   'Zebrawood In Hidden Category', 'Category is off', 'new', now(), 0, 0);

insert into public.product_variants (id, product_id, name, options, price, compare_at_price, stock, is_active)
values
  ('40000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', 'Red', '{"colour": "Red"}', 500, 700, 3, true),
  ('40000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000001', 'Blue', '{"colour": "Blue"}', 800, null, 2, true),
  ('40000000-0000-0000-0000-000000000003', '30000000-0000-0000-0000-000000000001', 'Off', '{"colour": "Off"}', 100, null, 9, false),
  ('40000000-0000-0000-0000-000000000004', '30000000-0000-0000-0000-000000000002', 'Default', '{}', 300, null, 0, true),
  ('40000000-0000-0000-0000-000000000005', '30000000-0000-0000-0000-000000000003', 'Default', '{}', 900, null, 1, true),
  ('40000000-0000-0000-0000-000000000006', '30000000-0000-0000-0000-000000000004', 'Default', '{}', 50, null, 1, true),
  ('40000000-0000-0000-0000-000000000007', '30000000-0000-0000-0000-000000000005', 'Default', '{}', 60, null, 1, true),
  ('40000000-0000-0000-0000-000000000008', '30000000-0000-0000-0000-000000000006', 'Default', '{}', 70, null, 1, true);

insert into public.product_images (product_id, storage_path, sort_order)
values
  ('30000000-0000-0000-0000-000000000001', 'a/second.jpg', 1),
  ('30000000-0000-0000-0000-000000000001', 'a/first.jpg', 0),
  ('30000000-0000-0000-0000-000000000004', 'a/draft.jpg', 0);

update public.products set status = 'active'
where id in (
  '30000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000002',
  '30000000-0000-0000-0000-000000000003', '30000000-0000-0000-0000-000000000005',
  '30000000-0000-0000-0000-000000000006'
);

-- The product summary follows its active variants.
select results_eq(
  $$ select min_price, compare_at_price, total_stock from public.products
     where id = '30000000-0000-0000-0000-000000000001' $$,
  $$ values (500.00::numeric(12,2), 700.00::numeric(12,2), 5) $$,
  'A product shows its cheapest active variant and total stock'
);

update public.product_variants set price = 650, compare_at_price = null
where id = '40000000-0000-0000-0000-000000000001';
select is(
  (select min_price from public.products where id = '30000000-0000-0000-0000-000000000001'),
  650.00::numeric(12,2),
  'The summary updates when a variant changes'
);
update public.product_variants set price = 500, compare_at_price = 700
where id = '40000000-0000-0000-0000-000000000001';

select throws_ok(
  $$ update public.products set min_price = null, status = 'active'
     where id = '30000000-0000-0000-0000-000000000001' $$,
  '23514',
  null,
  'A live product must have a price'
);

select throws_ok(
  $$ insert into public.product_variants (product_id, options, price, compare_at_price)
     values ('30000000-0000-0000-0000-000000000001', '{"colour": "Bad"}', 500, 400) $$,
  '23514',
  null,
  'A discount must be lower than the original price'
);

-- Guests.
set local role anon;
set local request.jwt.claims = '{"role": "anon"}';

select results_eq(
  $$ select id from public.products where id::text like '30000000-%' order by id $$,
  $$ values
    ('30000000-0000-0000-0000-000000000001'::uuid),
    ('30000000-0000-0000-0000-000000000002'::uuid),
    ('30000000-0000-0000-0000-000000000003'::uuid),
    ('30000000-0000-0000-0000-000000000006'::uuid) $$,
  'Guests cannot read drafts or products of hidden shops'
);

select is(
  (select count(*)::int from public.product_variants where id = '40000000-0000-0000-0000-000000000006'),
  0,
  'Guests cannot read a draft product''s variants'
);

select is(
  (select count(*)::int from public.product_images where storage_path = 'a/draft.jpg'),
  0,
  'Guests cannot read a draft product''s images'
);

select is(
  (select count(*)::int from public.product_variants where id = '40000000-0000-0000-0000-000000000003'),
  0,
  'Guests cannot read inactive variants'
);

select is(
  (select count(*)::int from public.shops where slug = 'test-shop-b'),
  0,
  'Guests cannot read hidden shops'
);

select throws_ok(
  $$ select seller_id from public.shops limit 1 $$,
  '42501',
  null,
  'Guests cannot read who owns a shop'
);

select throws_ok(
  $$ select * from public.seller_profiles $$,
  '42501',
  null,
  'Guests cannot read seller profiles'
);

select throws_ok(
  $$ select * from public.wishlist_items $$,
  '42501',
  null,
  'Guests have no wishlist'
);

select throws_ok(
  $$ select * from public.get_wishlist() $$,
  '42501',
  null,
  'Guests cannot call the wishlist function'
);

-- Search: filters.
create function pg_temp.search_ids(
  p_query text default null,
  p_category_id uuid default null,
  p_min_price numeric default null,
  p_max_price numeric default null,
  p_condition public.product_condition default null,
  p_min_rating numeric default null,
  p_in_stock_only boolean default false,
  p_sort public.product_sort default 'newest'
)
returns text
language sql
as $$
  select coalesce(string_agg(right(id::text, 1), ',' order by ord), '')
  from (
    select id, row_number() over () as ord
    from public.search_products(
      p_query => p_query,
      p_category_id => p_category_id,
      p_shop_id => '10000000-0000-0000-0000-000000000001',
      p_min_price => p_min_price,
      p_max_price => p_max_price,
      p_condition => p_condition,
      p_min_rating => p_min_rating,
      p_in_stock_only => p_in_stock_only,
      p_sort => p_sort
    )
  ) as rows;
$$;
grant execute on function pg_temp.search_ids to anon, authenticated;

select is(pg_temp.search_ids(), '1,2,3', 'Search lists live products, newest first');
select is(pg_temp.search_ids(p_query => 'guit'), '1', 'Search matches the start of a word');
select is(pg_temp.search_ids(p_query => 'ZEBRAWOOD guitar'), '1', 'Search ignores case and needs every word');
select is(pg_temp.search_ids(p_query => 'acoustic'), '1', 'Search also matches the description');
select is(pg_temp.search_ids(p_query => 'guitr'), '1', 'Search forgives a small typo');
select is(pg_temp.search_ids(p_query => 'নকশি'), '3', 'Search finds Bangla text');
select is(pg_temp.search_ids(p_query => 'no-such-thing-here'), '', 'Search can find nothing');
select lives_ok(
  $$ select * from public.search_products(p_query => $q$a' & !b:* | (c) \ <d>$q$) $$,
  'Special characters in a search cannot break the query'
);
select is(
  pg_temp.search_ids(p_category_id => '20000000-0000-0000-0000-000000000001'),
  '1,2,3',
  'A parent category includes its subcategories'
);
select is(
  pg_temp.search_ids(p_category_id => '20000000-0000-0000-0000-000000000002'),
  '1',
  'A subcategory shows only its own products'
);
select is(pg_temp.search_ids(p_min_price => 400, p_max_price => 600), '1', 'Search filters by price');
select is(pg_temp.search_ids(p_condition => 'used'), '2', 'Search filters by condition');
select is(pg_temp.search_ids(p_min_rating => 4.5), '1,3', 'Search filters by rating');
select is(pg_temp.search_ids(p_in_stock_only => true), '1,3', 'Search can hide sold-out products');

-- Search: sorting.
select is(pg_temp.search_ids(p_sort => 'price_low'), '2,1,3', 'Sorts by lowest price');
select is(pg_temp.search_ids(p_sort => 'price_high'), '3,1,2', 'Sorts by highest price');
select is(pg_temp.search_ids(p_sort => 'rating'), '3,1,2', 'Sorts by rating');
select is(pg_temp.search_ids(p_sort => 'popular'), '2,1,3', 'Sorts by most sold');
select is(
  pg_temp.search_ids(p_query => 'guitar', p_sort => 'relevance'),
  '1',
  'Sorts by relevance when searching'
);

-- Search: paging walks every sort without repeats or gaps.
select is(
  (
    with recursive pages as (
      select 1 as page, s.id, s.cursor_key
      from public.search_products(
        p_shop_id => '10000000-0000-0000-0000-000000000001', p_sort => 'price_low', p_limit => 1
      ) s
      union all
      select pages.page + 1, n.id, n.cursor_key
      from pages
      cross join lateral public.search_products(
        p_shop_id => '10000000-0000-0000-0000-000000000001', p_sort => 'price_low', p_limit => 1,
        p_cursor_key => pages.cursor_key, p_cursor_id => pages.id
      ) n
    )
    select string_agg(right(id::text, 1), ',' order by page) from pages
  ),
  '2,1,3',
  'Cursor paging returns each product once, in order'
);

select is(
  (select image_path from public.search_products(p_query => 'guitar')),
  'a/first.jpg',
  'Search returns the first photo'
);

select is(
  (select count(*)::int from public.search_products(p_limit => 100000)) <= 60,
  true,
  'A page can never be larger than 60 rows'
);

-- Category counts.
select is(
  (select product_count from public.get_categories_with_counts() where slug = 'test-parent'),
  3,
  'A category counts live products, including in subcategories'
);
select is(
  (select product_count from public.get_categories_with_counts() where slug = 'test-child'),
  1,
  'A subcategory counts only its own products'
);
select is(
  (select count(*)::int from public.get_categories_with_counts() where slug = 'test-hidden'),
  0,
  'Hidden categories are not listed'
);

-- Clients cannot change the catalog directly.
reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub": "00000000-0000-0000-0000-0000000000a1", "role": "authenticated"}';

select throws_ok(
  $$ update public.products set status = 'active' where id = '30000000-0000-0000-0000-000000000004' $$,
  '42501',
  null,
  'A seller cannot publish their own product'
);
select throws_ok(
  $$ update public.product_variants set price = 1 where id = '40000000-0000-0000-0000-000000000001' $$,
  '42501',
  null,
  'A client cannot change a price directly'
);
select throws_ok(
  $$ insert into public.categories (name, slug) values ('Mine', 'mine') $$,
  '42501',
  null,
  'A client cannot add categories'
);

-- Sellers see more of their own catalog, but not of anyone else's.
select is(
  (select count(*)::int from public.products where id = '30000000-0000-0000-0000-000000000004'),
  1,
  'A seller can read their own draft'
);
select is(
  (select count(*)::int from public.product_variants where id = '40000000-0000-0000-0000-000000000003'),
  1,
  'A seller can read their own inactive variant'
);
select is(
  (select count(*)::int from public.products where id = '30000000-0000-0000-0000-000000000005'),
  0,
  'A seller cannot read another seller''s hidden shop''s products'
);
select is(
  (select count(*)::int from public.seller_profiles),
  1,
  'A seller reads only their own seller profile'
);
select is(
  pg_temp.search_ids(),
  '1,2,3',
  'Search never shows a seller''s own draft'
);

-- Wishlist.
reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub": "00000000-0000-0000-0000-0000000000a3", "role": "authenticated"}';

select lives_ok(
  $$ insert into public.wishlist_items (product_id) values ('30000000-0000-0000-0000-000000000001') $$,
  'A user can save a live product'
);
select lives_ok(
  $$ insert into public.wishlist_items (product_id) values ('30000000-0000-0000-0000-000000000002') $$,
  'A user can save a second product'
);
select lives_ok(
  $$ insert into public.wishlist_items (product_id) values ('30000000-0000-0000-0000-000000000001')
     on conflict do nothing $$,
  'Saving twice is harmless'
);
select throws_ok(
  $$ insert into public.wishlist_items (user_id, product_id)
     values ('00000000-0000-0000-0000-0000000000a4', '30000000-0000-0000-0000-000000000001') $$,
  '42501',
  null,
  'A user cannot save to someone else''s wishlist'
);
select throws_ok(
  $$ insert into public.wishlist_items (product_id) values ('30000000-0000-0000-0000-000000000004') $$,
  '42501',
  null,
  'A user cannot save a product that isn''t live'
);
select is(
  (select count(*)::int from public.get_wishlist()),
  2,
  'A user reads their saved products'
);

reset role;
update public.products set status = 'paused' where id = '30000000-0000-0000-0000-000000000002';
set local role authenticated;
set local request.jwt.claims = '{"sub": "00000000-0000-0000-0000-0000000000a3", "role": "authenticated"}';

select is(
  (select count(*)::int from public.get_wishlist()),
  1,
  'A saved product that stops being live leaves the list'
);

reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub": "00000000-0000-0000-0000-0000000000a4", "role": "authenticated"}';

select is((select count(*)::int from public.wishlist_items), 0, 'A user cannot read someone else''s wishlist');
select is((select count(*)::int from public.get_wishlist()), 0, 'The wishlist function shows only your own');

delete from public.wishlist_items where product_id = '30000000-0000-0000-0000-000000000001';

reset role;
select is(
  (select count(*)::int from public.wishlist_items where user_id = '00000000-0000-0000-0000-0000000000a3'),
  2,
  'A user cannot remove from someone else''s wishlist'
);

-- Deleting a seller's account removes their shop and listings, and doesn't fail.
delete from auth.users where id = '00000000-0000-0000-0000-0000000000a1';
select is(
  (select count(*)::int from public.products where shop_id = '10000000-0000-0000-0000-000000000001'),
  0,
  'Deleting a seller removes their listings'
);
select is(
  (select count(*)::int from public.wishlist_items where user_id = '00000000-0000-0000-0000-0000000000a3'),
  0,
  'Deleted listings leave wishlists'
);

select * from finish();

rollback;
