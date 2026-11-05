-- Buying: cart, multi-seller Cash on Delivery orders and buyer cancellation.
--
-- Clients never write to these tables. Prices, stock and totals are always
-- worked out here, and order rows keep their own copy of what was bought, so
-- later edits, deleted listings and deleted accounts never change past orders.

create type public.order_group_status as enum (
  'pending', 'packaging', 'out_for_delivery', 'completed', 'cancelled', 'delivery_failed'
);
create type public.payment_method as enum ('cod');
create type public.payment_status as enum ('pending', 'collected', 'cancelled', 'failed');

-- Stores no price, so the cart always shows the current listing price.
create table public.cart_items (
  user_id uuid not null references public.profiles (id) on delete cascade,
  variant_id uuid not null references public.product_variants (id) on delete cascade,
  quantity integer not null check (quantity between 1 and 99),
  created_at timestamptz not null default clock_timestamp(),
  primary key (user_id, variant_id)
);

create index cart_items_variant_id_idx on public.cart_items (variant_id);

create sequence public.order_number_seq start with 100001;
revoke all on sequence public.order_number_seq from public, anon, authenticated;

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  order_number text not null unique
    default 'BR-' || nextval('public.order_number_seq'::regclass)::text,
  -- Becomes null when the buyer deletes their account. The order stays.
  buyer_id uuid references public.profiles (id) on delete set null,
  country_code char(2) not null references public.countries (code),
  currency_code char(3) not null,
  subtotal numeric(12, 2) not null check (subtotal >= 0),
  delivery_total numeric(12, 2) not null check (delivery_total >= 0),
  grand_total numeric(12, 2) not null,
  idempotency_key text not null check (length(idempotency_key) between 16 and 64),
  created_at timestamptz not null default now(),
  constraint orders_total_adds_up check (grand_total = subtotal + delivery_total),
  unique (buyer_id, idempotency_key)
);

create index orders_buyer_newest_idx on public.orders (buyer_id, created_at desc, id desc);
create index orders_country_code_idx on public.orders (country_code);

-- One order splits into one group per seller. Sellers read only their own group,
-- and never the order, so they can't see what else the buyer bought.
create table public.seller_order_groups (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders (id) on delete cascade,
  -- Becomes null when the seller deletes their account. shop_name stays.
  shop_id uuid references public.shops (id) on delete set null,
  shop_name text not null,
  status public.order_group_status not null default 'pending',
  subtotal numeric(12, 2) not null check (subtotal >= 0),
  delivery_fee numeric(12, 2) not null check (delivery_fee >= 0),
  commission_total numeric(12, 2) not null check (commission_total >= 0),
  shipping_address jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (order_id, shop_id)
);

create index seller_order_groups_shop_status_idx
  on public.seller_order_groups (shop_id, status, created_at desc);

create trigger seller_order_groups_set_updated_at
  before update on public.seller_order_groups
  for each row execute function public.set_updated_at();

-- Everything a buyer sees later is copied here when the order is placed.
create table public.order_items (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.seller_order_groups (id) on delete cascade,
  product_id uuid references public.products (id) on delete set null,
  variant_id uuid references public.product_variants (id) on delete set null,
  product_title text not null,
  variant_name text not null,
  image_path text,
  unit_price numeric(12, 2) not null check (unit_price > 0),
  quantity integer not null check (quantity > 0),
  line_total numeric(12, 2) not null,
  commission_rate numeric(5, 2) not null check (commission_rate between 0 and 100),
  commission_amount numeric(12, 2) not null check (commission_amount >= 0),
  created_at timestamptz not null default now(),
  constraint order_items_total_adds_up check (line_total = unit_price * quantity)
);

create index order_items_group_id_idx on public.order_items (group_id);
create index order_items_product_id_idx on public.order_items (product_id);
create index order_items_variant_id_idx on public.order_items (variant_id);

create table public.order_status_history (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.seller_order_groups (id) on delete cascade,
  from_status public.order_group_status,
  to_status public.order_group_status not null,
  changed_by uuid references public.profiles (id) on delete set null,
  note text check (length(note) <= 300),
  created_at timestamptz not null default clock_timestamp()
);

create index order_status_history_group_idx
  on public.order_status_history (group_id, created_at);
create index order_status_history_changed_by_idx
  on public.order_status_history (changed_by);

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null unique references public.seller_order_groups (id) on delete cascade,
  method public.payment_method not null default 'cod',
  amount numeric(12, 2) not null check (amount >= 0),
  status public.payment_status not null default 'pending',
  collected_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger payments_set_updated_at
  before update on public.payments
  for each row execute function public.set_updated_at();

-- Row Level Security. Commission columns are left out of the grants, so buyers
-- can't read them. Sellers get their own figures through a function in Step 5.
alter table public.cart_items enable row level security;
alter table public.orders enable row level security;
alter table public.seller_order_groups enable row level security;
alter table public.order_items enable row level security;
alter table public.order_status_history enable row level security;
alter table public.payments enable row level security;

revoke all on
  public.cart_items, public.orders, public.seller_order_groups, public.order_items,
  public.order_status_history, public.payments
from anon, authenticated;

grant select on public.cart_items to authenticated;
grant select (
  id, order_number, buyer_id, country_code, currency_code, subtotal, delivery_total,
  grand_total, created_at
) on public.orders to authenticated;
grant select (
  id, order_id, shop_id, shop_name, status, subtotal, delivery_fee, shipping_address,
  created_at, updated_at
) on public.seller_order_groups to authenticated;
grant select (
  id, group_id, product_id, variant_id, product_title, variant_name, image_path,
  unit_price, quantity, line_total, created_at
) on public.order_items to authenticated;
grant select on public.order_status_history to authenticated;
grant select on public.payments to authenticated;

create policy "Users can read their own cart"
  on public.cart_items for select to authenticated
  using (user_id = (select auth.uid()));

create policy "Buyers can read their own orders"
  on public.orders for select to authenticated
  using (buyer_id = (select auth.uid()));

create policy "Admins can read all orders"
  on public.orders for select to authenticated
  using ((select public.is_admin()));

-- The orders subquery obeys the policies above, so sellers get no rows from it.
create policy "Buyers can read the groups of their own orders"
  on public.seller_order_groups for select to authenticated
  using (exists (select 1 from public.orders o where o.id = order_id));

create policy "Sellers can read their own shop's groups"
  on public.seller_order_groups for select to authenticated
  using (shop_id = (select public.current_shop_id()));

create policy "Admins can read all groups"
  on public.seller_order_groups for select to authenticated
  using ((select public.is_admin()));

-- These subqueries obey the group policies, so they follow the group.
create policy "Anyone who can read a group can read its items"
  on public.order_items for select to authenticated
  using (exists (select 1 from public.seller_order_groups g where g.id = group_id));

create policy "Anyone who can read a group can read its history"
  on public.order_status_history for select to authenticated
  using (exists (select 1 from public.seller_order_groups g where g.id = group_id));

create policy "Anyone who can read a group can read its payment"
  on public.payments for select to authenticated
  using (exists (select 1 from public.seller_order_groups g where g.id = group_id));

-- One line of a cart or Buy Now, always with current prices and stock.
create type public.checkout_line as (
  variant_id uuid,
  product_id uuid,
  shop_id uuid,
  shop_name text,
  delivery_fee numeric,
  title text,
  variant_name text,
  image_path text,
  unit_price numeric,
  compare_at_price numeric,
  quantity integer,
  stock integer,
  country_code char(2),
  problem text,
  added_at timestamptz
);

-- Reads the buyer's cart, or just the Buy Now item when one is given. Internal:
-- it trusts its arguments, so clients cannot call it.
create function public.checkout_lines(p_buyer uuid, p_buy_now_variant uuid)
returns setof public.checkout_line
language sql
stable
set search_path = ''
as $$
  with wanted as (
    select c.variant_id, c.quantity, c.created_at as added_at
    from public.cart_items c
    where p_buy_now_variant is null and c.user_id = p_buyer
    union all
    select p_buy_now_variant, 1, now()
    where p_buy_now_variant is not null
  )
  select
    v.id,
    p.id,
    s.id,
    s.name,
    s.delivery_fee,
    p.title,
    v.name,
    (
      select i.storage_path from public.product_images i
      where i.product_id = p.id
      order by i.sort_order
      limit 1
    ),
    v.price,
    v.compare_at_price,
    w.quantity,
    v.stock,
    p.country_code,
    case
      when s.seller_id = p_buyer then 'OWN_PRODUCT'
      when p.status <> 'active' or p.deleted_at is not null
        or not s.is_active or not v.is_active then 'PRODUCT_UNAVAILABLE'
      when v.stock = 0 then 'OUT_OF_STOCK'
      when w.quantity > v.stock then 'LOW_STOCK'
    end,
    w.added_at
  from wanted w
  join public.product_variants v on v.id = w.variant_id
  join public.products p on p.id = v.product_id
  join public.shops s on s.id = p.shop_id;
$$;

revoke all on function public.checkout_lines(uuid, uuid) from public, anon, authenticated;

-- The cart as the app shows it, grouped by shop, with totals from the server.
-- Lines with a problem stay visible, but aren't counted in the totals.
create function public.cart_view(p_buyer uuid, p_buy_now_variant uuid)
returns jsonb
language sql
stable
set search_path = ''
as $$
  with lines as (
    select * from public.checkout_lines(p_buyer, p_buy_now_variant)
  ),
  shop_rows as (
    select
      l.shop_id,
      l.shop_name,
      l.delivery_fee,
      coalesce(sum(l.unit_price * l.quantity) filter (where l.problem is null), 0) as subtotal,
      bool_or(l.problem is null) as has_buyable,
      jsonb_agg(
        jsonb_build_object(
          'variant_id', l.variant_id,
          'product_id', l.product_id,
          'title', l.title,
          'variant_name', l.variant_name,
          'image_path', l.image_path,
          'unit_price', l.unit_price,
          'compare_at_price', l.compare_at_price,
          'quantity', l.quantity,
          'stock', l.stock,
          'problem', l.problem
        )
        order by l.added_at, l.variant_id
      ) as items
    from lines l
    group by l.shop_id, l.shop_name, l.delivery_fee
  ),
  totals as (
    select
      coalesce(sum(s.subtotal), 0) as subtotal,
      coalesce(sum(s.delivery_fee) filter (where s.has_buyable), 0) as delivery_total
    from shop_rows s
  )
  select jsonb_build_object(
    'shops', coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'shop_id', s.shop_id,
            'shop_name', s.shop_name,
            'delivery_fee', s.delivery_fee,
            'subtotal', s.subtotal,
            'items', s.items
          )
          order by s.shop_name, s.shop_id
        )
        from shop_rows s
      ),
      '[]'::jsonb
    ),
    'subtotal', t.subtotal,
    'delivery_total', t.delivery_total,
    'grand_total', t.subtotal + t.delivery_total,
    'item_count', (select coalesce(sum(l.quantity), 0) from lines l),
    'can_checkout', exists (select 1 from lines)
      and not exists (select 1 from lines l where l.problem is not null)
  )
  from totals t;
$$;

revoke all on function public.cart_view(uuid, uuid) from public, anon, authenticated;

-- The signed-in buyer, refused if suspended. Internal.
create function public.require_active_buyer()
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_buyer uuid := (select auth.uid());
begin
  if v_buyer is null then
    raise exception 'NOT_SIGNED_IN';
  end if;
  if not exists (
    select 1 from public.profiles where id = v_buyer and status = 'active'
  ) then
    raise exception 'ACCOUNT_SUSPENDED';
  end if;
  return v_buyer;
end;
$$;

revoke all on function public.require_active_buyer() from public, anon, authenticated;

create function public.get_cart()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  return public.cart_view(public.require_active_buyer(), null);
end;
$$;

revoke all on function public.get_cart() from public, anon;
grant execute on function public.get_cart() to authenticated;

-- The same shape as the cart, for checking out one item with Buy Now.
create function public.get_buy_now(p_variant_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if p_variant_id is null then
    raise exception 'PRODUCT_UNAVAILABLE';
  end if;
  return public.cart_view(public.require_active_buyer(), p_variant_id);
end;
$$;

revoke all on function public.get_buy_now(uuid) from public, anon;
grant execute on function public.get_buy_now(uuid) to authenticated;

-- Adds one. Returns the updated cart, so the app needs no second request.
create function public.add_to_cart(p_variant_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_buyer uuid := public.require_active_buyer();
  v_line public.checkout_line;
  v_current integer;
begin
  select * into v_line from public.checkout_lines(v_buyer, p_variant_id);
  if v_line.variant_id is null then
    raise exception 'PRODUCT_UNAVAILABLE';
  end if;
  if v_line.problem is not null then
    raise exception '%', v_line.problem;
  end if;

  select quantity into v_current
  from public.cart_items
  where user_id = v_buyer and variant_id = p_variant_id
  for update;

  if v_current is null then
    if (select count(*) from public.cart_items where user_id = v_buyer) >= 50 then
      raise exception 'CART_FULL';
    end if;
  elsif v_current >= least(v_line.stock, 99) then
    raise exception 'STOCK_LIMIT';
  end if;

  insert into public.cart_items (user_id, variant_id, quantity)
  values (v_buyer, p_variant_id, 1)
  on conflict (user_id, variant_id)
  do update set quantity = public.cart_items.quantity + 1;

  return public.cart_view(v_buyer, null);
end;
$$;

revoke all on function public.add_to_cart(uuid) from public, anon;
grant execute on function public.add_to_cart(uuid) to authenticated;

-- For the cart button on product cards, which don't know the variants. A
-- product with choices refuses, and the app opens its page to choose there.
create function public.add_product_to_cart(p_product_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_variants uuid[];
begin
  perform public.require_active_buyer();

  select array_agg(id) into v_variants
  from public.product_variants
  where product_id = p_product_id and is_active;

  if v_variants is null then
    raise exception 'PRODUCT_UNAVAILABLE';
  end if;
  if cardinality(v_variants) > 1 then
    raise exception 'VARIANT_REQUIRED';
  end if;

  return public.add_to_cart(v_variants[1]);
end;
$$;

revoke all on function public.add_product_to_cart(uuid) from public, anon;
grant execute on function public.add_product_to_cart(uuid) to authenticated;

-- Zero removes the line. Lowering a quantity always works, even for a product
-- that has since gone away. Raising one has to pass the normal checks.
create function public.set_cart_quantity(p_variant_id uuid, p_quantity integer)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_buyer uuid := public.require_active_buyer();
  v_current integer;
  v_line public.checkout_line;
begin
  if p_quantity is null or p_quantity < 0 then
    raise exception 'INVALID_QUANTITY';
  end if;

  if p_quantity = 0 then
    delete from public.cart_items
    where user_id = v_buyer and variant_id = p_variant_id;
    return public.cart_view(v_buyer, null);
  end if;

  select quantity into v_current
  from public.cart_items
  where user_id = v_buyer and variant_id = p_variant_id
  for update;

  if v_current is null then
    raise exception 'CART_ITEM_NOT_FOUND';
  end if;

  if p_quantity > v_current then
    select * into v_line from public.checkout_lines(v_buyer, p_variant_id);
    if v_line.problem in ('OWN_PRODUCT', 'PRODUCT_UNAVAILABLE', 'OUT_OF_STOCK') then
      raise exception '%', v_line.problem;
    end if;
    if p_quantity > least(v_line.stock, 99) then
      raise exception 'STOCK_LIMIT';
    end if;
  end if;

  update public.cart_items
  set quantity = p_quantity
  where user_id = v_buyer and variant_id = p_variant_id;

  return public.cart_view(v_buyer, null);
end;
$$;

revoke all on function public.set_cart_quantity(uuid, integer) from public, anon;
grant execute on function public.set_cart_quantity(uuid, integer) to authenticated;

-- Locks products, then variants, each in ID order. Every writer takes them in
-- this order (save_product locks the product first too), which prevents
-- deadlocks. "No key update" still lets new rows point at these products.
create function public.lock_variants(p_variant_ids uuid[])
returns void
language plpgsql
set search_path = ''
as $$
begin
  perform 1
  from public.products p
  where p.id in (
    select v.product_id from public.product_variants v where v.id = any (p_variant_ids)
  )
  order by p.id
  for no key update;

  perform 1
  from public.product_variants v
  where v.id = any (p_variant_ids)
  order by v.id
  for update;
end;
$$;

revoke all on function public.lock_variants(uuid[]) from public, anon, authenticated;

-- Checkout, as one transaction: any failure undoes all of it.
-- p_buy_now_variant_id null means the whole cart, and otherwise one of that
-- item, leaving the cart as it was.
create function public.place_order(
  p_address_id uuid,
  p_idempotency_key text,
  p_expected_total numeric,
  p_buy_now_variant_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_buyer uuid := public.require_active_buyer();
  v_order public.orders;
  v_address public.addresses;
  v_settings public.platform_settings;
  v_country char(2);
  v_currency char(3);
  v_region text;
  v_shipping jsonb;
  v_variant_ids uuid[];
  v_lines public.checkout_line[];
  v_problem text;
  v_subtotal numeric;
  v_delivery numeric;
  v_group_id uuid;
  v_shop record;
begin
  if p_idempotency_key is null or length(p_idempotency_key) not between 16 and 64 then
    raise exception 'INVALID_REQUEST';
  end if;

  -- One checkout per buyer at a time. A double tap waits here, then finds the
  -- first order below instead of seeing an empty cart.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('place_order:' || v_buyer::text, 0)
  );

  select * into v_order
  from public.orders
  where buyer_id = v_buyer and idempotency_key = p_idempotency_key;
  if v_order.id is not null then
    return jsonb_build_object('order_id', v_order.id, 'order_number', v_order.order_number);
  end if;

  if not exists (
    select 1 from public.profiles where id = v_buyer and phone_verified_at is not null
  ) then
    raise exception 'PHONE_NOT_VERIFIED';
  end if;

  select * into v_address
  from public.addresses
  where id = p_address_id and user_id = v_buyer;
  if v_address.id is null then
    raise exception 'ADDRESS_NOT_FOUND';
  end if;

  with recursive path as (
    select r.name, r.parent_id, r.country_code, 0 as depth
    from public.regions r
    where r.id = v_address.region_id
    union all
    select r.name, r.parent_id, r.country_code, path.depth + 1
    from public.regions r
    join path on r.id = path.parent_id
  )
  select string_agg(path.name, ', ' order by path.depth), max(path.country_code)
  into v_region, v_country
  from path;

  select * into v_settings from public.platform_settings where country_code = v_country;
  select currency_code into v_currency from public.countries where code = v_country;

  if p_buy_now_variant_id is not null then
    v_variant_ids := array[p_buy_now_variant_id];
  else
    select array_agg(variant_id) into v_variant_ids
    from public.cart_items
    where user_id = v_buyer;
    if v_variant_ids is null then
      raise exception 'CART_EMPTY';
    end if;
  end if;

  perform public.lock_variants(v_variant_ids);

  -- Read after locking, so this is the latest price and stock. Everything
  -- below uses this one reading.
  select array_agg(l) into v_lines
  from public.checkout_lines(v_buyer, p_buy_now_variant_id) as l;
  if v_lines is null then
    raise exception 'PRODUCT_UNAVAILABLE';
  end if;

  select l.problem into v_problem
  from unnest(v_lines) as l
  where l.problem is not null
  order by case l.problem
    when 'OWN_PRODUCT' then 1
    when 'PRODUCT_UNAVAILABLE' then 2
    else 3
  end
  limit 1;
  if v_problem = 'LOW_STOCK' then
    v_problem := 'OUT_OF_STOCK';
  end if;
  if v_problem is not null then
    raise exception '%', v_problem;
  end if;

  if exists (select 1 from unnest(v_lines) as l where l.country_code <> v_country) then
    raise exception 'PRODUCT_UNAVAILABLE';
  end if;

  select sum(l.unit_price * l.quantity) into v_subtotal from unnest(v_lines) as l;
  select sum(s.delivery_fee) into v_delivery
  from (select distinct l.shop_id, l.delivery_fee from unnest(v_lines) as l) as s;

  if p_expected_total is null or round(p_expected_total, 2) <> v_subtotal + v_delivery then
    raise exception 'PRICE_CHANGED';
  end if;
  if v_subtotal + v_delivery > v_settings.max_cod_order_value then
    raise exception 'COD_LIMIT_EXCEEDED';
  end if;

  v_shipping := jsonb_build_object(
    'recipient_name', v_address.recipient_name,
    'phone', v_address.phone,
    'line1', v_address.line1,
    'region', v_region,
    'postal_code', v_address.postal_code
  );

  insert into public.orders (
    buyer_id, country_code, currency_code, subtotal, delivery_total, grand_total, idempotency_key
  )
  values (
    v_buyer, v_country, v_currency, v_subtotal, v_delivery, v_subtotal + v_delivery,
    p_idempotency_key
  )
  returning * into v_order;

  for v_shop in
    select
      l.shop_id,
      l.shop_name,
      l.delivery_fee,
      sum(l.unit_price * l.quantity) as subtotal,
      sum(round(l.unit_price * l.quantity * v_settings.commission_rate / 100, 2)) as commission
    from unnest(v_lines) as l
    group by l.shop_id, l.shop_name, l.delivery_fee
  loop
    insert into public.seller_order_groups (
      order_id, shop_id, shop_name, subtotal, delivery_fee, commission_total, shipping_address
    )
    values (
      v_order.id, v_shop.shop_id, v_shop.shop_name, v_shop.subtotal, v_shop.delivery_fee,
      v_shop.commission, v_shipping
    )
    returning id into v_group_id;

    insert into public.order_items (
      group_id, product_id, variant_id, product_title, variant_name, image_path,
      unit_price, quantity, line_total, commission_rate, commission_amount
    )
    select
      v_group_id, l.product_id, l.variant_id, l.title, l.variant_name, l.image_path,
      l.unit_price, l.quantity, l.unit_price * l.quantity, v_settings.commission_rate,
      round(l.unit_price * l.quantity * v_settings.commission_rate / 100, 2)
    from unnest(v_lines) as l
    where l.shop_id = v_shop.shop_id;

    insert into public.payments (group_id, amount)
    values (v_group_id, v_shop.subtotal + v_shop.delivery_fee);

    insert into public.order_status_history (group_id, to_status, changed_by)
    values (v_group_id, 'pending', v_buyer);
  end loop;

  update public.product_variants v
  set stock = v.stock - l.quantity
  from unnest(v_lines) as l
  where v.id = l.variant_id;

  if p_buy_now_variant_id is null then
    delete from public.cart_items where user_id = v_buyer;
  end if;

  return jsonb_build_object('order_id', v_order.id, 'order_number', v_order.order_number);
end;
$$;

revoke all on function public.place_order(uuid, text, numeric, uuid) from public, anon;
grant execute on function public.place_order(uuid, text, numeric, uuid) to authenticated;

-- The buyer or the seller cancels one seller's part before it goes out for
-- delivery. Stock returns, even to a variant that has since been turned off.
create function public.cancel_order_group(p_group_id uuid, p_reason text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
  v_group public.seller_order_groups;
  v_variant_ids uuid[];
begin
  if v_user is null then
    raise exception 'NOT_SIGNED_IN';
  end if;

  select g.* into v_group
  from public.seller_order_groups g
  join public.orders o on o.id = g.order_id
  where g.id = p_group_id
    and (o.buyer_id = v_user or g.shop_id = public.current_shop_id())
  for update of g;
  if v_group.id is null then
    raise exception 'ORDER_NOT_FOUND';
  end if;
  if v_group.status not in ('pending', 'packaging') then
    raise exception 'ORDER_NOT_CANCELLABLE';
  end if;

  select array_agg(variant_id) into v_variant_ids
  from public.order_items
  where group_id = p_group_id and variant_id is not null;

  if v_variant_ids is not null then
    perform public.lock_variants(v_variant_ids);

    update public.product_variants v
    set stock = v.stock + i.quantity
    from public.order_items i
    where i.group_id = p_group_id and v.id = i.variant_id;
  end if;

  update public.seller_order_groups set status = 'cancelled' where id = p_group_id;
  update public.payments set status = 'cancelled' where group_id = p_group_id;

  insert into public.order_status_history (group_id, from_status, to_status, changed_by, note)
  values (
    p_group_id, v_group.status, 'cancelled', v_user,
    nullif(left(btrim(p_reason), 300), '')
  );
end;
$$;

revoke all on function public.cancel_order_group(uuid, text) from public, anon;
grant execute on function public.cancel_order_group(uuid, text) to authenticated;

-- My Orders, newest first.
create function public.get_my_orders(
  p_cursor_key text default null,
  p_cursor_id uuid default null,
  p_limit integer default 20
)
returns table (
  id uuid,
  order_number text,
  grand_total numeric,
  created_at timestamptz,
  groups jsonb,
  cursor_key text
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    o.id,
    o.order_number,
    o.grand_total,
    o.created_at,
    (
      select jsonb_agg(
        jsonb_build_object(
          'id', g.id,
          'shop_name', g.shop_name,
          'status', g.status,
          'item_count', (
            select count(*) from public.order_items i where i.group_id = g.id
          ),
          'first_title', (
            select i.product_title from public.order_items i
            where i.group_id = g.id
            order by i.created_at, i.id
            limit 1
          ),
          'first_image_path', (
            select i.image_path from public.order_items i
            where i.group_id = g.id
            order by i.created_at, i.id
            limit 1
          )
        )
        order by g.shop_name, g.id
      )
      from public.seller_order_groups g
      where g.order_id = o.id
    ),
    extract(epoch from o.created_at)::text
  from public.orders o
  where o.buyer_id = (select auth.uid())
    and (
      p_cursor_id is null
      or (extract(epoch from o.created_at), o.id) < (p_cursor_key::numeric, p_cursor_id)
    )
  order by o.created_at desc, o.id desc
  limit least(greatest(coalesce(p_limit, 20), 1), 60);
$$;

revoke all on function public.get_my_orders(text, uuid, integer) from public, anon;
grant execute on function public.get_my_orders(text, uuid, integer) to authenticated;

-- Account deletion. Someone still owed a delivery, or still owing one, can't
-- leave yet.
create function public.account_has_open_orders(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.seller_order_groups g
    join public.orders o on o.id = g.order_id
    left join public.shops s on s.id = g.shop_id
    where g.status in ('pending', 'packaging', 'out_for_delivery')
      and (o.buyer_id = p_user_id or s.seller_id = p_user_id)
  );
$$;

revoke all on function public.account_has_open_orders(uuid) from public, anon, authenticated;
grant execute on function public.account_has_open_orders(uuid) to service_role;

-- Runs however an account gets deleted. Order records stay, but the deleted
-- buyer's name, phone and address are removed from them.
create function public.prepare_profile_deletion()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if public.account_has_open_orders(old.id) then
    raise exception 'OPEN_ORDERS';
  end if;

  update public.seller_order_groups g
  set shipping_address = jsonb_build_object('recipient_name', 'Deleted user')
  from public.orders o
  where o.id = g.order_id and o.buyer_id = old.id;

  return old;
end;
$$;

revoke all on function public.prepare_profile_deletion() from public, anon, authenticated;

create trigger profiles_prepare_deletion
  before delete on public.profiles
  for each row execute function public.prepare_profile_deletion();
