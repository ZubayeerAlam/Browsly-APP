begin;

create extension if not exists pgtap with schema extensions;

select plan(67);

-- b1 and b2 are buyers, s1 and s2 are sellers, u1 has no verified phone.
insert into auth.users (id, email)
values
  ('00000000-0000-0000-0000-0000000000d1', 'buyer@example.test'),
  ('00000000-0000-0000-0000-0000000000d2', 'buyer2@example.test'),
  ('00000000-0000-0000-0000-0000000000e1', 'shop1@example.test'),
  ('00000000-0000-0000-0000-0000000000e2', 'shop2@example.test'),
  ('00000000-0000-0000-0000-0000000000f1', 'unverified@example.test');

update auth.users
set phone = '88017200000' || right(id::text, 2), phone_confirmed_at = now()
where id <> '00000000-0000-0000-0000-0000000000f1'
  and email like '%@example.test';

insert into public.seller_profiles (user_id)
values
  ('00000000-0000-0000-0000-0000000000e1'),
  ('00000000-0000-0000-0000-0000000000e2');

insert into public.shops (id, seller_id, name, slug, delivery_fee)
values
  ('30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000e1', 'Alpha Shop', 'alpha-shop', 60),
  ('30000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-0000000000e2', 'Beta Shop', 'beta-shop', 100);

insert into public.categories (id, name, slug)
values ('20000000-0000-0000-0000-0000000000d1', 'Buying test', 'buying-test');

insert into public.products (id, shop_id, category_id, title)
values
  ('40000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-0000000000d1', 'Alpha Lamp'),
  ('40000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-0000000000d1', 'Beta Shirt'),
  ('40000000-0000-0000-0000-000000000003', '30000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-0000000000d1', 'Paused Chair');

insert into public.product_variants (id, product_id, options, price, stock)
values
  -- A ৳1,000 lamp, the example from the business rules.
  ('50000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000001', '{}', 1000, 3),
  ('50000000-0000-0000-0000-000000000021', '40000000-0000-0000-0000-000000000002', '{"size": "M"}', 250.50, 5),
  ('50000000-0000-0000-0000-000000000022', '40000000-0000-0000-0000-000000000002', '{"size": "L"}', 300, 0),
  ('50000000-0000-0000-0000-000000000031', '40000000-0000-0000-0000-000000000003', '{}', 700, 2);

update public.products
set status = 'active'
where id in (
  '40000000-0000-0000-0000-000000000001',
  '40000000-0000-0000-0000-000000000002'
);
update public.products set status = 'paused' where id = '40000000-0000-0000-0000-000000000003';

insert into public.addresses (id, user_id, recipient_name, phone, region_id, line1)
select
  ('60000000-0000-0000-0000-00000000000' || n)::uuid,
  u::uuid,
  'Test Person',
  '+8801700000000',
  (select id from public.regions where level = 'district' and name = 'Dhaka' limit 1),
  'House 1'
from (values
  (1, '00000000-0000-0000-0000-0000000000d1'),
  (2, '00000000-0000-0000-0000-0000000000d2'),
  (3, '00000000-0000-0000-0000-0000000000f1'),
  (4, '00000000-0000-0000-0000-0000000000e1')
) as t (n, u);

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

-- Guests.
set local role anon;
select throws_ok(
  $$ select public.get_cart() $$, '42501', null, 'Guests cannot read a cart');
select throws_ok(
  $$ select public.place_order('60000000-0000-0000-0000-000000000001', 'guest-key-0000000', 1) $$,
  '42501', null, 'Guests cannot place an order');
reset role;

-- Internal functions stay private.
select pg_temp.sign_in('00000000-0000-0000-0000-0000000000d1');
select throws_ok(
  $$ select public.checkout_lines('00000000-0000-0000-0000-0000000000d2', null) $$,
  '42501', null, 'Clients cannot read another buyer''s lines');
select throws_ok(
  $$ select public.cart_view('00000000-0000-0000-0000-0000000000d2', null) $$,
  '42501', null, 'Clients cannot read another buyer''s cart view');
select throws_ok(
  $$ select public.lock_variants(array['50000000-0000-0000-0000-000000000001'::uuid]) $$,
  '42501', null, 'Clients cannot take locks');
select throws_ok(
  $$ select public.account_has_open_orders('00000000-0000-0000-0000-0000000000d2') $$,
  '42501', null, 'Clients cannot ask about another user''s orders');

-- Clients have no direct writes.
select throws_ok(
  $$ insert into public.cart_items (user_id, variant_id, quantity)
     values ('00000000-0000-0000-0000-0000000000d1', '50000000-0000-0000-0000-000000000001', 1) $$,
  '42501', null, 'Clients cannot write to the cart directly');
select throws_ok(
  $$ insert into public.orders (buyer_id, country_code, currency_code, subtotal, delivery_total, grand_total, idempotency_key)
     values ('00000000-0000-0000-0000-0000000000d1', 'BD', 'BDT', 1, 0, 1, 'direct-key-000000') $$,
  '42501', null, 'Clients cannot create orders directly');

-- Cart.
select is(
  (public.get_cart() ->> 'item_count')::integer, 0, 'A new cart is empty');
select is(
  (public.get_cart() ->> 'can_checkout')::boolean, false, 'An empty cart cannot check out');

select is(
  (public.add_to_cart('50000000-0000-0000-0000-000000000001') ->> 'item_count')::integer,
  1, 'Adding returns the updated cart');
select is(
  (public.add_to_cart('50000000-0000-0000-0000-000000000001') ->> 'item_count')::integer,
  2, 'Adding again raises the quantity');
select is(
  (public.add_product_to_cart('40000000-0000-0000-0000-000000000001') ->> 'item_count')::integer,
  3, 'A product with one variant can be added from its card');
select throws_ok(
  $$ select public.add_to_cart('50000000-0000-0000-0000-000000000001') $$,
  'STOCK_LIMIT', 'A cart cannot hold more than the stock');
select throws_ok(
  $$ select public.set_cart_quantity('50000000-0000-0000-0000-000000000001', 4) $$,
  'STOCK_LIMIT', 'A quantity cannot be raised past the stock');
select throws_ok(
  $$ select public.add_product_to_cart('40000000-0000-0000-0000-000000000002') $$,
  'VARIANT_REQUIRED', 'A product with choices must be chosen on its page');
select throws_ok(
  $$ select public.add_to_cart('50000000-0000-0000-0000-000000000022') $$,
  'OUT_OF_STOCK', 'A sold-out variant cannot be added');
select throws_ok(
  $$ select public.add_to_cart('50000000-0000-0000-0000-000000000031') $$,
  'PRODUCT_UNAVAILABLE', 'A paused product cannot be added');
select throws_ok(
  $$ select public.set_cart_quantity('50000000-0000-0000-0000-000000000001', -1) $$,
  'INVALID_QUANTITY', 'A negative quantity is refused');

select is(
  (public.set_cart_quantity('50000000-0000-0000-0000-000000000001', 1) ->> 'item_count')::integer,
  1, 'A quantity can be lowered');

select public.add_to_cart('50000000-0000-0000-0000-000000000021');

-- Two shops: 1000 + 250.50 of items, and 60 + 100 of delivery.
select is(
  jsonb_array_length(public.get_cart() -> 'shops'), 2, 'The cart is grouped by shop');
select is(
  public.get_cart() -> 'shops' -> 0 ->> 'shop_name', 'Alpha Shop', 'Shops are in a steady order');
select is(
  (public.get_cart() ->> 'subtotal')::numeric, 1250.50::numeric, 'The cart adds up the items');
select is(
  (public.get_cart() ->> 'delivery_total')::numeric, 160::numeric, 'Each shop charges one delivery fee');
select is(
  (public.get_cart() ->> 'grand_total')::numeric, 1410.50::numeric, 'The cart adds up the total');

-- A shop's own products.
reset role;
select pg_temp.sign_in('00000000-0000-0000-0000-0000000000e1');
select throws_ok(
  $$ select public.add_to_cart('50000000-0000-0000-0000-000000000001') $$,
  'OWN_PRODUCT', 'Sellers cannot add their own products');
select throws_ok(
  $$ select public.place_order(
       '60000000-0000-0000-0000-000000000004', 'seller-own-key-000', 1060,
       '50000000-0000-0000-0000-000000000001') $$,
  'OWN_PRODUCT', 'Sellers cannot buy their own products');

-- Checks in place_order.
reset role;
select pg_temp.sign_in('00000000-0000-0000-0000-0000000000f1');
select throws_ok(
  $$ select public.place_order(
       '60000000-0000-0000-0000-000000000003', 'unverified-key-000', 1060,
       '50000000-0000-0000-0000-000000000001') $$,
  'PHONE_NOT_VERIFIED', 'Checkout needs a verified phone');

reset role;
select pg_temp.sign_in('00000000-0000-0000-0000-0000000000d1');
select throws_ok(
  $$ select public.place_order('60000000-0000-0000-0000-000000000002', 'other-address-key', 1410.50) $$,
  'ADDRESS_NOT_FOUND', 'Buyers cannot use someone else''s address');
select throws_ok(
  $$ select public.place_order('60000000-0000-0000-0000-000000000001', 'short', 1410.50) $$,
  'INVALID_REQUEST', 'A retry key is required');
select throws_ok(
  $$ select public.place_order('60000000-0000-0000-0000-000000000001', 'wrong-total-key-00', 1) $$,
  'PRICE_CHANGED', 'A total the app did not expect stops the order');

-- The seller raises a price after the buyer opened checkout. It changes nothing.
reset role;
update public.product_variants set price = 1100 where id = '50000000-0000-0000-0000-000000000001';
select pg_temp.sign_in('00000000-0000-0000-0000-0000000000d1');
select throws_ok(
  $$ select public.place_order('60000000-0000-0000-0000-000000000001', 'stale-price-key-0', 1410.50) $$,
  'PRICE_CHANGED', 'A changed price stops the order');
select is(
  (select stock from public.product_variants where id = '50000000-0000-0000-0000-000000000001'),
  3, 'A refused order leaves stock alone');
select is(
  (public.get_cart() ->> 'item_count')::integer, 2, 'A refused order leaves the cart alone');
reset role;
update public.product_variants set price = 1000 where id = '50000000-0000-0000-0000-000000000001';

-- Order value limit.
update public.platform_settings set max_cod_order_value = 100 where country_code = 'BD';
select pg_temp.sign_in('00000000-0000-0000-0000-0000000000d1');
select throws_ok(
  $$ select public.place_order('60000000-0000-0000-0000-000000000001', 'cod-limit-key-000', 1410.50) $$,
  'COD_LIMIT_EXCEEDED', 'The Cash on Delivery limit is enforced');
reset role;
update public.platform_settings set max_cod_order_value = 50000 where country_code = 'BD';

-- A multi-seller order.
select pg_temp.sign_in('00000000-0000-0000-0000-0000000000d1');
create temp table placed on commit drop as
  select public.place_order(
    '60000000-0000-0000-0000-000000000001', 'first-order-key-00', 1410.50
  ) as result;
grant select on placed to authenticated;

select ok(
  (select result ->> 'order_number' from placed) like 'BR-%', 'An order gets an order number');
select is(
  (select grand_total from public.orders where id = (select (result ->> 'order_id')::uuid from placed)),
  1410.50::numeric(12, 2), 'The order stores the server total');
select is(
  (select count(*)::integer from public.seller_order_groups
   where order_id = (select (result ->> 'order_id')::uuid from placed)),
  2, 'The order splits into one group per seller');
select is(
  (public.get_cart() ->> 'item_count')::integer, 0, 'Ordering empties the cart');
select is(
  (select result from placed),
  public.place_order('60000000-0000-0000-0000-000000000001', 'first-order-key-00', 1410.50),
  'Retrying with the same key returns the same order');
select is(
  (select count(*)::integer from public.orders), 1, 'A retry creates no second order');

reset role;
select is(
  (select stock from public.product_variants where id = '50000000-0000-0000-0000-000000000001'),
  2, 'Ordering takes the stock');
select is(
  (select total_stock from public.products where id = '40000000-0000-0000-0000-000000000001'),
  2, 'The product''s stock summary follows');
select is(
  (select commission_amount from public.order_items where product_title = 'Alpha Lamp'),
  10.00::numeric(12, 2), 'A ৳1,000 item has ৳10 commission');
select is(
  (select commission_total from public.seller_order_groups where shop_name = 'Alpha Shop'),
  10.00::numeric(12, 2), 'Commission excludes the delivery fee');
select is(
  (select commission_amount from public.order_items where product_title = 'Beta Shirt'),
  2.51::numeric(12, 2), 'Commission rounds to the paisa');
select is(
  (select amount from public.payments p
   join public.seller_order_groups g on g.id = p.group_id
   where g.shop_name = 'Alpha Shop'),
  1060.00::numeric(12, 2), 'The cash to collect includes delivery');

-- Later edits don't touch past orders.
update public.product_variants set price = 9999 where id = '50000000-0000-0000-0000-000000000001';
update public.products set title = 'Renamed Lamp' where id = '40000000-0000-0000-0000-000000000001';
select is(
  (select unit_price from public.order_items where variant_id = '50000000-0000-0000-0000-000000000001'),
  1000.00::numeric(12, 2), 'An order keeps the price it was placed at');
select is(
  (select product_title from public.order_items where variant_id = '50000000-0000-0000-0000-000000000001'),
  'Alpha Lamp', 'An order keeps the title it was placed with');
update public.product_variants set price = 1000 where id = '50000000-0000-0000-0000-000000000001';

-- Who can read what.
select pg_temp.sign_in('00000000-0000-0000-0000-0000000000d2');
select is((select count(*)::integer from public.orders), 0, 'Other buyers cannot read an order');
select is(
  (select count(*)::integer from public.seller_order_groups), 0, 'Other buyers cannot read its groups');
select is((select count(*)::integer from public.order_items), 0, 'Other buyers cannot read its items');
reset role;

select pg_temp.sign_in('00000000-0000-0000-0000-0000000000e1');
select is((select count(*)::integer from public.orders), 0, 'Sellers cannot read the whole order');
select is(
  (select array_agg(shop_name) from public.seller_order_groups),
  array['Alpha Shop'], 'Sellers see only their own group');
select is(
  (select array_agg(product_title) from public.order_items),
  array['Alpha Lamp'], 'Sellers see only their own items');
reset role;

select pg_temp.sign_in('00000000-0000-0000-0000-0000000000d1');
select throws_ok(
  $$ select commission_amount from public.order_items $$,
  '42501', null, 'Buyers cannot read commission');
select throws_ok(
  $$ update public.seller_order_groups set status = 'completed' $$,
  '42501', null, 'Clients cannot change a status directly');
select is(
  (select jsonb_array_length(groups) from public.get_my_orders()), 2, 'My Orders lists each seller');

-- Account deletion is blocked while orders are open.
reset role;
select throws_ok(
  $$ delete from auth.users where id = '00000000-0000-0000-0000-0000000000d1' $$,
  'OPEN_ORDERS', 'A buyer with open orders cannot delete their account');
select throws_ok(
  $$ delete from auth.users where id = '00000000-0000-0000-0000-0000000000e1' $$,
  'OPEN_ORDERS', 'A seller with open orders cannot delete their account');

-- Cancelling.
select pg_temp.sign_in('00000000-0000-0000-0000-0000000000d2');
select throws_ok(
  format(
    $$ select public.cancel_order_group(%L) $$,
    (select id from public.seller_order_groups where shop_name = 'Alpha Shop')
  ),
  'ORDER_NOT_FOUND', 'Other buyers cannot cancel an order');
reset role;

create temp table alpha on commit drop as
  select id from public.seller_order_groups where shop_name = 'Alpha Shop';
create temp table beta on commit drop as
  select id from public.seller_order_groups where shop_name = 'Beta Shop';
grant select on alpha, beta to authenticated;

select pg_temp.sign_in('00000000-0000-0000-0000-0000000000d1');
select public.cancel_order_group((select id from alpha), 'Changed my mind');
reset role;
select is(
  (select stock from public.product_variants where id = '50000000-0000-0000-0000-000000000001'),
  3, 'Cancelling returns the stock');
select is(
  (select status::text from public.seller_order_groups where id = (select id from alpha)),
  'cancelled', 'Cancelling changes only that seller''s part');

-- Finish the other part, then the order is closed for good.
update public.seller_order_groups set status = 'out_for_delivery' where id = (select id from beta);
select pg_temp.sign_in('00000000-0000-0000-0000-0000000000d1');
select throws_ok(
  format($$ select public.cancel_order_group(%L) $$, (select id from beta)),
  'ORDER_NOT_CANCELLABLE', 'An order out for delivery cannot be cancelled');
reset role;
update public.seller_order_groups set status = 'completed' where id = (select id from beta);

-- Deleting closed accounts keeps the records and removes the personal details.
delete from auth.users where id = '00000000-0000-0000-0000-0000000000d1';
select is(
  (select shipping_address ->> 'phone' from public.seller_order_groups where id = (select id from beta)),
  null, 'A deleted buyer''s phone is removed from past orders');

delete from auth.users where id = '00000000-0000-0000-0000-0000000000e2';
select is(
  (select shop_name from public.seller_order_groups where id = (select id from beta)),
  'Beta Shop', 'A deleted seller''s past orders keep the shop name');
select is(
  (select product_title from public.order_items where group_id = (select id from beta)),
  'Beta Shirt', 'A deleted seller''s past orders keep what was bought');

select * from finish();

rollback;
