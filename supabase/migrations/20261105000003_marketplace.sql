-- Marketplace: sellers, shops, categories, products, wishlist and search.
--
-- Clients can only read here. Step 3 adds the seller write paths, and product
-- status can never be changed directly by a seller.

create type public.seller_status as enum ('active', 'suspended');
create type public.product_condition as enum ('new', 'used');
create type public.product_status as enum (
  'draft', 'pending_review', 'admin_review', 'active', 'rejected', 'paused', 'removed'
);
create type public.product_sort as enum (
  'newest', 'popular', 'price_low', 'price_high', 'rating', 'relevance'
);

-- Private seller details. The public only ever sees the shop.
create table public.seller_profiles (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  status public.seller_status not null default 'active',
  payout_number text check (length(payout_number) <= 30),
  terms_accepted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger seller_profiles_set_updated_at
  before update on public.seller_profiles
  for each row execute function public.set_updated_at();

-- Each seller has one shop. Turning is_active off hides the shop and products.
create table public.shops (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null unique references public.seller_profiles (user_id) on delete cascade,
  name text not null check (length(trim(name)) between 2 and 80),
  slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  logo_path text check (length(logo_path) <= 500),
  banner_path text check (length(banner_path) <= 500),
  description text not null default '' check (length(description) <= 2000),
  region_id uuid references public.regions (id),
  delivery_fee numeric(12, 2) not null default 0 check (delivery_fee >= 0),
  is_active boolean not null default true,
  rating_avg numeric(3, 2) not null default 0 check (rating_avg between 0 and 5),
  rating_count integer not null default 0 check (rating_count >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index shops_region_id_idx on public.shops (region_id);

create trigger shops_set_updated_at
  before update on public.shops
  for each row execute function public.set_updated_at();

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  parent_id uuid references public.categories (id),
  name text not null check (length(trim(name)) > 0),
  slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  icon text not null default 'category' check (length(icon) <= 50),
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  check (parent_id is distinct from id)
);

create index categories_parent_id_idx on public.categories (parent_id);

create table public.products (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops (id) on delete cascade,
  category_id uuid not null references public.categories (id),
  title text not null check (length(trim(title)) between 3 and 120),
  description text not null default '' check (length(description) <= 5000),
  condition public.product_condition not null default 'new',
  status public.product_status not null default 'draft',
  country_code char(2) not null default 'BD' references public.countries (code),
  -- The next three are kept correct by a trigger on product_variants.
  min_price numeric(12, 2),
  compare_at_price numeric(12, 2),
  total_stock integer not null default 0 check (total_stock >= 0),
  rating_avg numeric(3, 2) not null default 0 check (rating_avg between 0 and 5),
  rating_count integer not null default 0 check (rating_count >= 0),
  sold_count integer not null default 0 check (sold_count >= 0),
  -- 'simple' rather than 'english', because listings can be in Bangla too.
  search_vector tsvector generated always as (
    setweight(to_tsvector('simple'::regconfig, title), 'A')
    || setweight(to_tsvector('simple'::regconfig, description), 'B')
  ) stored,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- A live product must always have something to buy.
  constraint products_active_has_price check (status <> 'active' or min_price is not null)
);

create index products_shop_id_idx on public.products (shop_id);
create index products_category_id_idx on public.products (category_id);
create index products_country_code_idx on public.products (country_code);
create index products_active_newest_idx
  on public.products (country_code, created_at desc, id desc) where status = 'active';
create index products_active_price_idx
  on public.products (country_code, min_price, id) where status = 'active';
create index products_search_vector_idx on public.products using gin (search_vector);
create index products_title_trgm_idx
  on public.products using gin (title extensions.gin_trgm_ops);

create trigger products_set_updated_at
  before update on public.products
  for each row execute function public.set_updated_at();

create table public.product_images (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products (id) on delete cascade,
  storage_path text not null check (length(storage_path) <= 500),
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  unique (product_id, sort_order)
);

-- Every product has at least one variant, so a simple product has one default
-- variant. Cart, stock and order logic then work the same for all products.
create table public.product_variants (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products (id) on delete cascade,
  sku text check (length(sku) <= 60),
  name text not null default 'Default' check (length(trim(name)) between 1 and 80),
  options jsonb not null default '{}' check (jsonb_typeof(options) = 'object'),
  price numeric(12, 2) not null check (price > 0),
  compare_at_price numeric(12, 2),
  stock integer not null default 0 check (stock >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (product_id, options),
  -- A discount must really be lower than the original price.
  check (compare_at_price is null or compare_at_price > price)
);

create trigger product_variants_set_updated_at
  before update on public.product_variants
  for each row execute function public.set_updated_at();

-- Copies the cheapest active variant and the total stock onto the product, so
-- lists can sort and filter without reading every variant.
create function public.refresh_product_summary()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_product_id uuid := case when tg_op = 'DELETE' then old.product_id else new.product_id end;
begin
  update public.products p
  set
    min_price = summary.min_price,
    compare_at_price = summary.compare_at_price,
    total_stock = summary.total_stock
  from (
    select
      (
        select v.price from public.product_variants v
        where v.product_id = v_product_id and v.is_active
        order by v.price, v.id limit 1
      ) as min_price,
      (
        select v.compare_at_price from public.product_variants v
        where v.product_id = v_product_id and v.is_active
        order by v.price, v.id limit 1
      ) as compare_at_price,
      coalesce((
        select sum(v.stock)::integer from public.product_variants v
        where v.product_id = v_product_id and v.is_active
      ), 0) as total_stock
  ) as summary
  where p.id = v_product_id;
  return null;
end;
$$;

revoke all on function public.refresh_product_summary() from public, anon, authenticated;

create trigger product_variants_refresh_summary
  after insert or update or delete on public.product_variants
  for each row execute function public.refresh_product_summary();

create table public.wishlist_items (
  user_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  product_id uuid not null references public.products (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, product_id)
);

create index wishlist_items_product_id_idx on public.wishlist_items (product_id);
create index wishlist_items_user_newest_idx
  on public.wishlist_items (user_id, created_at desc, product_id desc);

-- The shop owned by the current user. Security definer, because seller_id is
-- deliberately not readable by clients.
create function public.current_shop_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select id from public.shops where seller_id = (select auth.uid());
$$;

revoke all on function public.current_shop_id() from public, anon;
grant execute on function public.current_shop_id() to authenticated;

-- Row Level Security.
alter table public.seller_profiles enable row level security;
alter table public.shops enable row level security;
alter table public.categories enable row level security;
alter table public.products enable row level security;
alter table public.product_images enable row level security;
alter table public.product_variants enable row level security;
alter table public.wishlist_items enable row level security;

revoke all on
  public.seller_profiles, public.shops, public.categories, public.products,
  public.product_images, public.product_variants, public.wishlist_items
from anon, authenticated;

grant select on public.seller_profiles to authenticated;

-- Column lists keep seller_id and internal fields out of the public API.
grant select (
  id, name, slug, logo_path, banner_path, description, region_id, delivery_fee,
  is_active, rating_avg, rating_count, created_at
) on public.shops to anon, authenticated;

grant select (id, parent_id, name, slug, icon, sort_order, is_active)
  on public.categories to anon, authenticated;

grant select (
  id, shop_id, category_id, title, description, condition, status, country_code,
  min_price, compare_at_price, total_stock, rating_avg, rating_count, sold_count,
  search_vector, created_at, updated_at
) on public.products to anon, authenticated;

grant select (id, product_id, storage_path, sort_order)
  on public.product_images to anon, authenticated;

grant select (
  id, product_id, name, options, price, compare_at_price, stock, is_active
) on public.product_variants to anon, authenticated;

grant select, delete on public.wishlist_items to authenticated;
grant insert (product_id) on public.wishlist_items to authenticated;

create policy "Sellers can read their own seller profile"
  on public.seller_profiles for select to authenticated
  using (user_id = (select auth.uid()));

create policy "Admins can read seller profiles"
  on public.seller_profiles for select to authenticated
  using ((select public.is_admin()));

create policy "Anyone can read active shops"
  on public.shops for select to anon, authenticated
  using (is_active);

create policy "Sellers can read their own shop"
  on public.shops for select to authenticated
  using (id = (select public.current_shop_id()));

create policy "Admins can read all shops"
  on public.shops for select to authenticated
  using ((select public.is_admin()));

create policy "Anyone can read active categories"
  on public.categories for select to anon, authenticated
  using (is_active);

create policy "Admins can read all categories"
  on public.categories for select to authenticated
  using ((select public.is_admin()));

-- The shop subquery obeys the shops policies, so a hidden shop hides its products.
create policy "Anyone can read active products of active shops"
  on public.products for select to anon, authenticated
  using (
    status = 'active'
    and exists (select 1 from public.shops s where s.id = shop_id and s.is_active)
  );

create policy "Sellers can read their own products"
  on public.products for select to authenticated
  using (shop_id = (select public.current_shop_id()));

create policy "Admins can read all products"
  on public.products for select to authenticated
  using ((select public.is_admin()));

-- The product subquery obeys the products policies, so these follow the product.
create policy "Anyone can read images of readable products"
  on public.product_images for select to anon, authenticated
  using (exists (select 1 from public.products p where p.id = product_id));

create policy "Anyone can read active variants of readable products"
  on public.product_variants for select to anon, authenticated
  using (is_active and exists (select 1 from public.products p where p.id = product_id));

create policy "Sellers can read all variants of their own products"
  on public.product_variants for select to authenticated
  using (
    exists (
      select 1 from public.products p
      where p.id = product_id and p.shop_id = (select public.current_shop_id())
    )
  );

create policy "Admins can read all variants"
  on public.product_variants for select to authenticated
  using ((select public.is_admin()));

create policy "Users can read their own wishlist"
  on public.wishlist_items for select to authenticated
  using (user_id = (select auth.uid()));

create policy "Users can save live products to their own wishlist"
  on public.wishlist_items for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1 from public.products p where p.id = product_id and p.status = 'active'
    )
  );

create policy "Users can remove from their own wishlist"
  on public.wishlist_items for delete to authenticated
  using (user_id = (select auth.uid()));

-- Turns typed text into a prefix search, so "head" finds "headphones". Characters
-- with a special meaning in a search query are removed first.
create function public.product_search_query(p_text text)
returns tsquery
language sql
immutable
set search_path = ''
as $$
  select to_tsquery(
    'simple'::regconfig,
    string_agg(quote_literal(word) || ':*', ' & ')
  )
  from regexp_split_to_table(
    regexp_replace(left(coalesce(p_text, ''), 100), '[''\\:&|!()<>*]', ' ', 'g'),
    '\s+'
  ) as word
  where word <> '';
$$;

revoke all on function public.product_search_query(text) from public;
grant execute on function public.product_search_query(text) to anon, authenticated;

-- Marketplace search with filters and cursor paging. Runs with the caller's
-- rights, so RLS still applies. The status and shop checks are repeated because
-- sellers and admins can read more than the public marketplace shows.
--
-- Every sort is a single descending number, returned as text so the cursor
-- doesn't lose precision. To get the next page, send back the last row's
-- cursor_key and id.
create function public.search_products(
  p_query text default null,
  p_category_id uuid default null,
  p_shop_id uuid default null,
  p_min_price numeric default null,
  p_max_price numeric default null,
  p_condition public.product_condition default null,
  p_min_rating numeric default null,
  p_in_stock_only boolean default false,
  p_sort public.product_sort default 'newest',
  p_country_code char(2) default 'BD',
  p_cursor_key text default null,
  p_cursor_id uuid default null,
  p_limit integer default 20
)
returns table (
  id uuid,
  title text,
  shop_id uuid,
  shop_name text,
  image_path text,
  price numeric,
  compare_at_price numeric,
  rating_avg numeric,
  rating_count integer,
  sold_count integer,
  total_stock integer,
  cursor_key text
)
language sql
stable
set search_path = ''
as $$
  with recursive input as (
    select
      nullif(btrim(left(coalesce(p_query, ''), 100)), '') as q,
      public.product_search_query(p_query) as tsq
  ),
  category_tree as (
    select c.id from public.categories c where c.id = p_category_id
    union all
    select child.id
    from public.categories child
    join category_tree parent on child.parent_id = parent.id
  ),
  matches as (
    select
      p.*,
      s.name as shop_name,
      case
        when p_sort = 'price_low' then -p.min_price
        when p_sort = 'price_high' then p.min_price
        when p_sort = 'rating' then p.rating_avg
        when p_sort = 'popular' then p.sold_count::numeric
        when p_sort = 'relevance' and i.tsq is not null then round((
          pg_catalog.ts_rank(p.search_vector, i.tsq)
          + extensions.word_similarity(i.q, p.title)
        )::numeric, 6)
        else extract(epoch from p.created_at)
      end as sort_key
    from public.products p
    join public.shops s on s.id = p.shop_id and s.is_active
    join public.categories c on c.id = p.category_id and c.is_active
    cross join input i
    where p.status = 'active'
      and p.country_code = p_country_code
      and p.min_price is not null
      and (p_category_id is null or p.category_id in (select t.id from category_tree t))
      and (p_shop_id is null or p.shop_id = p_shop_id)
      and (p_min_price is null or p.min_price >= p_min_price)
      and (p_max_price is null or p.min_price <= p_max_price)
      and (p_condition is null or p.condition = p_condition)
      and (p_min_rating is null or p.rating_avg >= p_min_rating)
      and (not coalesce(p_in_stock_only, false) or p.total_stock > 0)
      and (
        i.tsq is null
        or p.search_vector @@ i.tsq
        or i.q operator(extensions.<%) p.title
      )
  )
  select
    m.id,
    m.title,
    m.shop_id,
    m.shop_name,
    (
      select pi.storage_path from public.product_images pi
      where pi.product_id = m.id
      order by pi.sort_order
      limit 1
    ),
    m.min_price,
    m.compare_at_price,
    m.rating_avg,
    m.rating_count,
    m.sold_count,
    m.total_stock,
    m.sort_key::text
  from matches m
  where p_cursor_id is null
    or (m.sort_key, m.id) < (p_cursor_key::numeric, p_cursor_id)
  order by m.sort_key desc, m.id desc
  limit least(greatest(coalesce(p_limit, 20), 1), 60);
$$;

revoke all on function public.search_products(
  text, uuid, uuid, numeric, numeric, public.product_condition, numeric, boolean,
  public.product_sort, char, text, uuid, integer
) from public;
grant execute on function public.search_products(
  text, uuid, uuid, numeric, numeric, public.product_condition, numeric, boolean,
  public.product_sort, char, text, uuid, integer
) to anon, authenticated;

-- Active categories with how many live products each holds, including those in
-- its subcategories.
create function public.get_categories_with_counts(p_country_code char(2) default 'BD')
returns table (
  id uuid,
  parent_id uuid,
  name text,
  slug text,
  icon text,
  sort_order integer,
  product_count integer
)
language sql
stable
set search_path = ''
as $$
  with recursive tree as (
    select c.id as root_id, c.id as category_id
    from public.categories c
    where c.is_active
    union all
    select tree.root_id, child.id
    from public.categories child
    join tree on child.parent_id = tree.category_id
    where child.is_active
  )
  select
    c.id, c.parent_id, c.name, c.slug, c.icon, c.sort_order,
    count(p.id)::integer
  from public.categories c
  left join tree on tree.root_id = c.id
  left join public.products p
    on p.category_id = tree.category_id
    and p.status = 'active'
    and p.country_code = p_country_code
    and p.min_price is not null
    and exists (select 1 from public.shops s where s.id = p.shop_id and s.is_active)
  where c.is_active
  group by c.id
  order by c.sort_order, c.name;
$$;

revoke all on function public.get_categories_with_counts(char) from public;
grant execute on function public.get_categories_with_counts(char) to anon, authenticated;

-- The current user's saved products, newest first. Products that are no longer
-- live are skipped, and come back if the seller relists them.
create function public.get_wishlist(
  p_cursor_key text default null,
  p_cursor_id uuid default null,
  p_limit integer default 20
)
returns table (
  id uuid,
  title text,
  shop_id uuid,
  shop_name text,
  image_path text,
  price numeric,
  compare_at_price numeric,
  rating_avg numeric,
  rating_count integer,
  sold_count integer,
  total_stock integer,
  cursor_key text
)
language sql
stable
set search_path = ''
as $$
  select
    p.id,
    p.title,
    p.shop_id,
    s.name,
    (
      select pi.storage_path from public.product_images pi
      where pi.product_id = p.id
      order by pi.sort_order
      limit 1
    ),
    p.min_price,
    p.compare_at_price,
    p.rating_avg,
    p.rating_count,
    p.sold_count,
    p.total_stock,
    extract(epoch from w.created_at)::text
  from public.wishlist_items w
  join public.products p on p.id = w.product_id and p.status = 'active'
  join public.shops s on s.id = p.shop_id and s.is_active
  where w.user_id = (select auth.uid())
    and (
      p_cursor_id is null
      or (extract(epoch from w.created_at), p.id) < (p_cursor_key::numeric, p_cursor_id)
    )
  order by w.created_at desc, p.id desc
  limit least(greatest(coalesce(p_limit, 20), 1), 60);
$$;

revoke all on function public.get_wishlist(text, uuid, integer) from public, anon;
grant execute on function public.get_wishlist(text, uuid, integer) to authenticated;

-- Listing photos are public to read. Upload policies are added in Step 3, so
-- until then no client can write to these buckets.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('product-images', 'product-images', true, 5242880, array['image/jpeg', 'image/png']),
  ('shop-assets', 'shop-assets', true, 5242880, array['image/jpeg', 'image/png'])
on conflict (id) do nothing;
