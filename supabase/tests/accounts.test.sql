begin;

create extension if not exists pgtap with schema extensions;

select plan(22);

insert into auth.users (id, email, raw_user_meta_data)
values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.test', '{"full_name": "User A"}'),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.test', '{"name": "User B"}');

-- Signup creates a profile.
select is(
  (select full_name from public.profiles where id = '00000000-0000-0000-0000-00000000000a'),
  'User A',
  'Signup creates a profile with the name'
);

select is(
  (select full_name from public.profiles where id = '00000000-0000-0000-0000-00000000000b'),
  'User B',
  'Signup also reads the name given by Google'
);

-- Only a confirmed phone reaches the profile.
update auth.users
set phone = '8801711111111', phone_confirmed_at = null
where id = '00000000-0000-0000-0000-00000000000a';

select is(
  (select phone from public.profiles where id = '00000000-0000-0000-0000-00000000000a'),
  null,
  'An unconfirmed phone is not copied'
);

update auth.users
set phone_confirmed_at = now()
where id = '00000000-0000-0000-0000-00000000000a';

select is(
  (select phone from public.profiles where id = '00000000-0000-0000-0000-00000000000a'),
  '+8801711111111',
  'A confirmed phone is copied with its plus'
);

select isnt(
  (select phone_verified_at from public.profiles where id = '00000000-0000-0000-0000-00000000000a'),
  null,
  'A confirmed phone marks the profile as verified'
);

-- Act as User A.
set local role authenticated;
set local request.jwt.claims = '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

select is(
  (select count(*)::int from public.profiles),
  1,
  'Users can see only their own profile'
);

update public.profiles
set full_name = 'Renamed'
where id = '00000000-0000-0000-0000-00000000000a';

select is(
  (select full_name from public.profiles),
  'Renamed',
  'Users can change their own name'
);

select throws_ok(
  $$ update public.profiles set phone_verified_at = now() $$,
  '42501',
  null,
  'Users cannot mark their own phone as verified'
);

select throws_ok(
  $$ update public.profiles set status = 'active' $$,
  '42501',
  null,
  'Users cannot change their own status'
);

update public.profiles
set full_name = 'Hacked'
where id = '00000000-0000-0000-0000-00000000000b';

-- Addresses.
create temporary table test_district on commit drop as
  select id from public.regions where level = 'district' limit 1;
create temporary table test_division on commit drop as
  select id from public.regions where level = 'division' limit 1;
grant select on test_district, test_division to authenticated;

insert into public.addresses (recipient_name, phone, region_id, line1)
select 'First', '+8801711111111', id, 'House 1' from test_district;

select is(
  (select is_default from public.addresses where recipient_name = 'First'),
  true,
  'The first address becomes the default'
);

insert into public.addresses (recipient_name, phone, region_id, line1)
select 'Second', '+8801711111111', id, 'House 2' from test_district;

select is(
  (select is_default from public.addresses where recipient_name = 'Second'),
  false,
  'Later addresses are not the default'
);

select public.set_default_address(
  (select id from public.addresses where recipient_name = 'Second')
);

select is(
  (select recipient_name from public.addresses where is_default),
  'Second',
  'Users can change their default address'
);

delete from public.addresses where recipient_name = 'Second';

select is(
  (select recipient_name from public.addresses where is_default),
  'First',
  'Deleting the default promotes another address'
);

select throws_ok(
  $$ insert into public.addresses (recipient_name, phone, region_id, line1)
     select 'Bad', '01711111111', id, 'House' from test_district $$,
  '23514',
  null,
  'Phones must use the +880 format'
);

select throws_ok(
  $$ insert into public.addresses (recipient_name, phone, region_id, line1)
     select 'Bad', '+8801711111111', id, 'House' from test_division $$,
  '23514',
  null,
  'A whole division is not a valid address'
);

select throws_ok(
  $$ update public.addresses set is_default = false $$,
  '42501',
  null,
  'Users cannot set the default directly'
);

select throws_ok(
  $$ insert into public.addresses (user_id, recipient_name, phone, region_id, line1)
     select '00000000-0000-0000-0000-00000000000b', 'Bad', '+8801711111111', id, 'House' from test_district $$,
  '42501',
  null,
  'Users cannot add an address for someone else'
);

-- Act as User B.
set local request.jwt.claims = '{"sub": "00000000-0000-0000-0000-00000000000b", "role": "authenticated"}';

select is(
  (select count(*)::int from public.addresses),
  0,
  'Users cannot see another user''s addresses'
);

select throws_ok(
  $$ select public.set_default_address((select id from pg_temp.test_district)) $$,
  'P0001',
  'ADDRESS_NOT_FOUND',
  'Users cannot set a default on an address that is not theirs'
);

delete from public.addresses;

reset role;

select is(
  (select count(*)::int from public.addresses),
  1,
  'Users cannot delete another user''s addresses'
);

select is(
  (select full_name from public.profiles where id = '00000000-0000-0000-0000-00000000000b'),
  'User B',
  'Users cannot change another user''s name'
);

-- Deleting an account removes its private data.
delete from auth.users where id = '00000000-0000-0000-0000-00000000000a';

select is(
  (select count(*)::int from public.addresses),
  0,
  'Deleting an account removes its addresses'
);

select * from finish();

rollback;
