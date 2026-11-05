#!/usr/bin/env bash
# Checks place_order when requests really do run at the same time, which a single
# pgTAP transaction cannot do. Needs the local database (supabase db start).
#
#   bash supabase/scripts/place_order_race.sh
set -uo pipefail

CONTAINER="${DB_CONTAINER:-supabase_db_browsly}"
PREFIX="70000000-0000-0000-0000"
failures=0

sql() {
  docker exec -i "$CONTAINER" psql -U postgres -v ON_ERROR_STOP=1 -qtA "$@"
}

# Places one order as one buyer. Prints the order number, or the refusal.
place_order() {
  local buyer="$1" address="$2" key="$3" variant="$4" total="$5"
  sql 2>&1 <<SQL | grep -oE 'BR-[0-9]+|OUT_OF_STOCK|deadlock detected' | head -1
begin;
select set_config('role', 'authenticated', true);
select set_config('request.jwt.claims', '{"sub": "$buyer", "role": "authenticated"}', true);
select public.place_order('$address', '$key', $total, '$variant');
commit;
SQL
}

check() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "ok - $label"
  else
    echo "FAILED - $label (expected $expected, got $actual)"
    failures=$((failures + 1))
  fi
}

cleanup() {
  sql >/dev/null <<SQL
delete from public.orders where buyer_id in (select id from public.profiles where id::text like '$PREFIX-%');
delete from auth.users where id::text like '$PREFIX-%';
delete from public.categories where slug = 'race-test';
SQL
}
trap cleanup EXIT
cleanup

# One seller, one product with 1 in stock, and 12 buyers with verified phones.
sql >/dev/null <<SQL
insert into auth.users (id, email, phone, phone_confirmed_at)
select
  ('$PREFIX-' || lpad(n::text, 12, '0'))::uuid,
  'race' || n || '@example.test',
  '88017300' || lpad(n::text, 5, '0'),
  now()
from generate_series(0, 12) as n;

insert into public.seller_profiles (user_id) values ('$PREFIX-000000000000');
insert into public.shops (id, seller_id, name, slug, delivery_fee)
values ('$PREFIX-0000000000a0', '$PREFIX-000000000000', 'Race Shop', 'race-shop', 0);
insert into public.categories (id, name, slug)
values ('$PREFIX-0000000000b0', 'Race test', 'race-test');
insert into public.products (id, shop_id, category_id, title)
values ('$PREFIX-0000000000c0', '$PREFIX-0000000000a0', '$PREFIX-0000000000b0', 'Race Product');
insert into public.product_variants (id, product_id, price, stock)
values ('$PREFIX-0000000000d0', '$PREFIX-0000000000c0', 100, 1);
update public.products set status = 'active' where id = '$PREFIX-0000000000c0';

insert into public.addresses (id, user_id, recipient_name, phone, region_id, line1)
select
  ('$PREFIX-' || lpad((1000 + n)::text, 12, '0'))::uuid,
  ('$PREFIX-' || lpad(n::text, 12, '0'))::uuid,
  'Race Buyer',
  '+8801700000000',
  (select id from public.regions where level = 'district' limit 1),
  'House 1'
from generate_series(1, 12) as n;
SQL

buyer() { printf '%s-%012d' "$PREFIX" "$1"; }
address() { printf '%s-%012d' "$PREFIX" "$((1000 + $1))"; }
VARIANT="$PREFIX-0000000000d0"
results="$(mktemp)"

# 1. Two buyers race for the last item.
for n in 1 2; do
  place_order "$(buyer "$n")" "$(address "$n")" "race-key-buyer-$n-00" "$VARIANT" 100 >>"$results" &
done
wait
check "last item: one buyer succeeds" 1 "$(grep -c '^BR-' "$results")"
check "last item: the other gets OUT_OF_STOCK" 1 "$(grep -c '^OUT_OF_STOCK$' "$results")"
check "last item: stock is never negative" 0 "$(sql -c "select stock from public.product_variants where id = '$VARIANT'")"

# 2. A double tap sends the same request twice at once.
sql -c "update public.product_variants set stock = 5 where id = '$VARIANT'" >/dev/null
: >"$results"
for _ in 1 2; do
  place_order "$(buyer 3)" "$(address 3)" "double-tap-key-0000" "$VARIANT" 100 >>"$results" &
done
wait
check "double tap: both get the same order" 1 "$(sort -u "$results" | grep -c '^BR-')"
check "double tap: one order exists" 1 "$(sql -c "select count(*) from public.orders where buyer_id = '$(buyer 3)'")"
check "double tap: one item taken" 4 "$(sql -c "select stock from public.product_variants where id = '$VARIANT'")"

# 3. A rush: 8 buyers for 4 items, with no deadlocks.
: >"$results"
for n in 4 5 6 7 8 9 10 11; do
  place_order "$(buyer "$n")" "$(address "$n")" "rush-key-buyer-$n-000" "$VARIANT" 100 >>"$results" &
done
wait
check "rush: exactly 4 orders succeed" 4 "$(grep -c '^BR-' "$results")"
check "rush: the others get OUT_OF_STOCK" 4 "$(grep -c '^OUT_OF_STOCK$' "$results")"
check "rush: no deadlocks" 0 "$(grep -c 'deadlock' "$results")"
check "rush: stock ends at zero" 0 "$(sql -c "select stock from public.product_variants where id = '$VARIANT'")"

rm -f "$results"
if [ "$failures" -gt 0 ]; then
  echo "$failures check(s) failed"
  exit 1
fi
echo "All race checks passed"
