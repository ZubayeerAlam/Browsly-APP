begin;

create extension if not exists pgtap with schema extensions;

select plan(73);

insert into auth.users (id, email)
values
  ('00000000-0000-0000-0000-0000000000b1', 'seller@example.test'),
  ('00000000-0000-0000-0000-0000000000b2', 'other-seller@example.test'),
  ('00000000-0000-0000-0000-0000000000b3', 'unverified@example.test'),
  ('00000000-0000-0000-0000-0000000000b4', 'admin@example.test');

update auth.users
set phone = '880171000000' || right(id::text, 1), phone_confirmed_at = now()
where id in (
  '00000000-0000-0000-0000-0000000000b1',
  '00000000-0000-0000-0000-0000000000b2'
);

insert into public.admin_users (user_id) values ('00000000-0000-0000-0000-0000000000b4');

insert into public.categories (id, name, slug)
values ('20000000-0000-0000-0000-0000000000c1', 'Selling test', 'selling-test');

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

create function pg_temp.district()
returns uuid
language sql
as $$ select id from public.regions where level = 'district' and name = 'Dhaka' limit 1 $$;
grant execute on function pg_temp.district() to authenticated;


-- Guests cannot sell.
set local role anon;
select throws_ok(
  $$ select public.become_seller('Nope', '', null, 0, null, true) $$,
  '42501', null, 'Guests cannot open a shop'
);
select throws_ok(
  $$ select public.save_product(null, 'Nope', '', null, 'new', '[]', '{}') $$,
  '42501', null, 'Guests cannot save listings'
);

-- Opening a shop.
reset role;
select pg_temp.sign_in('00000000-0000-0000-0000-0000000000b3');
select throws_ok(
  $$ select public.become_seller('Shop', '', pg_temp.district(), 50, null, true) $$,
  'P0001', 'PHONE_NOT_VERIFIED', 'A shop needs a verified phone'
);

reset role;
select pg_temp.sign_in('00000000-0000-0000-0000-0000000000b1');
select throws_ok(
  $$ select public.become_seller('Shop', '', pg_temp.district(), 50, null, false) $$,
  'P0001', 'TERMS_NOT_ACCEPTED', 'A shop needs the seller terms accepted'
);
select throws_ok(
  $$ select public.become_seller('Shop', '', null, 50, null, true) $$,
  'P0001', 'INVALID_REGION', 'A shop needs a real district'
);
select throws_ok(
  $$ select public.become_seller('Shop', '', pg_temp.district(), -1, null, true) $$,
  '23514', null, 'A delivery fee cannot be negative'
);
select ok(
  public.become_seller('নতুন দোকান', 'About', pg_temp.district(), 50, '01710000001', true) is not null,
  'A verified user can open a shop, even with a Bangla name'
);
select is(
  public.become_seller('Second try', '', pg_temp.district(), 99, null, true),
  public.current_shop_id(),
  'Opening a shop twice returns the same shop'
);
select is(
  (select delivery_fee from public.shops where id = public.current_shop_id()),
  50.00::numeric(12,2),
  'The second call changes nothing'
);
select ok(public.is_active_seller(), 'The new shop owner can sell');

create temp table ids (name text primary key, id uuid);
grant all on ids to authenticated, service_role;
insert into ids values ('shop_a', public.current_shop_id());

-- Editing a shop.
update public.shops set delivery_fee = 70 where id = public.current_shop_id();
select is(
  (select delivery_fee from public.shops where id = public.current_shop_id()),
  70.00::numeric(12,2),
  'A seller can change their delivery fee'
);
select throws_ok(
  $$ update public.shops set is_active = false $$,
  '42501', null, 'A seller cannot change whether a shop is active'
);
select throws_ok(
  $$ update public.shops set rating_avg = 5 $$,
  '42501', null, 'A seller cannot change their rating'
);
select throws_ok(
  $$ update public.shops set logo_path = 'someone-else/logo.jpg' where id = public.current_shop_id() $$,
  '42501', null, 'A shop logo must be in the shop''s own folder'
);

reset role;
select pg_temp.sign_in('00000000-0000-0000-0000-0000000000b2');
select ok(
  public.become_seller('Other shop', '', pg_temp.district(), 0, null, true) is not null,
  'A second seller opens a shop'
);
insert into ids values ('shop_b', public.current_shop_id());

update public.shops set delivery_fee = 1 where id = (select id from ids where name = 'shop_a');
reset role;
select is(
  (select delivery_fee from public.shops where id = (select id from ids where name = 'shop_a')),
  70.00::numeric(12,2),
  'A seller cannot change another seller''s shop'
);

-- Photo files are created directly here, as the storage service would.
insert into storage.objects (bucket_id, name)
select 'product-images', (select id::text from ids where name = 'shop_a') || '/' || n || '.jpg'
from unnest(array['one', 'two', 'three', 'four', 'five', 'six']) as n;
insert into storage.objects (bucket_id, name)
select 'product-images', (select id::text from ids where name = 'shop_b') || '/theirs.jpg';

create function pg_temp.photos(variadic p_names text[])
returns text[]
language sql
as $$
  select array_agg((select id::text from ids where name = 'shop_a') || '/' || n || '.jpg' order by o)
  from unnest(p_names) with ordinality as t (n, o);
$$;
grant execute on function pg_temp.photos(text[]) to authenticated;

create function pg_temp.save(
  p_id uuid,
  p_title text default 'Good Lamp',
  p_price numeric default 500,
  p_stock integer default 3,
  p_paths text[] default pg_temp.photos('one')
)
returns uuid
language sql
as $$
  select public.save_product(
    p_id, p_title, 'A very good lamp for your desk.',
    '20000000-0000-0000-0000-0000000000c1', 'new',
    jsonb_build_array(jsonb_build_object('options', '{}'::jsonb, 'price', p_price, 'stock', p_stock)),
    p_paths
  );
$$;
grant execute on function pg_temp.save(uuid, text, numeric, integer, text[]) to authenticated;

-- Saving listings.
select pg_temp.sign_in('00000000-0000-0000-0000-0000000000b1');

select throws_ok(
  $$ select pg_temp.save(null, p_paths => pg_temp.photos('one','two','three','four','five','six')) $$,
  'P0001', 'TOO_MANY_PHOTOS', 'A listing has at most 5 photos'
);
select throws_ok(
  $$ select pg_temp.save(null, p_paths => pg_temp.photos('missing')) $$,
  'P0001', 'INVALID_PHOTO', 'A photo must be a real uploaded file'
);
select throws_ok(
  $$ select pg_temp.save(null, p_paths => array[(select id::text from ids where name = 'shop_b') || '/theirs.jpg']) $$,
  'P0001', 'INVALID_PHOTO', 'A seller cannot use another seller''s photo'
);
select throws_ok(
  $$ select public.save_product(null, 'Bad Options', '', '20000000-0000-0000-0000-0000000000c1', 'new',
       '[{"options": {"weight": "1kg"}, "price": 5, "stock": 1}]', '{}') $$,
  'P0001', 'INVALID_VARIANTS', 'Only colours and sizes are accepted'
);
select throws_ok(
  $$ select public.save_product(null, 'Same Twice', '', '20000000-0000-0000-0000-0000000000c1', 'new',
       '[{"options": {"size": "M"}, "price": 5, "stock": 1}, {"options": {"size": "M"}, "price": 6, "stock": 1}]', '{}') $$,
  'P0001', 'INVALID_VARIANTS', 'The same option cannot be listed twice'
);
select throws_ok(
  $$ select public.save_product(null, 'No Variants', '', '20000000-0000-0000-0000-0000000000c1', 'new', '[]', '{}') $$,
  'P0001', 'INVALID_VARIANTS', 'A listing needs at least one variant'
);

insert into ids values ('p1', pg_temp.save(null));
select is(
  (select status::text from public.products where id = (select id from ids where name = 'p1')),
  'draft',
  'A new listing starts as a draft'
);
select is(
  (select count(*)::int from public.search_products(p_shop_id => (select id from ids where name = 'shop_a'))),
  0,
  'A draft is not in the marketplace'
);

-- Clients cannot write listings directly.
select throws_ok(
  $$ update public.products set status = 'active' where id = (select id from ids where name = 'p1') $$,
  '42501', null, 'A seller cannot publish their own product'
);
select throws_ok(
  $$ insert into public.products (shop_id, category_id, title, status)
     values ((select id from ids where name = 'shop_a'), '20000000-0000-0000-0000-0000000000c1', 'Sneaky', 'active') $$,
  '42501', null, 'A seller cannot insert a live product'
);
select throws_ok(
  $$ update public.moderation_reviews set ai_decision = 'approve' $$,
  '42501', null, 'A seller cannot change a review'
);

-- Submitting.
select throws_ok(
  $$ select public.claim_moderation_jobs() $$,
  '42501', null, 'A seller cannot claim review jobs'
);
select throws_ok(
  $$ select public.apply_moderation_result(gen_random_uuid(), 'x', 'p', 'm', 'v', 'approve', 'none', 'ok') $$,
  '42501', null, 'A seller cannot apply an AI result'
);

insert into ids values ('no_photo', public.save_product(
  null, 'Without Photo', 'A very good lamp for your desk.',
  '20000000-0000-0000-0000-0000000000c1', 'new',
  '[{"options": {}, "price": 5, "stock": 1}]', '{}'
));
select throws_ok(
  $$ select public.submit_product_for_review((select id from ids where name = 'no_photo')) $$,
  'P0001', 'PHOTO_REQUIRED', 'A listing needs a photo before review'
);

select lives_ok(
  $$ select public.submit_product_for_review((select id from ids where name = 'p1')) $$,
  'A complete draft can be submitted'
);
select is(
  (select status::text from public.products where id = (select id from ids where name = 'p1')),
  'pending_review',
  'A submitted listing is in review'
);
select throws_ok(
  $$ select public.submit_product_for_review((select id from ids where name = 'p1')) $$,
  'P0001', 'PRODUCT_NOT_SUBMITTABLE', 'A listing cannot be submitted twice'
);

reset role;
select pg_temp.sign_in('00000000-0000-0000-0000-0000000000b2');
select throws_ok(
  $$ select public.submit_product_for_review((select id from ids where name = 'p1')) $$,
  'P0001', 'PRODUCT_NOT_FOUND', 'A seller cannot submit another seller''s listing'
);
select throws_ok(
  $$ select pg_temp.save((select id from ids where name = 'p1'), 'Stolen') $$,
  'P0001', 'INVALID_PHOTO', 'A seller cannot edit another seller''s listing with its photos'
);
select throws_ok(
  $$ select public.save_product((select id from ids where name = 'p1'), 'Stolen', '', '20000000-0000-0000-0000-0000000000c1', 'new',
       '[{"options": {}, "price": 1, "stock": 1}]', '{}') $$,
  'P0001', 'PRODUCT_NOT_FOUND', 'A seller cannot edit another seller''s listing'
);
select throws_ok(
  $$ select public.delete_product((select id from ids where name = 'p1')) $$,
  'P0001', 'PRODUCT_NOT_FOUND', 'A seller cannot delete another seller''s listing'
);

-- The AI worker.
reset role;
set local role service_role;

select is(
  (select title from public.claim_moderation_jobs(20) where title = 'Good Lamp'),
  'Good Lamp',
  'The worker receives the listing'
);
select is(
  (select count(*)::int from public.claim_moderation_jobs(20)),
  0,
  'A claimed job is not handed out twice'
);

create function pg_temp.review(p_name text)
returns public.moderation_reviews
language sql
as $$
  select r.* from public.moderation_reviews r
  where r.product_id = (select id from ids where name = p_name)
  order by r.created_at desc, r.attempts desc
  limit 1;
$$;
grant execute on function pg_temp.review(text) to service_role, authenticated;

select is(
  public.apply_moderation_result((pg_temp.review('p1')).id, 'wrong-hash', 'fake', 'm', 'v1', 'approve', 'none', 'Looks fine'),
  'discarded',
  'A result for different content is thrown away'
);

-- A failure keeps the product in review, and delays the next try.
select lives_ok(
  format($$ select public.record_moderation_failure(%L, 'quota') $$, (pg_temp.review('p1')).id),
  'A failed attempt is recorded'
);
select ok((pg_temp.review('p1')).next_attempt_at > now() + interval '4 minutes', 'A retry waits');
select is(
  (select status::text from public.products where id = (select id from ids where name = 'p1')),
  'pending_review',
  'An AI failure never publishes a product'
);

select is(
  public.apply_moderation_result(
    (pg_temp.review('p1')).id, (pg_temp.review('p1')).content_hash,
    'fake', 'm', 'v1', 'approve', 'none', 'Looks fine'
  ),
  'applied',
  'A valid approval is applied'
);
select is(
  (select status::text from public.products where id = (select id from ids where name = 'p1')),
  'active',
  'AI approval makes a listing live'
);

-- Price and stock changes stay live. Content changes return to review.
reset role;
select pg_temp.sign_in('00000000-0000-0000-0000-0000000000b1');
select lives_ok($$ select pg_temp.save((select id from ids where name = 'p1'), p_price => 450, p_stock => 9) $$, 'A seller can change price and stock');
select is(
  (select status::text from public.products where id = (select id from ids where name = 'p1')),
  'active',
  'A price or stock change keeps a listing live'
);
select is(
  (select min_price from public.products where id = (select id from ids where name = 'p1')),
  450.00::numeric(12,2),
  'The new price is shown'
);
select lives_ok($$ select pg_temp.save((select id from ids where name = 'p1'), p_title => 'Different Lamp') $$, 'A seller can change the title');
select is(
  (select status::text from public.products where id = (select id from ids where name = 'p1')),
  'pending_review',
  'A title change returns a listing to review'
);
select is(
  (select count(*)::int from public.search_products(p_shop_id => (select id from ids where name = 'shop_a'))),
  0,
  'A listing in review leaves the marketplace'
);

-- A result for the old content can't publish the new content.
reset role;
set local role service_role;
create temp table old_review as
  select r.id, r.content_hash from public.moderation_reviews r
  where r.product_id = (select id from ids where name = 'p1') and r.status = 'queued';
grant all on old_review to service_role, authenticated;

reset role;
select pg_temp.sign_in('00000000-0000-0000-0000-0000000000b1');
select lives_ok($$ select pg_temp.save((select id from ids where name = 'p1'), p_title => 'Changed During Review', p_paths => pg_temp.photos('two')) $$, 'A seller can edit during review');

reset role;
set local role service_role;
select is(
  public.apply_moderation_result((select id from old_review), (select content_hash from old_review), 'fake', 'm', 'v1', 'approve', 'none', 'Fine'),
  'discarded',
  'An old approval cannot publish changed content'
);

-- Suspicious goes to admins. The seller sees neither the status name nor reason.
select is(
  public.apply_moderation_result(
    (pg_temp.review('p1')).id, (pg_temp.review('p1')).content_hash,
    'fake', 'm', 'v1', 'suspicious', 'counterfeit', 'Might be a fake brand'
  ),
  'applied',
  'A suspicious result is applied'
);
select is(
  (select status::text from public.products where id = (select id from ids where name = 'p1')),
  'admin_review',
  'A suspicious listing goes to the admin queue'
);

reset role;
select pg_temp.sign_in('00000000-0000-0000-0000-0000000000b1');
select is(
  (select rejection_reason from public.get_my_listings() where id = (select id from ids where name = 'p1')),
  null,
  'A seller cannot read the AI''s reason'
);
select is(
  (select count(*)::int from public.moderation_reviews),
  0,
  'A seller cannot read reviews directly'
);
select throws_ok(
  $$ select public.admin_decide_product((select id from ids where name = 'p1'), 'approve') $$,
  'P0001', 'NOT_AN_ADMIN', 'A seller cannot approve their own listing'
);

-- Admin decisions.
reset role;
select pg_temp.sign_in('00000000-0000-0000-0000-0000000000b4');
select throws_ok(
  $$ select public.admin_decide_product((select id from ids where name = 'p1'), 'reject', '  ') $$,
  'P0001', 'REASON_REQUIRED', 'A rejection needs a reason'
);
select lives_ok(
  $$ select public.admin_decide_product((select id from ids where name = 'p1'), 'reject', 'The brand name looks fake.') $$,
  'An admin can reject'
);

reset role;
select pg_temp.sign_in('00000000-0000-0000-0000-0000000000b1');
select is(
  (select rejection_reason from public.get_my_listings(array['rejected']::public.product_status[]) where id = (select id from ids where name = 'p1')),
  'The brand name looks fake.',
  'A seller sees the admin''s rejection reason'
);
select lives_ok(
  $$ select public.submit_product_for_review((select id from ids where name = 'p1')) $$,
  'A rejected listing can be resubmitted'
);

-- 24 hours without an AI result sends it to a person, not to the marketplace.
reset role;
update public.moderation_reviews
set created_at = now() - interval '25 hours'
where product_id = (select id from ids where name = 'p1') and status = 'queued';
select public.run_moderation_sweep();
select is(
  (select status::text from public.products where id = (select id from ids where name = 'p1')),
  'admin_review',
  'After 24 hours without AI, a listing goes to the admin queue'
);

select pg_temp.sign_in('00000000-0000-0000-0000-0000000000b4');
select lives_ok(
  $$ select public.admin_decide_product((select id from ids where name = 'p1'), 'approve') $$,
  'An admin can approve'
);

-- Pausing and deleting.
reset role;
select pg_temp.sign_in('00000000-0000-0000-0000-0000000000b1');
select lives_ok($$ select public.set_product_paused((select id from ids where name = 'p1'), true) $$, 'A seller can pause');
select is(
  (select count(*)::int from public.search_products(p_shop_id => (select id from ids where name = 'shop_a'))),
  0,
  'A paused listing leaves the marketplace'
);
select lives_ok($$ select public.set_product_paused((select id from ids where name = 'p1'), false) $$, 'A seller can resume');
select throws_ok(
  $$ select public.set_product_paused((select id from ids where name = 'no_photo'), false) $$,
  'P0001', 'PRODUCT_NOT_PAUSABLE', 'A draft cannot be resumed into the marketplace'
);
select is(
  public.delete_product((select id from ids where name = 'p1')),
  pg_temp.photos('two'),
  'Deleting returns the photos to remove'
);
select is(
  (select count(*)::int from public.get_my_listings() where id = (select id from ids where name = 'p1')),
  0,
  'A deleted listing leaves My Posts'
);

-- One seller can't use up all of the free AI quota.
reset role;
update public.platform_settings set daily_submission_limit = 1 where country_code = 'BD';
select pg_temp.sign_in('00000000-0000-0000-0000-0000000000b2');
insert into ids values ('limit_1', public.save_product(
  null, 'Limit One', 'A very good lamp for your desk.', '20000000-0000-0000-0000-0000000000c1', 'new',
  '[{"options": {}, "price": 5, "stock": 1}]',
  array[(select id::text from ids where name = 'shop_b') || '/theirs.jpg']
));
insert into ids values ('limit_2', public.save_product(
  null, 'Limit Two', 'A very good lamp for your desk.', '20000000-0000-0000-0000-0000000000c1', 'new',
  '[{"options": {}, "price": 5, "stock": 1}]',
  array[(select id::text from ids where name = 'shop_b') || '/theirs.jpg']
));
select lives_ok(
  $$ select public.submit_product_for_review((select id from ids where name = 'limit_1')) $$,
  'A submission within the daily limit works'
);
select throws_ok(
  $$ select public.submit_product_for_review((select id from ids where name = 'limit_2')) $$,
  'P0001', 'SUBMISSION_LIMIT', 'The daily limit stops further submissions'
);

-- Deleting a seller's account still works with listings and reviews in place.
reset role;
delete from auth.users where id = '00000000-0000-0000-0000-0000000000b2';
select is(
  (select count(*)::int from public.shops where id = (select id from ids where name = 'shop_b')),
  0,
  'Deleting a seller removes their shop'
);

select * from finish();

rollback;
