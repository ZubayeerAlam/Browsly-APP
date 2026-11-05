begin;

create extension if not exists pgtap with schema extensions;

select plan(56);

-- d1 buys. e1 and e2 are sellers. a1 is an admin.
insert into auth.users (id, email)
values
  ('00000000-0000-0000-0000-0000000001d1', 'sales-buyer@example.test'),
  ('00000000-0000-0000-0000-0000000001e1', 'sales-shop1@example.test'),
  ('00000000-0000-0000-0000-0000000001e2', 'sales-shop2@example.test'),
  ('00000000-0000-0000-0000-0000000001a1', 'sales-admin@example.test');

update auth.users
set phone = '88017400001' || right(id::text, 2), phone_confirmed_at = now()
where email like 'sales-%@example.test';

insert into public.admin_users (user_id) values ('00000000-0000-0000-0000-0000000001a1');

insert into public.seller_profiles (user_id)
values
  ('00000000-0000-0000-0000-0000000001e1'),
  ('00000000-0000-0000-0000-0000000001e2');

insert into public.shops (id, seller_id, name, slug, delivery_fee)
values
  ('31000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000001e1', 'Sales Alpha', 'sales-alpha', 60),
  ('31000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-0000000001e2', 'Sales Beta', 'sales-beta', 100);

insert into public.categories (id, name, slug)
values ('21000000-0000-0000-0000-0000000000d1', 'Sales test', 'sales-test');

insert into public.products (id, shop_id, category_id, title, description)
values
  ('41000000-0000-0000-0000-000000000001', '31000000-0000-0000-0000-000000000001', '21000000-0000-0000-0000-0000000000d1', 'Sales Lamp', 'A lamp used for testing.'),
  ('41000000-0000-0000-0000-000000000002', '31000000-0000-0000-0000-000000000002', '21000000-0000-0000-0000-0000000000d1', 'Sales Shirt', 'A shirt used for testing.');

insert into public.product_variants (id, product_id, price, stock)
values
  ('51000000-0000-0000-0000-000000000001', '41000000-0000-0000-0000-000000000001', 1000, 10),
  ('51000000-0000-0000-0000-000000000002', '41000000-0000-0000-0000-000000000002', 500, 10);

update public.products set status = 'active'
where id in ('41000000-0000-0000-0000-000000000001', '41000000-0000-0000-0000-000000000002');

insert into public.addresses (id, user_id, recipient_name, phone, region_id, line1)
values (
  '61000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-0000000001d1',
  'Sales Buyer',
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

-- Buys one of a variant and returns its group, as a buyer would.
create function pg_temp.buy(p_key text, p_variant uuid, p_total numeric)
returns uuid
language plpgsql
as $$
declare
  v_order uuid;
begin
  perform pg_temp.sign_in('00000000-0000-0000-0000-0000000001d1');
  v_order := (public.place_order(
    '61000000-0000-0000-0000-000000000001', p_key, p_total, p_variant
  ) ->> 'order_id')::uuid;
  reset role;
  return (select id from public.seller_order_groups where order_id = v_order);
end;
$$;

create temp table groups (name text primary key, id uuid);
grant select on groups to authenticated;

insert into groups values
  ('main', pg_temp.buy('sales-main-key-0000', '51000000-0000-0000-0000-000000000001', 1060)),
  ('fail', pg_temp.buy('sales-fail-key-0000', '51000000-0000-0000-0000-000000000001', 1060)),
  ('cancel', pg_temp.buy('sales-cancel-key-00', '51000000-0000-0000-0000-000000000001', 1060)),
  ('beta', pg_temp.buy('sales-beta-key-0000', '51000000-0000-0000-0000-000000000002', 600));
reset role;

create function pg_temp.g(p_name text)
returns uuid
language sql
as $$ select id from groups where name = p_name $$;
grant execute on function pg_temp.g(text) to authenticated;

create function pg_temp.status_call(p_name text, p_status text)
returns text
language sql
as $$ select format('select public.update_group_status(%L, %L)', pg_temp.g(p_name), p_status) $$;
grant execute on function pg_temp.status_call(text, text) to authenticated;

select is(
  (select stock from public.product_variants where id = '51000000-0000-0000-0000-000000000001'),
  7, 'Three orders took three items');

-- Who may change what.
select pg_temp.sign_in('00000000-0000-0000-0000-0000000001d1');
select throws_ok(
  pg_temp.status_call('main', 'packaging'), 'NOT_A_SELLER', 'Buyers cannot move an order along');
reset role;

select pg_temp.sign_in('00000000-0000-0000-0000-0000000001e2');
select throws_ok(
  pg_temp.status_call('main', 'packaging'), 'ORDER_NOT_FOUND', 'Other sellers cannot move an order along');
select is(
  public.get_shop_order(pg_temp.g('main')), null, 'Other sellers cannot read an order');
select is(
  (select count(*)::integer from public.get_shop_orders(array['pending']::public.order_group_status[])),
  1, 'Sellers list only their own orders');
reset role;

set local role anon;
select throws_ok(
  $$ select public.get_shop_orders(array['pending']::public.order_group_status[]) $$,
  '42501', null, 'Guests cannot list orders');
reset role;

select pg_temp.sign_in('00000000-0000-0000-0000-0000000001e1');
select throws_ok(
  $$ update public.seller_order_groups set status = 'completed' $$,
  '42501', null, 'Sellers cannot change a status directly');
select throws_ok(
  $$ insert into public.commission_ledger (seller_id, type, amount, note)
     values ('00000000-0000-0000-0000-0000000001e1', 'adjustment', -100, 'free money') $$,
  '42501', null, 'Sellers cannot write to the ledger');
select throws_ok(
  $$ delete from public.commission_ledger $$,
  '42501', null, 'Sellers cannot delete from the ledger');
select throws_ok(
  $$ select public.seller_commission_balance('00000000-0000-0000-0000-0000000001e2') $$,
  '42501', null, 'Sellers cannot ask about another seller''s balance');

-- What a seller can see of an order.
select is(
  (select count(*)::integer from public.get_shop_orders(array['pending']::public.order_group_status[])),
  3, 'Sellers list each of their orders');
select is(
  public.get_shop_order(pg_temp.g('main')) -> 'shipping_address' ->> 'phone',
  '+8801700000000', 'Sellers can see how to reach the buyer');
select is(
  (public.get_shop_order(pg_temp.g('main')) ->> 'commission_total')::numeric,
  10::numeric, 'Sellers can see the commission on an order');

-- Only valid steps.
select throws_ok(
  pg_temp.status_call('main', 'completed'), 'INVALID_STATUS_CHANGE', 'Pending cannot skip to Complete');
select throws_ok(
  pg_temp.status_call('main', 'out_for_delivery'), 'INVALID_STATUS_CHANGE', 'Pending cannot skip Packaging');
select throws_ok(
  pg_temp.status_call('main', 'delivery_failed'), 'INVALID_STATUS_CHANGE', 'Pending cannot fail delivery');
select throws_ok(
  pg_temp.status_call('main', 'cancelled'), 'INVALID_STATUS_CHANGE', 'Cancelling has its own function');

select lives_ok(pg_temp.status_call('main', 'packaging'), 'Pending moves to Packaging');
select lives_ok(pg_temp.status_call('main', 'packaging'), 'Sending the same step again does nothing');
select throws_ok(
  pg_temp.status_call('main', 'pending'), 'INVALID_STATUS_CHANGE', 'An order cannot go backwards');
select throws_ok(
  pg_temp.status_call('main', 'completed'), 'INVALID_STATUS_CHANGE', 'Packaging cannot skip to Complete');
select lives_ok(pg_temp.status_call('main', 'out_for_delivery'), 'Packaging moves to Out for delivery');
select is(
  public.get_commission_summary() ->> 'balance', '0', 'Nothing is charged before Complete');

select throws_ok(
  format($$ select public.cancel_order_group(%L) $$, pg_temp.g('main')),
  'ORDER_NOT_CANCELLABLE', 'An order out for delivery cannot be cancelled');

-- Complete.
select lives_ok(pg_temp.status_call('main', 'completed'), 'Out for delivery moves to Complete');
select is(
  (public.get_commission_summary() ->> 'balance')::numeric,
  10::numeric, 'A ৳1,000 item charges exactly ৳10, with delivery excluded');
select lives_ok(pg_temp.status_call('main', 'completed'), 'Completing again does nothing');
select is(
  (public.get_commission_summary() ->> 'balance')::numeric, 10::numeric, 'An order is never charged twice');
select is(
  (select count(*)::integer from public.commission_ledger), 1, 'Sellers can read their own ledger entry');
select throws_ok(
  pg_temp.status_call('main', 'delivery_failed'), 'INVALID_STATUS_CHANGE', 'Complete is final');
select is(
  (select array_agg(to_status::text order by created_at) from public.order_status_history
   where group_id = pg_temp.g('main')),
  array['pending', 'packaging', 'out_for_delivery', 'completed'],
  'Every step is recorded once');
reset role;

select is(
  (select status::text from public.payments where group_id = pg_temp.g('main')),
  'collected', 'Complete records the cash as collected');
select isnt(
  (select collected_at from public.payments where group_id = pg_temp.g('main')),
  null, 'Complete records when the cash was collected');
select is(
  (select sold_count from public.products where id = '41000000-0000-0000-0000-000000000001'),
  1, 'Complete adds to the sold count');
select is(
  (select stock from public.product_variants where id = '51000000-0000-0000-0000-000000000001'),
  7, 'Complete does not change stock');

-- Failed delivery and cancelling charge nothing and return the stock.
select pg_temp.sign_in('00000000-0000-0000-0000-0000000001e1');
select lives_ok(pg_temp.status_call('fail', 'packaging'), 'Second order moves to Packaging');
select lives_ok(pg_temp.status_call('fail', 'out_for_delivery'), 'Second order goes out for delivery');
select lives_ok(pg_temp.status_call('fail', 'delivery_failed'), 'A delivery can fail');
select lives_ok(
  format($$ select public.cancel_order_group(%L, 'Out of stock') $$, pg_temp.g('cancel')),
  'A seller can cancel a pending order');
select is(
  (public.get_commission_summary() ->> 'balance')::numeric,
  10::numeric, 'Cancelled and failed orders charge nothing');
reset role;

select is(
  (select stock from public.product_variants where id = '51000000-0000-0000-0000-000000000001'),
  9, 'Failed and cancelled orders return their stock');
select is(
  (select status::text from public.payments where group_id = pg_temp.g('fail')),
  'failed', 'A failed delivery records no cash');
select is(
  (select sold_count from public.products where id = '41000000-0000-0000-0000-000000000001'),
  1, 'Failed and cancelled orders do not count as sold');

-- A later rate change doesn't touch an order already placed.
update public.platform_settings set commission_rate = 5 where country_code = 'BD';
select pg_temp.sign_in('00000000-0000-0000-0000-0000000001e2');
select lives_ok(pg_temp.status_call('beta', 'packaging'), 'Rate test: packaging');
select lives_ok(pg_temp.status_call('beta', 'out_for_delivery'), 'Rate test: out for delivery');
select lives_ok(pg_temp.status_call('beta', 'completed'), 'Rate test: complete');
select is(
  (public.get_commission_summary() ->> 'balance')::numeric,
  5::numeric, 'Commission uses the rate from when the order was placed');
reset role;
update public.platform_settings set commission_rate = 1 where country_code = 'BD';

-- Settlements.
select pg_temp.sign_in('00000000-0000-0000-0000-0000000001e1');
select throws_ok(
  $$ select public.admin_record_settlement(
       '00000000-0000-0000-0000-0000000001e1', 10, 'bkash', 'FAKE') $$,
  'NOT_AN_ADMIN', 'Sellers cannot record their own payment');
reset role;

select pg_temp.sign_in('00000000-0000-0000-0000-0000000001a1');
select throws_ok(
  $$ select public.admin_record_settlement(
       '00000000-0000-0000-0000-0000000001e1', 11, 'bkash', 'TX1') $$,
  'SETTLEMENT_TOO_HIGH', 'A settlement cannot be more than what is owed');
select lives_ok(
  $$ select public.admin_record_settlement(
       '00000000-0000-0000-0000-0000000001e1', 4, 'bkash', 'TX1') $$,
  'An admin can record a payment');
reset role;

select pg_temp.sign_in('00000000-0000-0000-0000-0000000001e1');
select is(
  (public.get_commission_summary() ->> 'balance')::numeric, 6::numeric, 'A payment lowers the balance');
select is(
  (select array_agg(type::text || ':' || amount::text || ':' || coalesce(order_number like 'BR-%', false)::text || ':' || coalesce(reference, ''))
   from public.get_commission_entries()),
  array['settlement:-4.00:false:TX1', 'charge:10.00:true:'],
  'The history shows payments and charges, newest first');
reset role;

-- Over the limit.
update public.platform_settings set commission_block_limit = 6 where country_code = 'BD';
select pg_temp.sign_in('00000000-0000-0000-0000-0000000001e1');
select is(
  (public.get_commission_summary() ->> 'is_blocked')::boolean,
  false, 'Owing exactly the limit is still allowed');
reset role;

update public.platform_settings set commission_block_limit = 5 where country_code = 'BD';
select pg_temp.sign_in('00000000-0000-0000-0000-0000000001e1');
select is(
  (public.get_commission_summary() ->> 'is_blocked')::boolean, true, 'Owing over the limit blocks posting');
select throws_ok(
  $$ select public.save_product(
       null, 'New Listing', 'A new listing for testing.', '21000000-0000-0000-0000-0000000000d1',
       'new', '[{"options": {}, "price": 100, "stock": 1}]'::jsonb, '{}') $$,
  'COMMISSION_LIMIT', 'A seller over the limit cannot start a listing');
reset role;

-- Account deletion waits for commission to be paid. Commission stays on record.
update public.platform_settings set commission_block_limit = 5000 where country_code = 'BD';
select throws_ok(
  $$ delete from auth.users where id = '00000000-0000-0000-0000-0000000001e1' $$,
  'OWES_COMMISSION', 'A seller who owes commission cannot delete their account');

select * from finish();

rollback;
