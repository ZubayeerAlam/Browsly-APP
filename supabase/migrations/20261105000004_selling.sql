-- Selling: shop setup, listings, photo uploads and the AI review queue.
--
-- Clients change listings only through the functions here, so a seller can never
-- set a status, or skip review, by writing to a table.

create extension if not exists pg_net;
create extension if not exists pg_cron;

create type public.ai_decision as enum ('approve', 'suspicious', 'reject');
create type public.admin_decision as enum ('approve', 'reject');
create type public.moderation_status as enum ('queued', 'done', 'timed_out', 'superseded');

alter table public.platform_settings
  add column daily_submission_limit integer not null default 20
    check (daily_submission_limit > 0);

-- A deleted listing is kept, because orders and review history point to it.
alter table public.products add column deleted_at timestamptz;

-- search_products reads every product column with the caller's rights.
grant select (deleted_at) on public.products to anon, authenticated;

create table public.moderation_reviews (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products (id) on delete cascade,
  -- What was reviewed. A result for older content is thrown away.
  content_hash text not null,
  status public.moderation_status not null default 'queued',
  attempts integer not null default 0,
  next_attempt_at timestamptz not null default now(),
  last_error text,
  policy_version text,
  provider text,
  model text,
  ai_decision public.ai_decision,
  reason_code text,
  -- Only admins see the AI's reason.
  ai_reason text,
  admin_decision public.admin_decision,
  -- Shown to the seller when an admin rejects.
  admin_reason text,
  decided_by uuid references auth.users (id) on delete set null,
  decided_at timestamptz,
  -- The real clock, so "latest review" is exact even within one transaction.
  created_at timestamptz not null default clock_timestamp()
);

create index moderation_reviews_product_idx
  on public.moderation_reviews (product_id, created_at desc);
create index moderation_reviews_due_idx
  on public.moderation_reviews (next_attempt_at) where status = 'queued';
create index moderation_reviews_decided_by_idx on public.moderation_reviews (decided_by);

alter table public.moderation_reviews enable row level security;
revoke all on public.moderation_reviews from anon, authenticated;
grant select on public.moderation_reviews to authenticated;

create policy "Admins can read product reviews"
  on public.moderation_reviews for select to authenticated
  using ((select public.is_admin()));

-- Whether the current user may sell right now.
create function public.is_active_seller()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.seller_profiles sp
    join public.profiles p on p.id = sp.user_id
    join public.shops s on s.seller_id = sp.user_id
    where sp.user_id = (select auth.uid())
      and sp.status = 'active'
      and p.status = 'active'
      and p.phone_verified_at is not null
      and s.is_active
  );
$$;

revoke all on function public.is_active_seller() from public, anon;
grant execute on function public.is_active_seller() to authenticated;

-- Opens the user's shop. Calling it again returns the shop they already have,
-- so a retry after a lost connection is harmless.
create function public.become_seller(
  p_name text,
  p_description text,
  p_region_id uuid,
  p_delivery_fee numeric,
  p_payout_number text,
  p_accept_terms boolean
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_shop_id uuid;
  v_slug text;
begin
  if v_user_id is null then
    raise exception 'NOT_SIGNED_IN';
  end if;
  if not exists (
    select 1 from public.profiles
    where id = v_user_id and status = 'active' and phone_verified_at is not null
  ) then
    raise exception 'PHONE_NOT_VERIFIED';
  end if;

  select id into v_shop_id from public.shops where seller_id = v_user_id;
  if v_shop_id is not null then
    return v_shop_id;
  end if;

  if not coalesce(p_accept_terms, false) then
    raise exception 'TERMS_NOT_ACCEPTED';
  end if;
  if not exists (
    select 1 from public.regions where id = p_region_id and level = 'district'
  ) then
    raise exception 'INVALID_REGION';
  end if;

  -- A Bangla name has no Latin letters, so the random part keeps slugs valid.
  v_slug := btrim(
    regexp_replace(lower(coalesce(p_name, '')), '[^a-z0-9]+', '-', 'g'), '-'
  );
  v_slug := btrim(left(v_slug, 60), '-');
  v_slug := concat_ws(
    '-', nullif(v_slug, ''), left(replace(gen_random_uuid()::text, '-', ''), 8)
  );

  insert into public.seller_profiles (user_id, payout_number, terms_accepted_at)
  values (v_user_id, nullif(btrim(p_payout_number), ''), now());

  insert into public.shops (seller_id, name, slug, description, region_id, delivery_fee)
  values (
    v_user_id, btrim(p_name), v_slug, coalesce(btrim(p_description), ''),
    p_region_id, p_delivery_fee
  )
  returning id into v_shop_id;

  return v_shop_id;
end;
$$;

revoke all on function public.become_seller(text, text, uuid, numeric, text, boolean)
  from public, anon;
grant execute on function public.become_seller(text, text, uuid, numeric, text, boolean)
  to authenticated;

-- Sellers edit their own shop details, but never is_active or ratings.
grant update (name, description, region_id, delivery_fee, logo_path)
  on public.shops to authenticated;

create policy "Sellers can update their own shop"
  on public.shops for update to authenticated
  using (id = (select public.current_shop_id()) and (select public.is_active_seller()))
  with check (
    id = (select public.current_shop_id())
    and (logo_path is null or logo_path like id::text || '/%')
  );

-- Photos: sellers write only inside their own shop's folder.
create policy "Sellers can add their own shop photos"
  on storage.objects for insert to authenticated
  with check (
    bucket_id in ('product-images', 'shop-assets')
    and (storage.foldername(name))[1] = (select public.current_shop_id())::text
    and (select public.is_active_seller())
  );

create policy "Sellers can read their own shop photo files"
  on storage.objects for select to authenticated
  using (
    bucket_id in ('product-images', 'shop-assets')
    and (storage.foldername(name))[1] = (select public.current_shop_id())::text
  );

create policy "Sellers can delete their own shop photos"
  on storage.objects for delete to authenticated
  using (
    bucket_id in ('product-images', 'shop-assets')
    and (storage.foldername(name))[1] = (select public.current_shop_id())::text
  );

-- A fingerprint of everything the AI reviews. Price and stock are left out, so
-- changing them keeps a product live.
create function public.product_content_hash(p_product_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select md5(jsonb_build_object(
    'title', p.title,
    'description', p.description,
    'category', p.category_id,
    'condition', p.condition,
    'images', (
      select coalesce(jsonb_agg(i.storage_path order by i.sort_order), '[]')
      from public.product_images i where i.product_id = p.id
    ),
    'options', (
      select coalesce(jsonb_agg(v.options order by v.options), '[]')
      from public.product_variants v where v.product_id = p.id and v.is_active
    )
  )::text)
  from public.products p
  where p.id = p_product_id;
$$;

revoke all on function public.product_content_hash(uuid) from public, anon, authenticated;

-- Asks the Edge Function to work through the queue. It can never block a seller:
-- if this fails, the scheduled sweep picks the job up instead.
create function public.wake_moderation_worker()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_url text;
  v_secret text;
begin
  select decrypted_secret into v_url
  from vault.decrypted_secrets where name = 'project_url';
  select decrypted_secret into v_secret
  from vault.decrypted_secrets where name = 'moderation_secret';
  if v_url is null or v_secret is null then
    return;
  end if;

  perform net.http_post(
    url := v_url || '/functions/v1/moderate-product',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-moderation-secret', v_secret
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 120000
  );
exception when others then
  raise warning 'Could not wake the moderation worker: %', sqlerrm;
end;
$$;

revoke all on function public.wake_moderation_worker() from public, anon, authenticated;

-- Puts a product in the queue, replacing any review still waiting.
create function public.queue_product_review(p_product_id uuid, p_shop_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_limit integer;
begin
  select ps.daily_submission_limit into v_limit
  from public.products p
  join public.platform_settings ps on ps.country_code = p.country_code
  where p.id = p_product_id;

  -- Protects the free AI quota from one seller using all of it.
  if (
    select count(*)
    from public.moderation_reviews r
    join public.products p on p.id = r.product_id
    where p.shop_id = p_shop_id and r.created_at > now() - interval '1 day'
  ) >= v_limit then
    raise exception 'SUBMISSION_LIMIT';
  end if;

  update public.moderation_reviews
  set status = 'superseded'
  where product_id = p_product_id and status = 'queued';

  insert into public.moderation_reviews (product_id, content_hash)
  values (p_product_id, public.product_content_hash(p_product_id));

  update public.products set status = 'pending_review' where id = p_product_id;

  perform public.wake_moderation_worker();
end;
$$;

revoke all on function public.queue_product_review(uuid, uuid)
  from public, anon, authenticated;

-- Creates or updates a listing and its photos and variants in one transaction.
-- If a live listing's reviewed content changes, it returns to review. A change
-- to only price or stock keeps it live.
--
-- p_variants: [{"options": {"colour": "Red", "size": "M"}, "price": 500,
--               "compare_at_price": 700, "stock": 3}]
-- Variants that disappear are turned off rather than deleted, so carts and
-- orders that point to them stay valid.
create function public.save_product(
  p_product_id uuid,
  p_title text,
  p_description text,
  p_category_id uuid,
  p_condition public.product_condition,
  p_variants jsonb,
  p_image_paths text[]
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_shop_id uuid := public.current_shop_id();
  v_product_id uuid := p_product_id;
  v_status public.product_status;
  v_old_hash text;
  v_paths text[] := coalesce(p_image_paths, '{}');
begin
  if not public.is_active_seller() then
    raise exception 'NOT_A_SELLER';
  end if;

  if cardinality(v_paths) > 5 then
    raise exception 'TOO_MANY_PHOTOS';
  end if;
  -- A photo must be a real file in this seller's own folder.
  if exists (
    select 1 from unnest(v_paths) as path
    where path not like v_shop_id::text || '/%'
      or not exists (
        select 1 from storage.objects o
        where o.bucket_id = 'product-images' and o.name = path
      )
  ) or (select count(distinct path) from unnest(v_paths) as path) <> cardinality(v_paths) then
    raise exception 'INVALID_PHOTO';
  end if;

  if not exists (
    select 1 from public.categories where id = p_category_id and is_active
  ) then
    raise exception 'INVALID_CATEGORY';
  end if;

  if jsonb_typeof(p_variants) is distinct from 'array'
    or jsonb_array_length(p_variants) not between 1 and 50
    or exists (
      select 1 from jsonb_array_elements(p_variants) as v
      where jsonb_typeof(v -> 'options') is distinct from 'object'
        or (v -> 'options') - 'colour' - 'size' <> '{}'::jsonb
        or exists (
          select 1 from jsonb_each(v -> 'options') as o
          where jsonb_typeof(o.value) <> 'string'
            or length(btrim(o.value #>> '{}')) not between 1 and 30
        )
    )
    or (
      select count(distinct v -> 'options') from jsonb_array_elements(p_variants) as v
    ) <> jsonb_array_length(p_variants)
  then
    raise exception 'INVALID_VARIANTS';
  end if;

  if v_product_id is null then
    insert into public.products (shop_id, category_id, title, description, condition, country_code)
    select v_shop_id, p_category_id, btrim(p_title), coalesce(p_description, ''), p_condition, p.country_code
    from public.profiles p where p.id = (select auth.uid())
    returning id into v_product_id;
  else
    select status into v_status
    from public.products
    where id = v_product_id and shop_id = v_shop_id and deleted_at is null
    for update;
    if v_status is null or v_status = 'removed' then
      raise exception 'PRODUCT_NOT_FOUND';
    end if;
    v_old_hash := public.product_content_hash(v_product_id);

    update public.products
    set
      title = btrim(p_title),
      description = coalesce(p_description, ''),
      category_id = p_category_id,
      condition = p_condition
    where id = v_product_id;
  end if;

  delete from public.product_images where product_id = v_product_id;
  insert into public.product_images (product_id, storage_path, sort_order)
  select v_product_id, path, ordinality - 1
  from unnest(v_paths) with ordinality as t (path, ordinality);

  -- New variants go first, so a live product is never left with none.
  insert into public.product_variants (
    product_id, name, options, price, compare_at_price, stock, is_active
  )
  select
    v_product_id,
    coalesce(
      nullif(concat_ws(' / ', v.options ->> 'colour', v.options ->> 'size'), ''),
      'Default'
    ),
    v.options, v.price, v.compare_at_price, coalesce(v.stock, 0), true
  from jsonb_to_recordset(p_variants) as v (
    options jsonb, price numeric, compare_at_price numeric, stock integer
  )
  on conflict (product_id, options) do update
  set
    name = excluded.name,
    price = excluded.price,
    compare_at_price = excluded.compare_at_price,
    stock = excluded.stock,
    is_active = true;

  update public.product_variants pv
  set is_active = false
  where pv.product_id = v_product_id
    and pv.is_active
    and not exists (
      select 1 from jsonb_array_elements(p_variants) as v
      where v -> 'options' = pv.options
    );

  if v_status in ('active', 'paused', 'pending_review', 'admin_review')
    and public.product_content_hash(v_product_id) is distinct from v_old_hash
  then
    perform public.queue_product_review(v_product_id, v_shop_id);
  end if;

  return v_product_id;
end;
$$;

revoke all on function public.save_product(
  uuid, text, text, uuid, public.product_condition, jsonb, text[]
) from public, anon;
grant execute on function public.save_product(
  uuid, text, text, uuid, public.product_condition, jsonb, text[]
) to authenticated;

-- Sends a draft or rejected listing to the AI.
create function public.submit_product_for_review(p_product_id uuid)
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

revoke all on function public.submit_product_for_review(uuid) from public, anon;
grant execute on function public.submit_product_for_review(uuid) to authenticated;

create function public.set_product_paused(p_product_id uuid, p_paused boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_active_seller() then
    raise exception 'NOT_A_SELLER';
  end if;

  update public.products
  set status = case when p_paused then 'paused' else 'active' end::public.product_status
  where id = p_product_id
    and shop_id = public.current_shop_id()
    and deleted_at is null
    and status = case when p_paused then 'active' else 'paused' end::public.product_status;

  if not found then
    raise exception 'PRODUCT_NOT_PAUSABLE';
  end if;
end;
$$;

revoke all on function public.set_product_paused(uuid, boolean) from public, anon;
grant execute on function public.set_product_paused(uuid, boolean) to authenticated;

-- Hides a listing for good. Returns its photo paths, for the app to remove.
create function public.delete_product(p_product_id uuid)
returns text[]
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_paths text[];
begin
  update public.products
  set status = 'removed', deleted_at = now()
  where id = p_product_id
    and shop_id = public.current_shop_id()
    and deleted_at is null
    and status <> 'removed';
  if not found then
    raise exception 'PRODUCT_NOT_FOUND';
  end if;

  update public.moderation_reviews
  set status = 'superseded'
  where product_id = p_product_id and status = 'queued';

  delete from public.wishlist_items where product_id = p_product_id;

  with removed as (
    delete from public.product_images
    where product_id = p_product_id
    returning storage_path
  )
  select coalesce(array_agg(storage_path), '{}') into v_paths from removed;

  return v_paths;
end;
$$;

revoke all on function public.delete_product(uuid) from public, anon;
grant execute on function public.delete_product(uuid) to authenticated;

-- The seller's own listings for My Posts. p_statuses null means all of them.
-- The AI's reasons stay private. Only an admin's rejection reason is returned.
create function public.get_my_listings(
  p_statuses public.product_status[] default null,
  p_cursor_key text default null,
  p_cursor_id uuid default null,
  p_limit integer default 20
)
returns table (
  id uuid,
  title text,
  status public.product_status,
  image_path text,
  price numeric,
  total_stock integer,
  rejection_reason text,
  cursor_key text
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    p.id,
    p.title,
    p.status,
    (
      select i.storage_path from public.product_images i
      where i.product_id = p.id
      order by i.sort_order
      limit 1
    ),
    p.min_price,
    p.total_stock,
    case when p.status = 'rejected' then (
      select r.admin_reason from public.moderation_reviews r
      where r.product_id = p.id
      order by r.created_at desc
      limit 1
    ) end,
    extract(epoch from p.updated_at)::text
  from public.products p
  where p.shop_id = public.current_shop_id()
    and p.deleted_at is null
    and (p_statuses is null or p.status = any (p_statuses))
    and (
      p_cursor_id is null
      or (extract(epoch from p.updated_at), p.id) < (p_cursor_key::numeric, p_cursor_id)
    )
  order by p.updated_at desc, p.id desc
  limit least(greatest(coalesce(p_limit, 20), 1), 60);
$$;

revoke all on function public.get_my_listings(
  public.product_status[], text, uuid, integer
) from public, anon;
grant execute on function public.get_my_listings(
  public.product_status[], text, uuid, integer
) to authenticated;

-- The final decision on a product in the admin queue.
create function public.admin_decide_product(
  p_product_id uuid,
  p_decision public.admin_decision,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reason text := nullif(btrim(p_reason), '');
begin
  if not public.is_admin() then
    raise exception 'NOT_AN_ADMIN';
  end if;
  if p_decision = 'reject' and v_reason is null then
    raise exception 'REASON_REQUIRED';
  end if;

  update public.products
  set status = case when p_decision = 'approve' then 'active' else 'rejected' end::public.product_status
  where id = p_product_id and status = 'admin_review';
  if not found then
    raise exception 'PRODUCT_NOT_IN_REVIEW';
  end if;

  update public.moderation_reviews
  set
    admin_decision = p_decision,
    admin_reason = v_reason,
    decided_by = (select auth.uid()),
    decided_at = now()
  where id = (
    select id from public.moderation_reviews
    where product_id = p_product_id
    order by created_at desc
    limit 1
  );
end;
$$;

revoke all on function public.admin_decide_product(uuid, public.admin_decision, text)
  from public, anon;
grant execute on function public.admin_decide_product(uuid, public.admin_decision, text)
  to authenticated;

-- The next three are for the moderate-product Edge Function only.

-- Hands out due jobs with only the listing itself: never any seller details.
-- The delay set here means a crashed worker's job is simply tried again later.
create function public.claim_moderation_jobs(p_limit integer default 5)
returns table (
  review_id uuid,
  content_hash text,
  title text,
  description text,
  category_name text,
  condition public.product_condition,
  price numeric,
  options jsonb,
  image_paths text[]
)
language sql
security definer
set search_path = ''
as $$
  with due as (
    select r.id
    from public.moderation_reviews r
    where r.status = 'queued' and r.next_attempt_at <= now()
    order by r.next_attempt_at
    limit least(greatest(coalesce(p_limit, 5), 1), 20)
    for update skip locked
  ),
  claimed as (
    update public.moderation_reviews r
    set attempts = r.attempts + 1, next_attempt_at = now() + interval '10 minutes'
    from due
    where r.id = due.id
    returning r.id, r.product_id, r.content_hash
  )
  select
    c.id,
    c.content_hash,
    p.title,
    p.description,
    cat.name,
    p.condition,
    p.min_price,
    (
      select coalesce(jsonb_agg(v.options), '[]')
      from public.product_variants v
      where v.product_id = p.id and v.is_active
    ),
    (
      select coalesce(array_agg(i.storage_path order by i.sort_order), '{}')
      from public.product_images i
      where i.product_id = p.id
    )
  from claimed c
  join public.products p on p.id = c.product_id
  join public.categories cat on cat.id = p.category_id;
$$;

revoke all on function public.claim_moderation_jobs(integer) from public, anon, authenticated;
grant execute on function public.claim_moderation_jobs(integer) to service_role;

-- Applies the AI's decision. Only "approve" can make a product live, and a
-- result for content that has since changed is thrown away.
create function public.apply_moderation_result(
  p_review_id uuid,
  p_content_hash text,
  p_provider text,
  p_model text,
  p_policy_version text,
  p_decision public.ai_decision,
  p_reason_code text,
  p_reason text
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_product_id uuid;
begin
  select r.product_id into v_product_id
  from public.moderation_reviews r
  where r.id = p_review_id and r.status = 'queued' and r.content_hash = p_content_hash
  for update;
  if v_product_id is null then
    return 'discarded';
  end if;

  perform 1 from public.products where id = v_product_id for update;

  if public.product_content_hash(v_product_id) is distinct from p_content_hash
    or not exists (
      select 1 from public.products where id = v_product_id and status = 'pending_review'
    )
  then
    update public.moderation_reviews set status = 'superseded' where id = p_review_id;
    return 'discarded';
  end if;

  update public.moderation_reviews
  set
    status = 'done',
    provider = p_provider,
    model = p_model,
    policy_version = p_policy_version,
    ai_decision = p_decision,
    reason_code = p_reason_code,
    ai_reason = left(p_reason, 1000),
    last_error = null
  where id = p_review_id;

  update public.products
  set status = case when p_decision = 'approve' then 'active' else 'admin_review' end::public.product_status
  where id = v_product_id;

  return 'applied';
end;
$$;

revoke all on function public.apply_moderation_result(
  uuid, text, text, text, text, public.ai_decision, text, text
) from public, anon, authenticated;
grant execute on function public.apply_moderation_result(
  uuid, text, text, text, text, public.ai_decision, text, text
) to service_role;

-- Leaves the product in review, and tries again later with growing delays.
create function public.record_moderation_failure(p_review_id uuid, p_error text)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.moderation_reviews
  set
    last_error = left(p_error, 500),
    next_attempt_at = now() + least(
      interval '5 minutes' * power(2, greatest(attempts - 1, 0)),
      interval '6 hours'
    )
  where id = p_review_id and status = 'queued';
$$;

revoke all on function public.record_moderation_failure(uuid, text)
  from public, anon, authenticated;
grant execute on function public.record_moderation_failure(uuid, text) to service_role;

-- Runs on a schedule. After 24 hours with no AI result, a person decides. A
-- product is never published just because the AI was unavailable.
create function public.run_moderation_sweep()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  with expired as (
    update public.moderation_reviews r
    set status = 'timed_out', ai_reason = 'AI unavailable', reason_code = 'ai_unavailable'
    where r.status = 'queued' and r.created_at < now() - interval '24 hours'
    returning r.product_id
  )
  update public.products p
  set status = 'admin_review'
  from expired e
  where p.id = e.product_id and p.status = 'pending_review';

  if exists (
    select 1 from public.moderation_reviews
    where status = 'queued' and next_attempt_at <= now()
  ) then
    perform public.wake_moderation_worker();
  end if;
end;
$$;

revoke all on function public.run_moderation_sweep() from public, anon, authenticated;

select cron.schedule(
  'moderation-sweep',
  '*/5 * * * *',
  'select public.run_moderation_sweep()'
);
