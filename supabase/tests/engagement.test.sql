begin;

create extension if not exists pgtap with schema extensions;

select plan(75);

-- d1 and d2 buy. e1 and e2 sell. a1 is an admin.
insert into auth.users (id, email, raw_user_meta_data)
values
  ('00000000-0000-0000-0000-0000000002d1', 'eng-buyer@example.test', '{"full_name": "Rahima Khatun"}'),
  ('00000000-0000-0000-0000-0000000002d2', 'eng-buyer2@example.test', '{}'),
  ('00000000-0000-0000-0000-0000000002e1', 'eng-shop1@example.test', '{}'),
  ('00000000-0000-0000-0000-0000000002e2', 'eng-shop2@example.test', '{}'),
  ('00000000-0000-0000-0000-0000000002a1', 'eng-admin@example.test', '{}');

update auth.users
set phone = '88017500002' || right(id::text, 2), phone_confirmed_at = now()
where email like 'eng-%@example.test';

insert into public.admin_users (user_id) values ('00000000-0000-0000-0000-0000000002a1');

insert into public.seller_profiles (user_id)
values
  ('00000000-0000-0000-0000-0000000002e1'),
  ('00000000-0000-0000-0000-0000000002e2');

insert into public.shops (id, seller_id, name, slug, delivery_fee)
values
  ('32000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000002e1', 'Eng Alpha', 'eng-alpha', 60),
  ('32000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-0000000002e2', 'Eng Beta', 'eng-beta', 100);

insert into public.categories (id, name, slug)
values ('22000000-0000-0000-0000-0000000000d1', 'Eng test', 'eng-test');

insert into public.products (id, shop_id, category_id, title, description)
values
  ('42000000-0000-0000-0000-000000000001', '32000000-0000-0000-0000-000000000001', '22000000-0000-0000-0000-0000000000d1', 'Eng Lamp', 'A lamp used for testing.'),
  ('42000000-0000-0000-0000-000000000002', '32000000-0000-0000-0000-000000000002', '22000000-0000-0000-0000-0000000000d1', 'Eng Shirt', 'A shirt used for testing.');

insert into public.product_variants (id, product_id, price, stock)
values
  ('52000000-0000-0000-0000-000000000001', '42000000-0000-0000-0000-000000000001', 1000, 10),
  ('52000000-0000-0000-0000-000000000002', '42000000-0000-0000-0000-000000000002', 500, 10);

update public.products set status = 'active'
where id in ('42000000-0000-0000-0000-000000000001', '42000000-0000-0000-0000-000000000002');

insert into public.addresses (id, user_id, recipient_name, phone, region_id, line1)
values (
  '62000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-0000000002d1',
  'Eng Buyer',
  '+8801700000000',
  (select id from public.regions where level = 'district' and name = 'Dhaka' limit 1),
  'House 1'
);

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

create temp table ids (name text primary key, id uuid);
grant select, insert on ids to authenticated;
create function pg_temp.id(p_name text)
returns uuid
language sql
as $$ select id from ids where name = p_name $$;
grant execute on function pg_temp.id(text) to authenticated;

-- ---- Chat

set local role anon;
select throws_ok(
  $$ select public.start_conversation('42000000-0000-0000-0000-000000000001') $$,
  '42501', null, 'Guests cannot start a chat');
select throws_ok(
  $$ select * from public.messages $$, '42501', null, 'Guests cannot read messages');
reset role;

select pg_temp.sign_in('00000000-0000-0000-0000-0000000002e1');
select throws_ok(
  $$ select public.start_conversation('42000000-0000-0000-0000-000000000001') $$,
  'OWN_PRODUCT', 'Sellers cannot chat with themselves');
reset role;

select pg_temp.sign_in('00000000-0000-0000-0000-0000000002d1');
insert into ids
select 'chat', public.start_conversation('42000000-0000-0000-0000-000000000001');
select is(
  public.start_conversation('42000000-0000-0000-0000-000000000001'),
  pg_temp.id('chat'), 'Opening a chat twice gives the same chat');
select is(
  (select count(*)::integer from public.get_conversations()), 0, 'A chat with no messages is not listed');
select throws_ok(
  format($$ select public.send_message(%L, '   ') $$, pg_temp.id('chat')),
  'INVALID_MESSAGE', 'An empty message is refused');
select throws_ok(
  format($$ select public.send_message(%L, repeat('x', 2001)) $$, pg_temp.id('chat')),
  'INVALID_MESSAGE', 'A very long message is refused');
select throws_ok(
  $$ insert into public.messages (conversation_id, sender_id, body)
     values (gen_random_uuid(), auth.uid(), 'direct') $$,
  '42501', null, 'Messages cannot be written directly');

insert into ids
select 'msg1', (public.send_message(pg_temp.id('chat'), '  Is this still available?  ') ->> 'id')::uuid;
select is(
  (select body from public.messages where id = pg_temp.id('msg1')),
  'Is this still available?', 'A message is saved, trimmed');
select is(
  (select unread_count from public.get_conversations()), 0::bigint, 'Your own messages are not unread');
reset role;

-- The two people in the chat, and nobody else.
select pg_temp.sign_in('00000000-0000-0000-0000-0000000002e1');
select is((select count(*)::integer from public.messages), 1, 'The seller can read the message');
select is(
  (select unread_count from public.get_conversations()), 1::bigint, 'The seller sees it as unread');
select is(
  (select other_name from public.get_conversations()), 'Rahima', 'Sellers see only the buyer''s first name');
select is(
  (public.get_unread_counts() ->> 'chat')::integer, 1, 'The chat badge counts it');
select is(
  (select title from public.notifications where type = 'chat_message'),
  'Rahima', 'The seller is notified about the message');
select public.send_message(pg_temp.id('chat'), 'Yes, it is.');
reset role;

select pg_temp.sign_in('00000000-0000-0000-0000-0000000002e2');
select is((select count(*)::integer from public.messages), 0, 'Other sellers cannot read the chat');
select is(
  public.get_conversation(pg_temp.id('chat')), null, 'Other sellers cannot open the chat');
select throws_ok(
  format($$ select public.send_message(%L, 'hello') $$, pg_temp.id('chat')),
  'CONVERSATION_NOT_FOUND', 'Other sellers cannot write in the chat');
reset role;

select pg_temp.sign_in('00000000-0000-0000-0000-0000000002d2');
select is((select count(*)::integer from public.messages), 0, 'Other buyers cannot read the chat');
select throws_ok(
  format($$ select public.mark_conversation_read(%L) $$, pg_temp.id('chat')),
  'CONVERSATION_NOT_FOUND', 'Other buyers cannot change the chat');
reset role;

select pg_temp.sign_in('00000000-0000-0000-0000-0000000002a1');
select is((select count(*)::integer from public.messages), 0, 'Admins cannot browse private chats');
reset role;

-- A busy chat stays as one notification, which clears when the chat is read.
select pg_temp.sign_in('00000000-0000-0000-0000-0000000002d1');
select public.send_message(pg_temp.id('chat'), 'Great.');
select public.send_message(pg_temp.id('chat'), 'I will order it.');
reset role;
select is(
  (select count(*)::integer from public.notifications
   where user_id = '00000000-0000-0000-0000-0000000002e1' and type = 'chat_message' and read_at is null),
  1, 'Several messages make one unread notification');
select is(
  (select body from public.notifications
   where user_id = '00000000-0000-0000-0000-0000000002e1' and type = 'chat_message' and read_at is null),
  'I will order it.', 'It shows the newest message');

select pg_temp.sign_in('00000000-0000-0000-0000-0000000002e1');
select public.mark_conversation_read(pg_temp.id('chat'));
select is(
  (public.get_unread_counts() ->> 'chat')::integer, 0, 'Reading a chat clears its unread count');
select is(
  (select count(*)::integer from public.notifications where read_at is null and type = 'chat_message'),
  0, 'Reading a chat clears its notification');
reset role;

-- Rate limit: 30 messages a minute.
insert into public.messages (conversation_id, sender_id, body)
select pg_temp.id('chat'), '00000000-0000-0000-0000-0000000002d2', 'x' from generate_series(1, 30);
insert into public.conversations (buyer_id, shop_id, product_id)
values ('00000000-0000-0000-0000-0000000002d2', '32000000-0000-0000-0000-000000000002', '42000000-0000-0000-0000-000000000002');
select pg_temp.sign_in('00000000-0000-0000-0000-0000000002d2');
select throws_ok(
  $$ select public.send_message(
       (select id from public.conversations limit 1), 'one too many') $$,
  'MESSAGE_RATE_LIMIT', 'Too many messages in a minute are refused');
reset role;
delete from public.messages where sender_id = '00000000-0000-0000-0000-0000000002d2';

-- ---- Order notifications

select pg_temp.sign_in('00000000-0000-0000-0000-0000000002d1');
insert into ids
select 'order', (public.place_order(
  '62000000-0000-0000-0000-000000000001', 'eng-order-key-00000', 1060,
  '52000000-0000-0000-0000-000000000001'
) ->> 'order_id')::uuid;
reset role;
insert into ids
select 'group', id from public.seller_order_groups where order_id = pg_temp.id('order');
insert into ids
select 'item', id from public.order_items where group_id = pg_temp.id('group');

select is(
  (select count(*)::integer from public.notifications
   where user_id = '00000000-0000-0000-0000-0000000002e1' and type = 'new_order'),
  1, 'The seller is told about a new order');
select is(
  (select data ->> 'group_id' from public.notifications
   where user_id = '00000000-0000-0000-0000-0000000002e1' and type = 'new_order')::uuid,
  pg_temp.id('group'), 'The notification opens that order');

select pg_temp.sign_in('00000000-0000-0000-0000-0000000002e1');
select public.update_group_status(pg_temp.id('group'), 'packaging');
reset role;
select is(
  (select title from public.notifications
   where user_id = '00000000-0000-0000-0000-0000000002d1' and type = 'order_update'),
  'Your order is being packed', 'The buyer is told about each step');

select pg_temp.sign_in('00000000-0000-0000-0000-0000000002d2');
select is((select count(*)::integer from public.notifications where type = 'order_update'), 0,
  'Other users cannot read a notification');
select throws_ok(
  $$ update public.notifications set read_at = now() $$,
  '42501', null, 'Notifications cannot be changed directly');
reset role;

select pg_temp.sign_in('00000000-0000-0000-0000-0000000002d1');
select is((public.get_unread_counts() ->> 'notifications')::integer, 1, 'The bell counts it');
select public.mark_notifications_read();
select is((public.get_unread_counts() ->> 'notifications')::integer, 0, 'Marking read clears the bell');
reset role;

-- Whoever cancels isn't told about it; the other person is.
select pg_temp.sign_in('00000000-0000-0000-0000-0000000002d1');
insert into ids
select 'order2', (public.place_order(
  '62000000-0000-0000-0000-000000000001', 'eng-order-key-00002', 1060,
  '52000000-0000-0000-0000-000000000001'
) ->> 'order_id')::uuid;
reset role;
insert into ids
select 'group2', id from public.seller_order_groups where order_id = pg_temp.id('order2');
select pg_temp.sign_in('00000000-0000-0000-0000-0000000002d1');
select public.cancel_order_group(pg_temp.id('group2'));
reset role;
select is(
  (select count(*)::integer from public.notifications
   where user_id = '00000000-0000-0000-0000-0000000002e1' and type = 'order_cancelled'),
  1, 'When the buyer cancels, the seller is told');
select is(
  (select count(*)::integer from public.notifications
   where user_id = '00000000-0000-0000-0000-0000000002d1' and type = 'order_cancelled'),
  0, 'The buyer who cancelled is not told');

-- ---- Listing results

update public.products set status = 'pending_review' where id = '42000000-0000-0000-0000-000000000002';
update public.products set status = 'active' where id = '42000000-0000-0000-0000-000000000002';
select is(
  (select count(*)::integer from public.notifications
   where user_id = '00000000-0000-0000-0000-0000000002e2' and type = 'listing_live'),
  1, 'A seller is told when a listing goes live');
update public.products set status = 'paused' where id = '42000000-0000-0000-0000-000000000002';
update public.products set status = 'active' where id = '42000000-0000-0000-0000-000000000002';
select is(
  (select count(*)::integer from public.notifications
   where user_id = '00000000-0000-0000-0000-0000000002e2' and type = 'listing_live'),
  1, 'Resuming a paused listing is not news');
update public.products set status = 'admin_review' where id = '42000000-0000-0000-0000-000000000002';
select is(
  (select count(*)::integer from public.notifications
   where user_id = '00000000-0000-0000-0000-0000000002e2' and type = 'listing_rejected'),
  0, 'Going to the admin queue stays quiet');
update public.products set status = 'rejected' where id = '42000000-0000-0000-0000-000000000002';
select is(
  (select count(*)::integer from public.notifications
   where user_id = '00000000-0000-0000-0000-0000000002e2' and type = 'listing_rejected'),
  1, 'A seller is told when a listing is rejected');
update public.products set status = 'active' where id = '42000000-0000-0000-0000-000000000002';

-- ---- Reviews

select pg_temp.sign_in('00000000-0000-0000-0000-0000000002d1');
select throws_ok(
  format($$ select public.submit_review(%L, 5) $$, pg_temp.id('item')),
  'NOT_REVIEWABLE', 'An order must be complete before a review');
reset role;

select pg_temp.sign_in('00000000-0000-0000-0000-0000000002e1');
select public.update_group_status(pg_temp.id('group'), 'out_for_delivery');
select public.update_group_status(pg_temp.id('group'), 'completed');
reset role;

select pg_temp.sign_in('00000000-0000-0000-0000-0000000002d2');
select throws_ok(
  format($$ select public.submit_review(%L, 5) $$, pg_temp.id('item')),
  'NOT_REVIEWABLE', 'Only the buyer can review');
reset role;

select pg_temp.sign_in('00000000-0000-0000-0000-0000000002d1');
select throws_ok(
  format($$ select public.submit_review(%L, 6) $$, pg_temp.id('item')),
  'INVALID_RATING', 'A rating must be 1 to 5');
select throws_ok(
  $$ insert into public.reviews (order_item_id, product_id, rating) values (gen_random_uuid(), gen_random_uuid(), 5) $$,
  '42501', null, 'Reviews cannot be written directly');
insert into ids
select 'review', public.submit_review(pg_temp.id('item'), 4, ' Good lamp ');
select throws_ok(
  format($$ select public.submit_review(%L, 1) $$, pg_temp.id('item')),
  'ALREADY_REVIEWED', 'One review per item');
reset role;

select is(
  (select rating_avg from public.products where id = '42000000-0000-0000-0000-000000000001'),
  4.00::numeric(3, 2), 'A review updates the product rating');
select is(
  (select rating_count from public.shops where id = '32000000-0000-0000-0000-000000000001'),
  1, 'A review updates the shop rating');

set local role anon;
select is(
  (select comment from public.get_product_reviews('42000000-0000-0000-0000-000000000001')),
  'Good lamp', 'Anyone can read a review');
select is(
  (select reviewer_name from public.get_product_reviews('42000000-0000-0000-0000-000000000001')),
  'Rahima', 'Reviews show only a first name');
select throws_ok(
  $$ select buyer_id from public.reviews $$, '42501', null, 'A review cannot be traced to an account');
reset role;

update public.reviews set status = 'hidden' where id = pg_temp.id('review');
select is(
  (select rating_count from public.products where id = '42000000-0000-0000-0000-000000000001'),
  0, 'A hidden review stops counting');
select is(
  (select count(*)::integer from public.get_product_reviews('42000000-0000-0000-0000-000000000001')),
  0, 'A hidden review is not shown');
update public.reviews set status = 'visible' where id = pg_temp.id('review');

-- ---- Reports

set local role anon;
select throws_ok(
  $$ select public.submit_report('product', '42000000-0000-0000-0000-000000000001', 'fake') $$,
  '42501', null, 'Guests cannot report');
reset role;

select pg_temp.sign_in('00000000-0000-0000-0000-0000000002d2');
select lives_ok(
  $$ select public.submit_report('product', '42000000-0000-0000-0000-000000000001', 'fake', 'Looks wrong') $$,
  'A user can report a product');
select lives_ok(
  $$ select public.submit_report('product', '42000000-0000-0000-0000-000000000001', 'fake') $$,
  'Reporting twice is not an error');
select is((select count(*)::integer from public.reports), 1, 'Reporting twice saves one report');
select throws_ok(
  format($$ select public.submit_report('message', %L, 'spam') $$, pg_temp.id('msg1')),
  'REPORT_TARGET_NOT_FOUND', 'Only someone in a chat can report its messages');
select throws_ok(
  $$ update public.reports set status = 'dismissed' $$,
  '42501', null, 'Users cannot change a report');
reset role;

select pg_temp.sign_in('00000000-0000-0000-0000-0000000002e1');
select lives_ok(
  format($$ select public.submit_report('message', %L, 'offensive') $$, pg_temp.id('msg1')),
  'Someone in a chat can report a message');
select is((select count(*)::integer from public.reports), 1, 'Users read only their own reports');
reset role;

select pg_temp.sign_in('00000000-0000-0000-0000-0000000002a1');
select is(
  (select array_agg(id) from public.messages), array[pg_temp.id('msg1')],
  'Admins can read a message only once it is reported');
reset role;

-- ---- Statistics

create function pg_temp.track(p_type text, p_session text)
returns void
language sql
as $$
  select public.track_event(
    p_type::public.analytics_event_type,
    '42000000-0000-0000-0000-000000000001',
    p_session::uuid
  );
$$;
grant execute on function pg_temp.track(text, text) to anon, authenticated;

set local role anon;
select pg_temp.track('view', '72000000-0000-0000-0000-000000000001');
select pg_temp.track('view', '72000000-0000-0000-0000-000000000001');
select pg_temp.track('click', '72000000-0000-0000-0000-000000000001');
select pg_temp.track('view', '72000000-0000-0000-0000-000000000002');
select throws_ok(
  $$ select * from public.analytics_events $$, '42501', null, 'Events cannot be read directly');
reset role;
select is(
  (select count(*)::integer from public.analytics_events where event_type = 'view'
   and product_id = '42000000-0000-0000-0000-000000000001'),
  2, 'A quick repeat in one session counts once');

select pg_temp.sign_in('00000000-0000-0000-0000-0000000002e1');
select pg_temp.track('view', '72000000-0000-0000-0000-000000000003');
reset role;
select is(
  (select count(*)::integer from public.analytics_events where event_type = 'view'
   and product_id = '42000000-0000-0000-0000-000000000001'),
  2, 'A seller''s own views do not count');

-- Yesterday's events, as the nightly job finds them.
insert into public.analytics_events (event_type, product_id, shop_id, session_id, created_at)
select 'view', '42000000-0000-0000-0000-000000000001', '32000000-0000-0000-0000-000000000001',
  gen_random_uuid(), now() - interval '1 day'
from generate_series(1, 3);
select public.roll_up_analytics();
select public.roll_up_analytics();
select is(
  (select sum(views)::integer from public.product_daily_stats
   where product_id = '42000000-0000-0000-0000-000000000001'),
  3, 'Running the nightly job twice does not double count');

select pg_temp.sign_in('00000000-0000-0000-0000-0000000002e1');
select is((public.get_seller_stats(7) ->> 'views')::integer, 5, 'Stats add up past days and today');
select is((public.get_seller_stats(7) ->> 'clicks')::integer, 1, 'Stats count clicks');
select is((public.get_seller_stats(7) ->> 'sales')::numeric, 1000::numeric, 'Sales exclude delivery');
select is((public.get_seller_stats(7) ->> 'orders')::integer, 1, 'Cancelled orders are not counted');
select is(jsonb_array_length(public.get_seller_stats(7) -> 'daily'), 7, 'Every day appears, even quiet ones');
select is(
  public.get_seller_stats(7) -> 'top_products' -> 0 ->> 'title', 'Eng Lamp', 'Top products are listed');
select is((public.get_seller_dashboard() ->> 'views_today')::integer, 2, 'The dashboard shows today');
select is((public.get_seller_dashboard() ->> 'sales_today')::numeric, 1000::numeric, 'The dashboard shows sales');
select is((public.get_seller_dashboard() ->> 'amount_owed')::numeric, 10::numeric, 'The dashboard shows what is owed');
reset role;

select pg_temp.sign_in('00000000-0000-0000-0000-0000000002d2');
select is(public.get_seller_stats(7), null, 'Someone with no shop has no stats');
select is(public.get_seller_dashboard(), null, 'Someone with no shop has no dashboard card');
reset role;

select * from finish();

rollback;
