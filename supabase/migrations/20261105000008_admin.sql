-- Admin panel: everything the web panel can do. Every function here checks
-- is_admin() on the server, so the panel itself holds no special power and no
-- service key. supabase/tests/admin.test.sql checks that no function was missed.

alter type public.notification_type add value if not exists 'report_update';

-- A record of who did what, for anything without its own "decided by" column.
create table public.admin_actions (
  id bigint generated always as identity primary key,
  admin_id uuid references public.profiles (id) on delete set null,
  action text not null,
  target_type text not null,
  target_id text not null,
  details jsonb not null default '{}',
  created_at timestamptz not null default clock_timestamp()
);

create index admin_actions_newest_idx on public.admin_actions (created_at desc);
create index admin_actions_admin_id_idx on public.admin_actions (admin_id);

alter table public.admin_actions enable row level security;
revoke all on public.admin_actions from anon, authenticated;
grant select on public.admin_actions to authenticated;

create policy "Admins can read the admin record"
  on public.admin_actions for select to authenticated
  using ((select public.is_admin()));

-- Internal: refuses anyone who isn't an admin, and returns who it is.
create function public.require_admin()
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'NOT_AN_ADMIN';
  end if;
  return (select auth.uid());
end;
$$;

revoke all on function public.require_admin() from public, anon, authenticated;

create function public.log_admin_action(
  p_action text,
  p_target_type text,
  p_target_id text,
  p_details jsonb default '{}'
)
returns void
language sql
set search_path = ''
as $$
  insert into public.admin_actions (admin_id, action, target_type, target_id, details)
  values ((select auth.uid()), p_action, p_target_type, p_target_id, p_details);
$$;

revoke all on function public.log_admin_action(text, text, text, jsonb)
  from public, anon, authenticated;

-- Typed search text is matched literally, even % and _.
create function public.search_pattern(p_text text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case when nullif(btrim(p_text), '') is null then null else
    '%' || replace(replace(replace(btrim(p_text), '\', '\\'), '%', '\%'), '_', '\_') || '%'
  end;
$$;

revoke all on function public.search_pattern(text) from public, anon, authenticated;

-- ---------------------------------------------------------------------- Overview

create function public.admin_get_overview()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform public.require_admin();
  return jsonb_build_object(
    'review_queue', (select count(*) from public.products where status = 'admin_review' and deleted_at is null),
    'open_reports', (select count(*) from public.reports where status = 'open'),
    'users', (select count(*) from public.profiles),
    'sellers', (select count(*) from public.seller_profiles),
    'live_products', (select count(*) from public.products where status = 'active' and deleted_at is null),
    'open_orders', (
      select count(*) from public.seller_order_groups
      where status in ('pending', 'packaging', 'out_for_delivery')
    ),
    'orders_today', (
      select count(*) from public.orders
      where created_at >= (((now() at time zone 'Asia/Dhaka')::date)::timestamp at time zone 'Asia/Dhaka')
    ),
    'commission_owed', (select coalesce(sum(amount), 0) from public.commission_ledger where seller_id is not null)
  );
end;
$$;

revoke all on function public.admin_get_overview() from public, anon;
grant execute on function public.admin_get_overview() to authenticated;

-- ------------------------------------------------------------- Product review queue

-- Oldest first, so nobody waits longest. Includes the AI's reason, which sellers
-- never see. admin_decide_product makes the decision.
create function public.admin_get_review_queue(
  p_cursor_key text default null,
  p_cursor_id uuid default null,
  p_limit integer default 20
)
returns table (
  id uuid,
  title text,
  description text,
  condition public.product_condition,
  shop_name text,
  category_name text,
  price numeric,
  total_stock integer,
  image_paths text[],
  variant_names text[],
  ai_decision public.ai_decision,
  reason_code text,
  ai_reason text,
  last_error text,
  waiting_since timestamptz,
  cursor_key text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform public.require_admin();
  return query
    select
      p.id,
      p.title,
      p.description,
      p.condition,
      s.name,
      c.name,
      p.min_price,
      p.total_stock,
      coalesce((
        select array_agg(i.storage_path order by i.sort_order)
        from public.product_images i where i.product_id = p.id
      ), '{}'),
      coalesce((
        select array_agg(v.name order by v.name)
        from public.product_variants v where v.product_id = p.id and v.is_active
      ), '{}'),
      r.ai_decision,
      r.reason_code,
      r.ai_reason,
      r.last_error,
      r.created_at,
      extract(epoch from r.created_at)::text
    from public.products p
    join public.shops s on s.id = p.shop_id
    join public.categories c on c.id = p.category_id
    join lateral (
      select m.* from public.moderation_reviews m
      where m.product_id = p.id
      order by m.created_at desc
      limit 1
    ) r on true
    where p.status = 'admin_review'
      and p.deleted_at is null
      and (
        p_cursor_id is null
        or (extract(epoch from r.created_at), p.id) > (p_cursor_key::numeric, p_cursor_id)
      )
    order by r.created_at, p.id
    limit least(greatest(coalesce(p_limit, 20), 1), 60);
end;
$$;

revoke all on function public.admin_get_review_queue(text, uuid, integer) from public, anon;
grant execute on function public.admin_get_review_queue(text, uuid, integer) to authenticated;

-- ------------------------------------------------------------------------- Users

create function public.admin_list_users(
  p_search text default null,
  p_cursor_key text default null,
  p_cursor_id uuid default null,
  p_limit integer default 30
)
returns table (
  id uuid,
  full_name text,
  email text,
  phone text,
  status public.profile_status,
  is_admin boolean,
  shop_name text,
  commission_owed numeric,
  created_at timestamptz,
  cursor_key text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_pattern text := public.search_pattern(p_search);
begin
  perform public.require_admin();
  return query
    select
      p.id,
      p.full_name,
      u.email::text,
      p.phone,
      p.status,
      exists (select 1 from public.admin_users a where a.user_id = p.id),
      s.name,
      public.seller_commission_balance(p.id),
      p.created_at,
      extract(epoch from p.created_at)::text
    from public.profiles p
    join auth.users u on u.id = p.id
    left join public.shops s on s.seller_id = p.id
    where (
        v_pattern is null
        or p.full_name ilike v_pattern
        or u.email ilike v_pattern
        or p.phone ilike v_pattern
        or s.name ilike v_pattern
      )
      and (
        p_cursor_id is null
        or (extract(epoch from p.created_at), p.id) < (p_cursor_key::numeric, p_cursor_id)
      )
    order by p.created_at desc, p.id desc
    limit least(greatest(coalesce(p_limit, 30), 1), 100);
end;
$$;

revoke all on function public.admin_list_users(text, text, uuid, integer) from public, anon;
grant execute on function public.admin_list_users(text, text, uuid, integer) to authenticated;

-- Suspending a seller also turns off their shop, which hides their products from
-- everyone. Orders already accepted can still be finished.
create function public.admin_set_user_status(
  p_user_id uuid,
  p_status public.profile_status,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid := public.require_admin();
  v_reason text := nullif(btrim(p_reason), '');
begin
  if p_user_id = v_admin or exists (
    select 1 from public.admin_users where user_id = p_user_id
  ) then
    raise exception 'CANNOT_CHANGE_ADMIN';
  end if;
  if p_status = 'suspended' and v_reason is null then
    raise exception 'REASON_REQUIRED';
  end if;

  update public.profiles set status = p_status where id = p_user_id;
  if not found then
    raise exception 'USER_NOT_FOUND';
  end if;

  update public.seller_profiles
  set status = case when p_status = 'active' then 'active' else 'suspended' end::public.seller_status
  where user_id = p_user_id;

  update public.shops
  set is_active = (p_status = 'active')
  where seller_id = p_user_id;

  perform public.log_admin_action(
    'set_user_status', 'user', p_user_id::text,
    jsonb_build_object('status', p_status, 'reason', v_reason)
  );
end;
$$;

revoke all on function public.admin_set_user_status(uuid, public.profile_status, text) from public, anon;
grant execute on function public.admin_set_user_status(uuid, public.profile_status, text) to authenticated;

-- ---------------------------------------------------------------------- Products

create function public.admin_list_products(
  p_search text default null,
  p_status public.product_status default null,
  p_cursor_key text default null,
  p_cursor_id uuid default null,
  p_limit integer default 30
)
returns table (
  id uuid,
  title text,
  shop_name text,
  status public.product_status,
  price numeric,
  total_stock integer,
  sold_count integer,
  image_path text,
  created_at timestamptz,
  cursor_key text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_pattern text := public.search_pattern(p_search);
begin
  perform public.require_admin();
  return query
    select
      p.id,
      p.title,
      s.name,
      p.status,
      p.min_price,
      p.total_stock,
      p.sold_count,
      (
        select i.storage_path from public.product_images i
        where i.product_id = p.id
        order by i.sort_order
        limit 1
      ),
      p.created_at,
      extract(epoch from p.created_at)::text
    from public.products p
    join public.shops s on s.id = p.shop_id
    where p.deleted_at is null
      and (p_status is null or p.status = p_status)
      and (v_pattern is null or p.title ilike v_pattern or s.name ilike v_pattern)
      and (
        p_cursor_id is null
        or (extract(epoch from p.created_at), p.id) < (p_cursor_key::numeric, p_cursor_id)
      )
    order by p.created_at desc, p.id desc
    limit least(greatest(coalesce(p_limit, 30), 1), 100);
end;
$$;

revoke all on function public.admin_list_products(
  text, public.product_status, text, uuid, integer
) from public, anon;
grant execute on function public.admin_list_products(
  text, public.product_status, text, uuid, integer
) to authenticated;

-- Takes a listing down, or puts one back. The seller is told either way.
create function public.admin_set_product_removed(
  p_product_id uuid,
  p_removed boolean,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reason text := nullif(btrim(p_reason), '');
  v_product public.products;
  v_seller uuid;
begin
  perform public.require_admin();
  if p_removed and v_reason is null then
    raise exception 'REASON_REQUIRED';
  end if;

  select * into v_product
  from public.products
  where id = p_product_id and deleted_at is null
  for update;
  if v_product.id is null then
    raise exception 'PRODUCT_NOT_FOUND';
  end if;
  if p_removed = (v_product.status = 'removed') then
    raise exception 'PRODUCT_UNCHANGED';
  end if;

  update public.products
  set status = case when p_removed then 'removed' else 'active' end::public.product_status
  where id = p_product_id;

  update public.moderation_reviews
  set status = 'superseded'
  where product_id = p_product_id and status = 'queued';

  select seller_id into v_seller from public.shops where id = v_product.shop_id;
  if p_removed then
    perform public.notify(
      v_seller, 'listing_rejected', 'Your listing was removed',
      v_product.title || ': ' || v_reason, jsonb_build_object('product_id', p_product_id)
    );
  else
    perform public.notify(
      v_seller, 'listing_live', 'Your listing is back on sale',
      v_product.title, jsonb_build_object('product_id', p_product_id)
    );
  end if;

  perform public.log_admin_action(
    case when p_removed then 'remove_product' else 'restore_product' end,
    'product', p_product_id::text, jsonb_build_object('reason', v_reason)
  );
end;
$$;

revoke all on function public.admin_set_product_removed(uuid, boolean, text) from public, anon;
grant execute on function public.admin_set_product_removed(uuid, boolean, text) to authenticated;

-- ------------------------------------------------------------------------ Orders

-- One row per seller's part, because that is what moves through the steps.
create function public.admin_list_orders(
  p_search text default null,
  p_status public.order_group_status default null,
  p_cursor_key text default null,
  p_cursor_id uuid default null,
  p_limit integer default 30
)
returns table (
  id uuid,
  order_number text,
  shop_name text,
  buyer_name text,
  status public.order_group_status,
  amount numeric,
  commission numeric,
  created_at timestamptz,
  cursor_key text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_pattern text := public.search_pattern(p_search);
begin
  perform public.require_admin();
  return query
    select
      g.id,
      o.order_number,
      g.shop_name,
      g.shipping_address ->> 'recipient_name',
      g.status,
      g.subtotal + g.delivery_fee,
      g.commission_total,
      g.created_at,
      extract(epoch from g.created_at)::text
    from public.seller_order_groups g
    join public.orders o on o.id = g.order_id
    where (p_status is null or g.status = p_status)
      and (
        v_pattern is null
        or o.order_number ilike v_pattern
        or g.shop_name ilike v_pattern
        or g.shipping_address ->> 'recipient_name' ilike v_pattern
      )
      and (
        p_cursor_id is null
        or (extract(epoch from g.created_at), g.id) < (p_cursor_key::numeric, p_cursor_id)
      )
    order by g.created_at desc, g.id desc
    limit least(greatest(coalesce(p_limit, 30), 1), 100);
end;
$$;

revoke all on function public.admin_list_orders(
  text, public.order_group_status, text, uuid, integer
) from public, anon;
grant execute on function public.admin_list_orders(
  text, public.order_group_status, text, uuid, integer
) to authenticated;

-- -------------------------------------------------------------------- Categories

create function public.admin_list_categories()
returns table (
  id uuid,
  parent_id uuid,
  name text,
  slug text,
  icon text,
  sort_order integer,
  is_active boolean,
  product_count bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform public.require_admin();
  return query
    select
      c.id, c.parent_id, c.name, c.slug, c.icon, c.sort_order, c.is_active,
      (
        select count(*) from public.products p
        where p.category_id = c.id and p.deleted_at is null
      )
    from public.categories c
    order by c.sort_order, c.name;
end;
$$;

revoke all on function public.admin_list_categories() from public, anon;
grant execute on function public.admin_list_categories() to authenticated;

-- Creates a category when p_id is null. Categories go only two levels deep, and
-- are turned off rather than deleted, because products point to them.
create function public.admin_save_category(
  p_id uuid,
  p_parent_id uuid,
  p_name text,
  p_slug text,
  p_icon text,
  p_sort_order integer,
  p_is_active boolean
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid := p_id;
begin
  perform public.require_admin();
  if nullif(btrim(p_name), '') is null then
    raise exception 'NAME_REQUIRED';
  end if;
  if p_slug is null or p_slug !~ '^[a-z0-9]+(-[a-z0-9]+)*$' then
    raise exception 'INVALID_SLUG';
  end if;
  if p_parent_id is not null then
    if p_parent_id = p_id or not exists (
      select 1 from public.categories where id = p_parent_id and parent_id is null
    ) then
      raise exception 'INVALID_PARENT';
    end if;
    if p_id is not null and exists (
      select 1 from public.categories where parent_id = p_id
    ) then
      raise exception 'INVALID_PARENT';
    end if;
  end if;

  begin
    if p_id is null then
      insert into public.categories (parent_id, name, slug, icon, sort_order, is_active)
      values (
        p_parent_id, btrim(p_name), p_slug, coalesce(nullif(btrim(p_icon), ''), 'category'),
        coalesce(p_sort_order, 0), coalesce(p_is_active, true)
      )
      returning id into v_id;
    else
      update public.categories
      set
        parent_id = p_parent_id,
        name = btrim(p_name),
        slug = p_slug,
        icon = coalesce(nullif(btrim(p_icon), ''), 'category'),
        sort_order = coalesce(p_sort_order, 0),
        is_active = coalesce(p_is_active, true)
      where id = p_id;
      if not found then
        raise exception 'CATEGORY_NOT_FOUND';
      end if;
    end if;
  exception when unique_violation then
    raise exception 'SLUG_TAKEN';
  end;

  perform public.log_admin_action(
    'save_category', 'category', v_id::text, jsonb_build_object('name', btrim(p_name))
  );
  return v_id;
end;
$$;

revoke all on function public.admin_save_category(
  uuid, uuid, text, text, text, integer, boolean
) from public, anon;
grant execute on function public.admin_save_category(
  uuid, uuid, text, text, text, integer, boolean
) to authenticated;

-- ---------------------------------------------------------------------- Settings

-- A rate change applies to new orders only. Orders keep the rate they were placed
-- at. Old and new values go in the admin record, because this is about money.
create function public.admin_update_settings(
  p_commission_rate numeric,
  p_commission_block_limit numeric,
  p_max_cod_order_value numeric,
  p_country_code char(2) default 'BD'
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old public.platform_settings;
begin
  perform public.require_admin();
  if p_commission_rate is null or p_commission_rate not between 0 and 100
    or p_commission_block_limit is null or p_commission_block_limit < 0
    or p_max_cod_order_value is null or p_max_cod_order_value <= 0
  then
    raise exception 'INVALID_SETTINGS';
  end if;

  select * into v_old from public.platform_settings
  where country_code = p_country_code for update;
  if v_old.country_code is null then
    raise exception 'INVALID_SETTINGS';
  end if;

  update public.platform_settings
  set
    commission_rate = p_commission_rate,
    commission_block_limit = p_commission_block_limit,
    max_cod_order_value = p_max_cod_order_value
  where country_code = p_country_code;

  perform public.log_admin_action(
    'update_settings', 'settings', p_country_code,
    jsonb_build_object(
      'old', to_jsonb(v_old),
      'new', jsonb_build_object(
        'commission_rate', p_commission_rate,
        'commission_block_limit', p_commission_block_limit,
        'max_cod_order_value', p_max_cod_order_value
      )
    )
  );
end;
$$;

revoke all on function public.admin_update_settings(numeric, numeric, numeric, char) from public, anon;
grant execute on function public.admin_update_settings(numeric, numeric, numeric, char) to authenticated;

-- ----------------------------------------------------------------------- Banners

create table public.home_banners (
  id uuid primary key default gen_random_uuid(),
  image_path text not null check (length(image_path) <= 500),
  title text not null default '' check (length(title) <= 120),
  -- Opens this product when tapped. A banner can also link nowhere.
  product_id uuid references public.products (id) on delete set null,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  starts_at timestamptz,
  ends_at timestamptz,
  created_at timestamptz not null default now(),
  constraint home_banners_dates_in_order check (ends_at is null or starts_at is null or ends_at > starts_at)
);

create index home_banners_product_id_idx on public.home_banners (product_id);

alter table public.home_banners enable row level security;
revoke all on public.home_banners from anon, authenticated;
grant select on public.home_banners to anon, authenticated;

create policy "Anyone can read banners showing now"
  on public.home_banners for select to anon, authenticated
  using (
    is_active
    and (starts_at is null or starts_at <= now())
    and (ends_at is null or ends_at > now())
  );

create policy "Admins can read all banners"
  on public.home_banners for select to authenticated
  using ((select public.is_admin()));

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('banners', 'banners', true, 5242880, array['image/jpeg', 'image/png'])
on conflict (id) do nothing;

create policy "Admins can add banner images"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'banners' and (select public.is_admin()));

create policy "Admins can read banner image records"
  on storage.objects for select to authenticated
  using (bucket_id = 'banners' and (select public.is_admin()));

create policy "Admins can delete banner images"
  on storage.objects for delete to authenticated
  using (bucket_id = 'banners' and (select public.is_admin()));

create function public.admin_save_banner(
  p_id uuid,
  p_image_path text,
  p_title text,
  p_product_id uuid,
  p_sort_order integer,
  p_is_active boolean,
  p_starts_at timestamptz default null,
  p_ends_at timestamptz default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid := p_id;
begin
  perform public.require_admin();
  if not exists (
    select 1 from storage.objects where bucket_id = 'banners' and name = p_image_path
  ) then
    raise exception 'INVALID_PHOTO';
  end if;
  if p_product_id is not null and not exists (
    select 1 from public.products where id = p_product_id and deleted_at is null
  ) then
    raise exception 'PRODUCT_NOT_FOUND';
  end if;
  if p_ends_at is not null and p_starts_at is not null and p_ends_at <= p_starts_at then
    raise exception 'INVALID_DATES';
  end if;

  if p_id is null then
    insert into public.home_banners (
      image_path, title, product_id, sort_order, is_active, starts_at, ends_at
    )
    values (
      p_image_path, coalesce(btrim(p_title), ''), p_product_id, coalesce(p_sort_order, 0),
      coalesce(p_is_active, true), p_starts_at, p_ends_at
    )
    returning id into v_id;
  else
    update public.home_banners
    set
      image_path = p_image_path,
      title = coalesce(btrim(p_title), ''),
      product_id = p_product_id,
      sort_order = coalesce(p_sort_order, 0),
      is_active = coalesce(p_is_active, true),
      starts_at = p_starts_at,
      ends_at = p_ends_at
    where id = p_id;
    if not found then
      raise exception 'BANNER_NOT_FOUND';
    end if;
  end if;

  perform public.log_admin_action('save_banner', 'banner', v_id::text);
  return v_id;
end;
$$;

revoke all on function public.admin_save_banner(
  uuid, text, text, uuid, integer, boolean, timestamptz, timestamptz
) from public, anon;
grant execute on function public.admin_save_banner(
  uuid, text, text, uuid, integer, boolean, timestamptz, timestamptz
) to authenticated;

-- Returns the image path, for the panel to remove the file.
create function public.admin_delete_banner(p_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_path text;
begin
  perform public.require_admin();
  delete from public.home_banners where id = p_id returning image_path into v_path;
  if v_path is null then
    raise exception 'BANNER_NOT_FOUND';
  end if;
  perform public.log_admin_action('delete_banner', 'banner', p_id::text);
  return v_path;
end;
$$;

revoke all on function public.admin_delete_banner(uuid) from public, anon;
grant execute on function public.admin_delete_banner(uuid) to authenticated;

-- ----------------------------------------------------------------------- Reports

-- What each report is about, so an admin can decide without searching for it.
-- The only place a private message is shown to an admin.
create function public.admin_list_reports(
  p_status public.report_status default 'open',
  p_cursor_key text default null,
  p_cursor_id uuid default null,
  p_limit integer default 30
)
returns table (
  id uuid,
  target_type public.report_target,
  target_id uuid,
  reason public.report_reason,
  details text,
  status public.report_status,
  reporter_name text,
  target_text text,
  -- The account behind what was reported, for suspending if needed.
  target_user_id uuid,
  resolution_note text,
  created_at timestamptz,
  cursor_key text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform public.require_admin();
  return query
    select
      r.id,
      r.target_type,
      r.target_id,
      r.reason,
      r.details,
      r.status,
      coalesce(nullif(btrim(p.full_name), ''), 'Deleted or unnamed user'),
      case r.target_type
        when 'product' then (select x.title from public.products x where x.id = r.target_id)
        when 'shop' then (select x.name from public.shops x where x.id = r.target_id)
        when 'review' then (select x.comment from public.reviews x where x.id = r.target_id)
        when 'message' then (select x.body from public.messages x where x.id = r.target_id)
      end,
      case r.target_type
        when 'product' then (
          select s.seller_id from public.products x
          join public.shops s on s.id = x.shop_id where x.id = r.target_id
        )
        when 'shop' then (select x.seller_id from public.shops x where x.id = r.target_id)
        when 'review' then (select x.buyer_id from public.reviews x where x.id = r.target_id)
        when 'message' then (select x.sender_id from public.messages x where x.id = r.target_id)
      end,
      r.resolution_note,
      r.created_at,
      extract(epoch from r.created_at)::text
    from public.reports r
    left join public.profiles p on p.id = r.reporter_id
    where r.status = p_status
      and (
        p_cursor_id is null
        or (extract(epoch from r.created_at), r.id) > (p_cursor_key::numeric, p_cursor_id)
      )
    order by r.created_at, r.id
    limit least(greatest(coalesce(p_limit, 30), 1), 100);
end;
$$;

revoke all on function public.admin_list_reports(
  public.report_status, text, uuid, integer
) from public, anon;
grant execute on function public.admin_list_reports(
  public.report_status, text, uuid, integer
) to authenticated;

-- Closes every open report about the same thing, and tells each person who sent
-- one. The note stays private: they only hear that it was looked at.
create function public.admin_resolve_report(
  p_report_id uuid,
  p_status public.report_status,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid := public.require_admin();
  v_report public.reports;
  v_reporter uuid;
begin
  if p_status not in ('resolved', 'dismissed') then
    raise exception 'INVALID_REPORT_STATUS';
  end if;

  select * into v_report from public.reports where id = p_report_id for update;
  if v_report.id is null then
    raise exception 'REPORT_NOT_FOUND';
  end if;
  if v_report.status <> 'open' then
    raise exception 'REPORT_ALREADY_CLOSED';
  end if;

  for v_reporter in
    update public.reports
    set
      status = p_status,
      resolved_by = v_admin,
      resolution_note = nullif(left(btrim(p_note), 1000), ''),
      resolved_at = clock_timestamp()
    where target_type = v_report.target_type
      and target_id = v_report.target_id
      and status = 'open'
    returning reporter_id
  loop
    perform public.notify(
      v_reporter, 'report_update', 'Thanks for your report',
      'We looked into what you reported.'
    );
  end loop;
end;
$$;

revoke all on function public.admin_resolve_report(uuid, public.report_status, text) from public, anon;
grant execute on function public.admin_resolve_report(uuid, public.report_status, text) to authenticated;

create function public.admin_set_review_hidden(p_review_id uuid, p_hidden boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.require_admin();
  update public.reviews
  set status = case when p_hidden then 'hidden' else 'visible' end::public.review_status
  where id = p_review_id;
  if not found then
    raise exception 'REVIEW_NOT_FOUND';
  end if;
  perform public.log_admin_action(
    case when p_hidden then 'hide_review' else 'show_review' end, 'review', p_review_id::text
  );
end;
$$;

revoke all on function public.admin_set_review_hidden(uuid, boolean) from public, anon;
grant execute on function public.admin_set_review_hidden(uuid, boolean) to authenticated;

-- ------------------------------------------------------------------- Settlements

-- Sellers who owe the most come first. admin_record_settlement takes the payment.
create function public.admin_list_sellers_owing(
  p_search text default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns table (
  seller_id uuid,
  shop_name text,
  phone text,
  payout_number text,
  total_charged numeric,
  total_paid numeric,
  balance numeric
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_pattern text := public.search_pattern(p_search);
begin
  perform public.require_admin();
  return query
    select
      sp.user_id,
      s.name,
      p.phone,
      sp.payout_number,
      coalesce(sum(l.amount) filter (where l.amount > 0), 0),
      coalesce(-sum(l.amount) filter (where l.amount < 0), 0),
      coalesce(sum(l.amount), 0) as balance
    from public.seller_profiles sp
    join public.shops s on s.seller_id = sp.user_id
    join public.profiles p on p.id = sp.user_id
    left join public.commission_ledger l on l.seller_id = sp.user_id
    where v_pattern is null or s.name ilike v_pattern or p.phone ilike v_pattern
    group by sp.user_id, s.name, p.phone, sp.payout_number
    having coalesce(sum(l.amount), 0) > 0
    order by balance desc, sp.user_id
    limit least(greatest(coalesce(p_limit, 50), 1), 100)
    offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

revoke all on function public.admin_list_sellers_owing(text, integer, integer) from public, anon;
grant execute on function public.admin_list_sellers_owing(text, integer, integer) to authenticated;

create function public.admin_list_settlements(
  p_cursor_key text default null,
  p_cursor_id uuid default null,
  p_limit integer default 30
)
returns table (
  id uuid,
  shop_name text,
  amount numeric,
  method public.settlement_method,
  reference text,
  note text,
  recorded_by_name text,
  created_at timestamptz,
  cursor_key text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform public.require_admin();
  return query
    select
      st.id,
      coalesce(s.name, 'Deleted shop'),
      st.amount,
      st.method,
      st.reference,
      st.note,
      coalesce(nullif(btrim(a.full_name), ''), 'Admin'),
      st.created_at,
      extract(epoch from st.created_at)::text
    from public.settlements st
    left join public.shops s on s.seller_id = st.seller_id
    left join public.profiles a on a.id = st.recorded_by
    where p_cursor_id is null
      or (extract(epoch from st.created_at), st.id) < (p_cursor_key::numeric, p_cursor_id)
    order by st.created_at desc, st.id desc
    limit least(greatest(coalesce(p_limit, 30), 1), 100);
end;
$$;

revoke all on function public.admin_list_settlements(text, uuid, integer) from public, anon;
grant execute on function public.admin_list_settlements(text, uuid, integer) to authenticated;
