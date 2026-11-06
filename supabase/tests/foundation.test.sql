begin;

create extension if not exists pgtap with schema extensions;

select plan(10);

select is(
  (select count(*)::int from public.regions where level = 'division'),
  8,
  'Bangladesh has 8 divisions'
);

select is(
  (select count(*)::int from public.regions where level = 'district'),
  64,
  'Bangladesh has 64 districts'
);

select is(
  (select commission_rate from public.platform_settings where country_code = 'BD'),
  1.00::numeric,
  'Commission is 1%'
);

-- Guests can read reference data but cannot change it.
set local role anon;

select is(
  (select count(*)::int from public.countries where code = 'BD'),
  1,
  'Guests can read countries'
);

select throws_ok(
  $$ insert into public.countries (code, name, currency_code) values ('XX', 'Test', 'XXX') $$,
  '42501',
  null,
  'Guests cannot add countries'
);

select throws_ok(
  $$ update public.platform_settings set commission_rate = 0 $$,
  '42501',
  null,
  'Guests cannot change settings'
);

-- A normal signed-in user is not an admin.
reset role;
insert into auth.users (id, email)
values ('00000000-0000-0000-0000-000000000001', 'user@example.test');
set local role authenticated;
set local request.jwt.claims = '{"sub": "00000000-0000-0000-0000-000000000001", "role": "authenticated"}';

select is(public.is_admin(), false, 'Normal users are not admins');

select throws_ok(
  $$ update public.platform_settings set commission_rate = 0 $$,
  '42501',
  null,
  'Normal users are refused when they change settings'
);

reset role;
select is(
  (select commission_rate from public.platform_settings where country_code = 'BD'),
  1.00::numeric,
  'Normal users cannot change the commission rate'
);

set local role authenticated;
select throws_ok(
  $$ insert into public.admin_users (user_id) values ('00000000-0000-0000-0000-000000000001') $$,
  '42501',
  null,
  'Users cannot make themselves admin'
);

select * from finish();

rollback;
