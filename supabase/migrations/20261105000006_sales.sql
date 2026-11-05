-- Sales and commission: sellers move orders along, and completing an order
-- records the cash and adds the 1% commission to the seller's balance.
--
-- The ledger is only ever added to. Each order item already stores the rate and
-- amount from when it was placed, so a later rate change never affects it.

create type public.commission_entry_type as enum ('charge', 'settlement', 'adjustment');
create type public.settlement_method as enum ('bkash', 'bank');

create table public.settlements (
  id uuid primary key default gen_random_uuid(),
  -- Records outlive a deleted account.
  seller_id uuid references public.seller_profiles (user_id) on delete set null,
  amount numeric(12, 2) not null check (amount > 0),
  method public.settlement_method not null,
  reference text not null check (length(btrim(reference)) between 1 and 100),
  note text check (length(note) <= 300),
  recorded_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default clock_timestamp()
);

create index settlements_seller_id_idx on public.settlements (seller_id);
create index settlements_recorded_by_idx on public.settlements (recorded_by);

-- Charges are positive and settlements negative, so the balance is the sum.
create table public.commission_ledger (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid references public.seller_profiles (user_id) on delete set null,
  type public.commission_entry_type not null,
  amount numeric(12, 2) not null check (amount <> 0),
  group_id uuid references public.seller_order_groups (id),
  settlement_id uuid references public.settlements (id),
  note text check (length(note) <= 300),
  created_at timestamptz not null default clock_timestamp(),
  constraint commission_ledger_charge_shape
    check (type <> 'charge' or (amount > 0 and group_id is not null)),
  constraint commission_ledger_settlement_shape
    check (type <> 'settlement' or (amount < 0 and settlement_id is not null))
);

create index commission_ledger_seller_newest_idx
  on public.commission_ledger (seller_id, created_at desc, id desc);
create index commission_ledger_settlement_id_idx on public.commission_ledger (settlement_id);
-- The database itself guarantees one order can never be charged twice.
create unique index commission_ledger_one_charge_per_group_idx
  on public.commission_ledger (group_id) where type = 'charge';

alter table public.settlements enable row level security;
alter table public.commission_ledger enable row level security;

revoke all on public.settlements, public.commission_ledger from anon, authenticated;
grant select on public.settlements, public.commission_ledger to authenticated;

create policy "Sellers can read their own settlements"
  on public.settlements for select to authenticated
  using (seller_id = (select auth.uid()));

create policy "Admins can read all settlements"
  on public.settlements for select to authenticated
  using ((select public.is_admin()));

create policy "Sellers can read their own commission"
  on public.commission_ledger for select to authenticated
  using (seller_id = (select auth.uid()));

create policy "Admins can read all commission"
  on public.commission_ledger for select to authenticated
  using ((select public.is_admin()));

-- What a seller owes right now. Internal.
create function public.seller_commission_balance(p_seller_id uuid)
returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(sum(amount), 0)
  from public.commission_ledger
  where seller_id = p_seller_id;
$$;

revoke all on function public.seller_commission_balance(uuid) from public, anon, authenticated;
grant execute on function public.seller_commission_balance(uuid) to service_role;

-- Blocked only above the limit, so owing exactly the limit is still allowed.
create function public.seller_over_commission_limit(p_seller_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.seller_commission_balance(p_seller_id) > s.commission_block_limit
  from public.profiles p
  join public.platform_settings s on s.country_code = p.country_code
  where p.id = p_seller_id;
$$;

revoke all on function public.seller_over_commission_limit(uuid) from public, anon, authenticated;

-- Covers every way of creating a listing. Existing listings stay live, and can
-- still be edited, because a seller needs sales to be able to pay.
create function public.block_new_products_over_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if public.seller_over_commission_limit(
    (select seller_id from public.shops where id = new.shop_id)
  ) then
    raise exception 'COMMISSION_LIMIT';
  end if;
  return new;
end;
$$;

revoke all on function public.block_new_products_over_limit() from public, anon, authenticated;

create trigger products_block_over_limit
  before insert on public.products
  for each row execute function public.block_new_products_over_limit();

-- Same as before, plus the limit, so a saved draft can't be published either.
create or replace function public.submit_product_for_review(p_product_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_shop_id uuid := public.current_shop_id();
  v_product public.products;
begin
  if not public.is_active_seller() then
    raise exception 'NOT_A_SELLER';
  end if;
  if public.seller_over_commission_limit((select auth.uid())) then
    raise exception 'COMMISSION_LIMIT';
  end if;

  select * into v_product
  from public.products
  where id = p_product_id and shop_id = v_shop_id and deleted_at is null
  for update;
  if v_product.id is null then
    raise exception 'PRODUCT_NOT_FOUND';
  end if;
  if v_product.status not in ('draft', 'rejected') then
    raise exception 'PRODUCT_NOT_SUBMITTABLE';
  end if;

  if not exists (select 1 from public.product_images where product_id = p_product_id) then
    raise exception 'PHOTO_REQUIRED';
  end if;
  if length(btrim(v_product.description)) < 10 then
    raise exception 'DESCRIPTION_REQUIRED';
  end if;
  if v_product.min_price is null then
    raise exception 'PRICE_REQUIRED';
  end if;

  perform public.queue_product_review(p_product_id, v_shop_id);
end;
$$;

-- Puts one seller's items back on sale. Internal. Stock returns even to a
-- variant that has since been turned off, and a deleted one is skipped.
create function public.restore_group_stock(p_group_id uuid)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_variant_ids uuid[];
begin
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
end;
$$;

revoke all on function public.restore_group_stock(uuid) from public, anon, authenticated;

create or replace function public.cancel_order_group(p_group_id uuid, p_reason text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
  v_group public.seller_order_groups;
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

  perform public.restore_group_stock(p_group_id);

  update public.seller_order_groups set status = 'cancelled' where id = p_group_id;
  update public.payments set status = 'cancelled' where group_id = p_group_id;

  insert into public.order_status_history (group_id, from_status, to_status, changed_by, note)
  values (
    p_group_id, v_group.status, 'cancelled', v_user,
    nullif(left(btrim(p_reason), 300), '')
  );
end;
$$;

-- The only way an order moves forward, one step at a time. Sellers with a
-- suspended shop can still finish orders they have already accepted.
create function public.update_group_status(
  p_group_id uuid,
  p_status public.order_group_status,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_seller uuid := (select auth.uid());
  v_shop_id uuid := public.current_shop_id();
  v_group public.seller_order_groups;
begin
  if v_shop_id is null then
    raise exception 'NOT_A_SELLER';
  end if;

  select * into v_group
  from public.seller_order_groups
  where id = p_group_id and shop_id = v_shop_id
  for update;
  if v_group.id is null then
    raise exception 'ORDER_NOT_FOUND';
  end if;

  -- A retry after a lost connection, so nothing more to do.
  if v_group.status = p_status then
    return;
  end if;

  if (v_group.status, p_status) not in (
    ('pending'::public.order_group_status, 'packaging'::public.order_group_status),
    ('packaging', 'out_for_delivery'),
    ('out_for_delivery', 'completed'),
    ('out_for_delivery', 'delivery_failed')
  ) then
    raise exception 'INVALID_STATUS_CHANGE';
  end if;

  if p_status = 'completed' then
    update public.payments
    set status = 'collected', collected_at = now()
    where group_id = p_group_id;

    if v_group.commission_total > 0 then
      insert into public.commission_ledger (seller_id, type, amount, group_id)
      values (v_seller, 'charge', v_group.commission_total, p_group_id);
    end if;

    -- In ID order, so two completions can't deadlock.
    perform 1
    from public.products p
    where p.id in (select i.product_id from public.order_items i where i.group_id = p_group_id)
    order by p.id
    for no key update;

    update public.products p
    set sold_count = p.sold_count + sold.units
    from (
      select i.product_id, sum(i.quantity)::integer as units
      from public.order_items i
      where i.group_id = p_group_id and i.product_id is not null
      group by i.product_id
    ) as sold
    where p.id = sold.product_id;
  elsif p_status = 'delivery_failed' then
    perform public.restore_group_stock(p_group_id);
    update public.payments set status = 'failed' where group_id = p_group_id;
  end if;

  update public.seller_order_groups set status = p_status where id = p_group_id;

  insert into public.order_status_history (group_id, from_status, to_status, changed_by, note)
  values (
    p_group_id, v_group.status, p_status, v_seller,
    nullif(left(btrim(p_note), 300), '')
  );
end;
$$;

revoke all on function public.update_group_status(
  uuid, public.order_group_status, text
) from public, anon;
grant execute on function public.update_group_status(
  uuid, public.order_group_status, text
) to authenticated;

-- The Sales tabs. Security definer, because sellers can't read orders, and need
-- only the order number from there.
create function public.get_shop_orders(
  p_statuses public.order_group_status[],
  p_cursor_key text default null,
  p_cursor_id uuid default null,
  p_limit integer default 20
)
returns table (
  id uuid,
  order_number text,
  status public.order_group_status,
  amount_to_collect numeric,
  created_at timestamptz,
  recipient_name text,
  item_count bigint,
  first_title text,
  first_image_path text,
  cursor_key text
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    g.id,
    o.order_number,
    g.status,
    g.subtotal + g.delivery_fee,
    g.created_at,
    g.shipping_address ->> 'recipient_name',
    (select count(*) from public.order_items i where i.group_id = g.id),
    (
      select i.product_title from public.order_items i
      where i.group_id = g.id
      order by i.created_at, i.id
      limit 1
    ),
    (
      select i.image_path from public.order_items i
      where i.group_id = g.id
      order by i.created_at, i.id
      limit 1
    ),
    extract(epoch from g.created_at)::text
  from public.seller_order_groups g
  join public.orders o on o.id = g.order_id
  where g.shop_id = public.current_shop_id()
    and g.status = any (p_statuses)
    and (
      p_cursor_id is null
      or (extract(epoch from g.created_at), g.id) < (p_cursor_key::numeric, p_cursor_id)
    )
  order by g.created_at desc, g.id desc
  limit least(greatest(coalesce(p_limit, 20), 1), 60);
$$;

revoke all on function public.get_shop_orders(
  public.order_group_status[], text, uuid, integer
) from public, anon;
grant execute on function public.get_shop_orders(
  public.order_group_status[], text, uuid, integer
) to authenticated;

-- One seller's part of an order, including what the commission will be.
-- Null if it isn't this seller's. Nothing here shows other sellers' items.
create function public.get_shop_order(p_group_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', g.id,
    'order_number', o.order_number,
    'status', g.status,
    'subtotal', g.subtotal,
    'delivery_fee', g.delivery_fee,
    'commission_total', g.commission_total,
    'shipping_address', g.shipping_address,
    'created_at', g.created_at,
    'items', (
      select coalesce(jsonb_agg(
        jsonb_build_object(
          'id', i.id,
          'product_id', i.product_id,
          'product_title', i.product_title,
          'variant_name', i.variant_name,
          'image_path', i.image_path,
          'unit_price', i.unit_price,
          'quantity', i.quantity,
          'line_total', i.line_total
        )
        order by i.created_at, i.id
      ), '[]'::jsonb)
      from public.order_items i
      where i.group_id = g.id
    ),
    'history', (
      select coalesce(jsonb_agg(
        jsonb_build_object('status', h.to_status, 'note', h.note, 'created_at', h.created_at)
        order by h.created_at, h.id
      ), '[]'::jsonb)
      from public.order_status_history h
      where h.group_id = g.id
    )
  )
  from public.seller_order_groups g
  join public.orders o on o.id = g.order_id
  where g.id = p_group_id and g.shop_id = public.current_shop_id();
$$;

revoke all on function public.get_shop_order(uuid) from public, anon;
grant execute on function public.get_shop_order(uuid) to authenticated;

-- The top of the Commission screen.
create function public.get_commission_summary()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'balance', public.seller_commission_balance(p.id),
    'total_charged', coalesce((
      select sum(l.amount) from public.commission_ledger l
      where l.seller_id = p.id and l.amount > 0
    ), 0),
    'total_paid', coalesce((
      select -sum(l.amount) from public.commission_ledger l
      where l.seller_id = p.id and l.amount < 0
    ), 0),
    'commission_rate', s.commission_rate,
    'block_limit', s.commission_block_limit,
    'is_blocked', public.seller_over_commission_limit(p.id)
  )
  from public.profiles p
  join public.platform_settings s on s.country_code = p.country_code
  where p.id = (select auth.uid());
$$;

revoke all on function public.get_commission_summary() from public, anon;
grant execute on function public.get_commission_summary() to authenticated;

-- The seller's charges and payments, newest first.
create function public.get_commission_entries(
  p_cursor_key text default null,
  p_cursor_id uuid default null,
  p_limit integer default 20
)
returns table (
  id uuid,
  type public.commission_entry_type,
  amount numeric,
  created_at timestamptz,
  order_number text,
  method public.settlement_method,
  reference text,
  note text,
  cursor_key text
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    l.id,
    l.type,
    l.amount,
    l.created_at,
    o.order_number,
    st.method,
    st.reference,
    coalesce(l.note, st.note),
    extract(epoch from l.created_at)::text
  from public.commission_ledger l
  left join public.seller_order_groups g on g.id = l.group_id
  left join public.orders o on o.id = g.order_id
  left join public.settlements st on st.id = l.settlement_id
  where l.seller_id = (select auth.uid())
    and (
      p_cursor_id is null
      or (extract(epoch from l.created_at), l.id) < (p_cursor_key::numeric, p_cursor_id)
    )
  order by l.created_at desc, l.id desc
  limit least(greatest(coalesce(p_limit, 20), 1), 60);
$$;

revoke all on function public.get_commission_entries(text, uuid, integer) from public, anon;
grant execute on function public.get_commission_entries(text, uuid, integer) to authenticated;

-- An admin records money a seller has paid. The admin screen arrives in Step 7.
create function public.admin_record_settlement(
  p_seller_id uuid,
  p_amount numeric,
  p_method public.settlement_method,
  p_reference text,
  p_note text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_settlement_id uuid;
begin
  if not public.is_admin() then
    raise exception 'NOT_AN_ADMIN';
  end if;
  if p_amount is null or p_amount <= 0 or p_amount <> round(p_amount, 2) then
    raise exception 'INVALID_AMOUNT';
  end if;
  if nullif(btrim(p_reference), '') is null then
    raise exception 'REFERENCE_REQUIRED';
  end if;

  -- One settlement per seller at a time, so two can't both pass the check.
  perform 1 from public.seller_profiles where user_id = p_seller_id for update;
  if not found then
    raise exception 'SELLER_NOT_FOUND';
  end if;
  if p_amount > public.seller_commission_balance(p_seller_id) then
    raise exception 'SETTLEMENT_TOO_HIGH';
  end if;

  insert into public.settlements (seller_id, amount, method, reference, note, recorded_by)
  values (
    p_seller_id, p_amount, p_method, btrim(p_reference),
    nullif(left(btrim(p_note), 300), ''), (select auth.uid())
  )
  returning id into v_settlement_id;

  insert into public.commission_ledger (seller_id, type, amount, settlement_id)
  values (p_seller_id, 'settlement', -p_amount, v_settlement_id);

  return v_settlement_id;
end;
$$;

revoke all on function public.admin_record_settlement(
  uuid, numeric, public.settlement_method, text, text
) from public, anon;
grant execute on function public.admin_record_settlement(
  uuid, numeric, public.settlement_method, text, text
) to authenticated;

-- A seller can't leave while owing commission. The record of what was charged
-- and paid stays after the account has gone.
create or replace function public.prepare_profile_deletion()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if public.account_has_open_orders(old.id) then
    raise exception 'OPEN_ORDERS';
  end if;
  if public.seller_commission_balance(old.id) > 0 then
    raise exception 'OWES_COMMISSION';
  end if;

  update public.seller_order_groups g
  set shipping_address = jsonb_build_object('recipient_name', 'Deleted user')
  from public.orders o
  where o.id = g.order_id and o.buyer_id = old.id;

  return old;
end;
$$;
