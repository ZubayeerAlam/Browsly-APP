-- Engagement: notifications, chat with seller, reviews, reports and statistics.
--
-- As everywhere else, clients only read here, and every write goes through a
-- function that checks who is asking.

create type public.notification_type as enum (
  'new_order', 'order_update', 'order_cancelled', 'chat_message',
  'listing_live', 'listing_rejected', 'commission_payment'
);
create type public.device_platform as enum ('android', 'ios');
create type public.review_status as enum ('visible', 'hidden');
create type public.report_target as enum ('product', 'shop', 'review', 'message');
create type public.report_reason as enum ('prohibited', 'fake', 'offensive', 'spam', 'other');
create type public.report_status as enum ('open', 'resolved', 'dismissed');
create type public.analytics_event_type as enum ('view', 'click', 'cart_add');

-- ---------------------------------------------------------------- Notifications

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  type public.notification_type not null,
  title text not null check (length(title) <= 150),
  body text not null default '' check (length(body) <= 300),
  -- IDs the app needs to open the right screen. Never personal details.
  data jsonb not null default '{}' check (jsonb_typeof(data) = 'object'),
  read_at timestamptz,
  created_at timestamptz not null default clock_timestamp()
);

create index notifications_user_newest_idx
  on public.notifications (user_id, created_at desc, id desc);
create index notifications_user_unread_idx
  on public.notifications (user_id) where read_at is null;
-- One unread row per chat, so a busy chat doesn't flood anyone.
create unique index notifications_one_unread_per_chat_idx
  on public.notifications (user_id, (data ->> 'conversation_id'))
  where type = 'chat_message' and read_at is null;

create table public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  token text not null unique check (length(token) between 1 and 4096),
  platform public.device_platform not null,
  last_seen_at timestamptz not null default now()
);

create index device_tokens_user_id_idx on public.device_tokens (user_id);

alter table public.notifications enable row level security;
alter table public.device_tokens enable row level security;

revoke all on public.notifications, public.device_tokens from anon, authenticated;
grant select on public.notifications to authenticated;

create policy "Users can read their own notifications"
  on public.notifications for select to authenticated
  using (user_id = (select auth.uid()));

-- Internal. A chat updates its unread row rather than adding another.
create function public.notify(
  p_user_id uuid,
  p_type public.notification_type,
  p_title text,
  p_body text,
  p_data jsonb default '{}'
)
returns void
language plpgsql
set search_path = ''
as $$
begin
  if p_user_id is null then
    return;
  end if;

  if p_type = 'chat_message' then
    insert into public.notifications (user_id, type, title, body, data)
    values (p_user_id, p_type, left(p_title, 150), left(p_body, 300), p_data)
    on conflict (user_id, (data ->> 'conversation_id'))
      where type = 'chat_message' and read_at is null
    do update set
      title = excluded.title,
      body = excluded.body,
      created_at = clock_timestamp();
  else
    insert into public.notifications (user_id, type, title, body, data)
    values (p_user_id, p_type, left(p_title, 150), left(p_body, 300), p_data);
  end if;
end;
$$;

revoke all on function public.notify(
  uuid, public.notification_type, text, text, jsonb
) from public, anon, authenticated;

-- Asks send-push to deliver a notification. It does nothing until production
-- secrets exist, and a push failing never stops the notification being saved.
create function public.wake_push_worker()
returns trigger
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
  from vault.decrypted_secrets where name = 'push_secret';
  if v_url is null or v_secret is null then
    return null;
  end if;

  perform net.http_post(
    url := v_url || '/functions/v1/send-push',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-push-secret', v_secret
    ),
    body := jsonb_build_object('notification_id', new.id),
    timeout_milliseconds := 10000
  );
  return null;
exception when others then
  raise warning 'Could not wake the push worker: %', sqlerrm;
  return null;
end;
$$;

revoke all on function public.wake_push_worker() from public, anon, authenticated;

create trigger notifications_wake_push
  after insert or update of created_at on public.notifications
  for each row execute function public.wake_push_worker();

-- Tells the right person when an order moves.
create function public.notify_order_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_number text;
  v_order_id uuid := new.order_id;
  v_buyer uuid;
  v_seller uuid;
  v_group jsonb := jsonb_build_object('group_id', new.id);
  v_order jsonb := jsonb_build_object('order_id', new.order_id);
begin
  select o.order_number, o.buyer_id into v_number, v_buyer
  from public.orders o where o.id = v_order_id;
  select s.seller_id into v_seller from public.shops s where s.id = new.shop_id;

  if tg_op = 'INSERT' then
    perform public.notify(
      v_seller, 'new_order', 'New order ' || v_number,
      'Open Sales to start packaging.', v_group
    );
    return null;
  end if;

  if new.status = old.status then
    return null;
  end if;

  case new.status
    when 'packaging' then
      perform public.notify(
        v_buyer, 'order_update', 'Your order is being packed',
        new.shop_name || ' is preparing ' || v_number || '.', v_order
      );
    when 'out_for_delivery' then
      perform public.notify(
        v_buyer, 'order_update', 'Your order is on its way',
        new.shop_name || ' sent out ' || v_number || '. Keep the cash ready.', v_order
      );
    when 'completed' then
      perform public.notify(
        v_buyer, 'order_update', 'Your order is complete',
        'How was it? You can now review your items from ' || new.shop_name || '.', v_order
      );
    when 'delivery_failed' then
      perform public.notify(
        v_buyer, 'order_cancelled', 'Delivery failed',
        new.shop_name || ' could not deliver ' || v_number || '.', v_order
      );
    when 'cancelled' then
      -- Whoever cancelled already knows, so tell the other person.
      if (select auth.uid()) = v_buyer then
        perform public.notify(
          v_seller, 'order_cancelled', 'Order ' || v_number || ' was cancelled',
          'The buyer cancelled, and the stock is back on sale.', v_group
        );
      else
        perform public.notify(
          v_buyer, 'order_cancelled', 'Your order was cancelled',
          new.shop_name || ' cancelled its part of ' || v_number || '.', v_order
        );
      end if;
    else
      null;
  end case;
  return null;
end;
$$;

revoke all on function public.notify_order_change() from public, anon, authenticated;

create trigger seller_order_groups_notify
  after insert or update of status on public.seller_order_groups
  for each row execute function public.notify_order_change();

-- Tells the seller the result of a review. They only ever saw "In review", so
-- nothing is said until the AI passes it or an admin decides.
create function public.notify_listing_result()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_seller uuid;
begin
  if old.status not in ('pending_review', 'admin_review') then
    return null;
  end if;
  select s.seller_id into v_seller from public.shops s where s.id = new.shop_id;

  if new.status = 'active' then
    perform public.notify(
      v_seller, 'listing_live', 'Your listing is live',
      new.title, jsonb_build_object('product_id', new.id)
    );
  elsif new.status = 'rejected' then
    perform public.notify(
      v_seller, 'listing_rejected', 'Your listing needs changes',
      new.title || '. See the reason in My Posts.', jsonb_build_object('product_id', new.id)
    );
  end if;
  return null;
end;
$$;

revoke all on function public.notify_listing_result() from public, anon, authenticated;

create trigger products_notify_result
  after update of status on public.products
  for each row
  when (old.status is distinct from new.status)
  execute function public.notify_listing_result();

create function public.notify_commission_payment()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.type = 'settlement' then
    perform public.notify(
      new.seller_id, 'commission_payment', 'Your commission payment was recorded',
      'We recorded a payment of BDT ' || to_char(-new.amount, 'FM999,999,990.00') || '.'
    );
  end if;
  return null;
end;
$$;

revoke all on function public.notify_commission_payment() from public, anon, authenticated;

create trigger commission_ledger_notify
  after insert on public.commission_ledger
  for each row execute function public.notify_commission_payment();

-- Null marks them all as read. Chat rows clear when the chat is opened instead.
create function public.mark_notifications_read(p_id uuid default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
begin
  if v_user is null then
    raise exception 'NOT_SIGNED_IN';
  end if;

  update public.notifications
  set read_at = clock_timestamp()
  where user_id = v_user
    and read_at is null
    and type <> 'chat_message'
    and (p_id is null or id = p_id);
end;
$$;

revoke all on function public.mark_notifications_read(uuid) from public, anon;
grant execute on function public.mark_notifications_read(uuid) to authenticated;

create function public.register_device_token(
  p_token text,
  p_platform public.device_platform
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
begin
  if v_user is null then
    raise exception 'NOT_SIGNED_IN';
  end if;

  -- A shared phone moves to whoever signed in last.
  insert into public.device_tokens (user_id, token, platform)
  values (v_user, p_token, p_platform)
  on conflict (token) do update set
    user_id = excluded.user_id,
    platform = excluded.platform,
    last_seen_at = now();
end;
$$;

revoke all on function public.register_device_token(text, public.device_platform) from public, anon;
grant execute on function public.register_device_token(text, public.device_platform) to authenticated;

-- Called when signing out, so the old account's alerts stop reaching this phone.
create function public.remove_device_token(p_token text)
returns void
language sql
security definer
set search_path = ''
as $$
  delete from public.device_tokens
  where token = p_token and user_id = (select auth.uid());
$$;

revoke all on function public.remove_device_token(text) from public, anon;
grant execute on function public.remove_device_token(text) to authenticated;

-- ------------------------------------------------------------------------- Chat

create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  buyer_id uuid not null references public.profiles (id) on delete cascade,
  shop_id uuid not null references public.shops (id) on delete cascade,
  product_id uuid references public.products (id) on delete set null,
  last_message_at timestamptz,
  buyer_last_read_at timestamptz,
  seller_last_read_at timestamptz,
  created_at timestamptz not null default now(),
  constraint conversations_one_per_product unique nulls not distinct (buyer_id, shop_id, product_id)
);

create index conversations_buyer_newest_idx
  on public.conversations (buyer_id, last_message_at desc, id desc);
create index conversations_shop_newest_idx
  on public.conversations (shop_id, last_message_at desc, id desc);
create index conversations_product_id_idx on public.conversations (product_id);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  sender_id uuid references public.profiles (id) on delete set null,
  body text not null check (length(btrim(body)) between 1 and 2000),
  created_at timestamptz not null default clock_timestamp()
);

create index messages_conversation_newest_idx
  on public.messages (conversation_id, created_at desc, id desc);
create index messages_sender_newest_idx on public.messages (sender_id, created_at desc);

alter table public.conversations enable row level security;
alter table public.messages enable row level security;

revoke all on public.conversations, public.messages from anon, authenticated;
grant select on public.conversations, public.messages to authenticated;

create policy "Chat members can read a conversation"
  on public.conversations for select to authenticated
  using (buyer_id = (select auth.uid()) or shop_id = (select public.current_shop_id()));

create policy "Chat members can read its messages"
  on public.messages for select to authenticated
  using (exists (select 1 from public.conversations c where c.id = conversation_id));

-- Only for a buyer asking about a live product. Opening it twice gives one chat.
create function public.start_conversation(p_product_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_buyer uuid := public.require_active_buyer();
  v_shop_id uuid;
  v_seller uuid;
  v_id uuid;
begin
  select p.shop_id, s.seller_id into v_shop_id, v_seller
  from public.products p
  join public.shops s on s.id = p.shop_id
  where p.id = p_product_id and p.status = 'active' and p.deleted_at is null and s.is_active;
  if v_shop_id is null then
    raise exception 'PRODUCT_UNAVAILABLE';
  end if;
  if v_seller = v_buyer then
    raise exception 'OWN_PRODUCT';
  end if;

  insert into public.conversations (buyer_id, shop_id, product_id)
  values (v_buyer, v_shop_id, p_product_id)
  on conflict on constraint conversations_one_per_product do nothing
  returning id into v_id;

  if v_id is null then
    select id into v_id from public.conversations
    where buyer_id = v_buyer and shop_id = v_shop_id and product_id = p_product_id;
  end if;
  return v_id;
end;
$$;

revoke all on function public.start_conversation(uuid) from public, anon;
grant execute on function public.start_conversation(uuid) to authenticated;

-- From an order screen, for either the buyer or the seller of that order.
create function public.start_order_conversation(p_group_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := public.require_active_buyer();
  v_buyer uuid;
  v_shop_id uuid;
  v_product_id uuid;
  v_id uuid;
begin
  select o.buyer_id, g.shop_id into v_buyer, v_shop_id
  from public.seller_order_groups g
  join public.orders o on o.id = g.order_id
  where g.id = p_group_id
    and (o.buyer_id = v_user or g.shop_id = public.current_shop_id());
  if v_buyer is null or v_shop_id is null then
    raise exception 'ORDER_NOT_FOUND';
  end if;

  select i.product_id into v_product_id
  from public.order_items i
  where i.group_id = p_group_id
  order by i.created_at, i.id
  limit 1;

  insert into public.conversations (buyer_id, shop_id, product_id)
  values (v_buyer, v_shop_id, v_product_id)
  on conflict on constraint conversations_one_per_product do nothing
  returning id into v_id;

  if v_id is null then
    select c.id into v_id from public.conversations c
    where c.buyer_id = v_buyer and c.shop_id = v_shop_id
      and c.product_id is not distinct from v_product_id;
  end if;
  return v_id;
end;
$$;

revoke all on function public.start_order_conversation(uuid) from public, anon;
grant execute on function public.start_order_conversation(uuid) to authenticated;

create function public.send_message(p_conversation_id uuid, p_body text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_sender uuid := public.require_active_buyer();
  v_body text := btrim(p_body);
  v_conversation public.conversations;
  v_shop_name text;
  v_seller uuid;
  v_buyer_name text;
  v_message public.messages;
begin
  select * into v_conversation
  from public.conversations
  where id = p_conversation_id
    and (buyer_id = v_sender or shop_id = public.current_shop_id())
  for update;
  if v_conversation.id is null then
    raise exception 'CONVERSATION_NOT_FOUND';
  end if;
  if v_body is null or length(v_body) not between 1 and 2000 then
    raise exception 'INVALID_MESSAGE';
  end if;
  if (
    select count(*) from public.messages
    where sender_id = v_sender and created_at > now() - interval '1 minute'
  ) >= 30 then
    raise exception 'MESSAGE_RATE_LIMIT';
  end if;

  insert into public.messages (conversation_id, sender_id, body)
  values (p_conversation_id, v_sender, v_body)
  returning * into v_message;

  update public.conversations
  set
    last_message_at = v_message.created_at,
    buyer_last_read_at = case when buyer_id = v_sender then v_message.created_at else buyer_last_read_at end,
    seller_last_read_at = case when buyer_id = v_sender then seller_last_read_at else v_message.created_at end
  where id = p_conversation_id;

  select s.name, s.seller_id into v_shop_name, v_seller
  from public.shops s where s.id = v_conversation.shop_id;

  if v_sender = v_conversation.buyer_id then
    select nullif(split_part(btrim(full_name), ' ', 1), '') into v_buyer_name
    from public.profiles where id = v_sender;
    perform public.notify(
      v_seller, 'chat_message', coalesce(v_buyer_name, 'A buyer'), left(v_body, 100),
      jsonb_build_object('conversation_id', p_conversation_id)
    );
  else
    perform public.notify(
      v_conversation.buyer_id, 'chat_message', v_shop_name, left(v_body, 100),
      jsonb_build_object('conversation_id', p_conversation_id)
    );
  end if;

  return jsonb_build_object(
    'id', v_message.id,
    'conversation_id', v_message.conversation_id,
    'sender_id', v_message.sender_id,
    'body', v_message.body,
    'created_at', v_message.created_at
  );
end;
$$;

revoke all on function public.send_message(uuid, text) from public, anon;
grant execute on function public.send_message(uuid, text) to authenticated;

create function public.mark_conversation_read(p_conversation_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
begin
  update public.conversations
  set
    buyer_last_read_at = case when buyer_id = v_user then clock_timestamp() else buyer_last_read_at end,
    seller_last_read_at = case when buyer_id = v_user then seller_last_read_at else clock_timestamp() end
  where id = p_conversation_id
    and (buyer_id = v_user or shop_id = public.current_shop_id());
  if not found then
    raise exception 'CONVERSATION_NOT_FOUND';
  end if;

  update public.notifications
  set read_at = clock_timestamp()
  where user_id = v_user
    and type = 'chat_message'
    and read_at is null
    and data ->> 'conversation_id' = p_conversation_id::text;
end;
$$;

revoke all on function public.mark_conversation_read(uuid) from public, anon;
grant execute on function public.mark_conversation_read(uuid) to authenticated;

-- How many messages this user hasn't read in one chat. Internal.
create function public.conversation_unread(p_conversation public.conversations, p_user uuid)
returns bigint
language sql
stable
set search_path = ''
as $$
  select count(*)
  from public.messages m
  where m.conversation_id = (p_conversation).id
    and m.sender_id is distinct from p_user
    and m.created_at > coalesce(
      case when (p_conversation).buyer_id = p_user
        then (p_conversation).buyer_last_read_at
        else (p_conversation).seller_last_read_at
      end,
      '-infinity'::timestamptz
    );
$$;

revoke all on function public.conversation_unread(public.conversations, uuid)
  from public, anon, authenticated;

-- The chat list, with the most recent first. A chat with no messages isn't shown.
-- Sellers see the buyer's first name only.
create function public.get_conversations(
  p_cursor_key text default null,
  p_cursor_id uuid default null,
  p_limit integer default 20
)
returns table (
  id uuid,
  other_name text,
  other_image_path text,
  is_seller boolean,
  product_title text,
  product_image_path text,
  last_message text,
  last_message_at timestamptz,
  unread_count bigint,
  cursor_key text
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    c.id,
    case when c.buyer_id = (select auth.uid())
      then s.name
      else coalesce(nullif(split_part(btrim(p.full_name), ' ', 1), ''), 'Buyer')
    end,
    case when c.buyer_id = (select auth.uid()) then s.logo_path else p.avatar_path end,
    c.buyer_id <> (select auth.uid()),
    pr.title,
    (
      select i.storage_path from public.product_images i
      where i.product_id = c.product_id
      order by i.sort_order
      limit 1
    ),
    (
      select m.body from public.messages m
      where m.conversation_id = c.id
      order by m.created_at desc, m.id desc
      limit 1
    ),
    c.last_message_at,
    public.conversation_unread(c, (select auth.uid())),
    extract(epoch from c.last_message_at)::text
  from public.conversations c
  join public.shops s on s.id = c.shop_id
  join public.profiles p on p.id = c.buyer_id
  left join public.products pr on pr.id = c.product_id
  where (c.buyer_id = (select auth.uid()) or c.shop_id = public.current_shop_id())
    and c.last_message_at is not null
    and (
      p_cursor_id is null
      or (extract(epoch from c.last_message_at), c.id) < (p_cursor_key::numeric, p_cursor_id)
    )
  order by c.last_message_at desc, c.id desc
  limit least(greatest(coalesce(p_limit, 20), 1), 60);
$$;

revoke all on function public.get_conversations(text, uuid, integer) from public, anon;
grant execute on function public.get_conversations(text, uuid, integer) to authenticated;

-- The header of a chat room. Null if the user isn't part of it.
create function public.get_conversation(p_conversation_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', c.id,
    'other_name', case when c.buyer_id = (select auth.uid())
      then s.name
      else coalesce(nullif(split_part(btrim(p.full_name), ' ', 1), ''), 'Buyer')
    end,
    'other_image_path', case when c.buyer_id = (select auth.uid()) then s.logo_path else p.avatar_path end,
    'is_seller', c.buyer_id <> (select auth.uid()),
    'product_id', pr.id,
    'product_title', pr.title,
    'product_price', case when pr.status = 'active' then pr.min_price end,
    'product_image_path', (
      select i.storage_path from public.product_images i
      where i.product_id = c.product_id
      order by i.sort_order
      limit 1
    )
  )
  from public.conversations c
  join public.shops s on s.id = c.shop_id
  join public.profiles p on p.id = c.buyer_id
  left join public.products pr on pr.id = c.product_id
  where c.id = p_conversation_id
    and (c.buyer_id = (select auth.uid()) or c.shop_id = public.current_shop_id());
$$;

revoke all on function public.get_conversation(uuid) from public, anon;
grant execute on function public.get_conversation(uuid) to authenticated;

-- The two badges in the top bar.
create function public.get_unread_counts()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'notifications', (
      select count(*) from public.notifications n
      where n.user_id = (select auth.uid()) and n.read_at is null and n.type <> 'chat_message'
    ),
    'chat', (
      select coalesce(sum(public.conversation_unread(c, (select auth.uid()))), 0)
      from public.conversations c
      where c.buyer_id = (select auth.uid()) or c.shop_id = public.current_shop_id()
    )
  );
$$;

revoke all on function public.get_unread_counts() from public, anon;
grant execute on function public.get_unread_counts() to authenticated;

-- ---------------------------------------------------------------------- Reviews

create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  order_item_id uuid not null unique references public.order_items (id) on delete cascade,
  product_id uuid not null references public.products (id) on delete cascade,
  buyer_id uuid references public.profiles (id) on delete set null,
  rating integer not null check (rating between 1 and 5),
  comment text not null default '' check (length(comment) <= 1000),
  status public.review_status not null default 'visible',
  created_at timestamptz not null default clock_timestamp()
);

create index reviews_product_newest_idx
  on public.reviews (product_id, created_at desc, id desc);
create index reviews_buyer_id_idx on public.reviews (buyer_id);

alter table public.reviews enable row level security;

revoke all on public.reviews from anon, authenticated;
-- buyer_id is left out, so reviews can't be traced back to an account.
grant select (id, order_item_id, product_id, rating, comment, status, created_at)
  on public.reviews to anon, authenticated;

create policy "Anyone can read visible reviews"
  on public.reviews for select to anon, authenticated
  using (status = 'visible');

create policy "Buyers can read their own reviews"
  on public.reviews for select to authenticated
  using (buyer_id = (select auth.uid()));

create policy "Admins can read all reviews"
  on public.reviews for select to authenticated
  using ((select public.is_admin()));

-- Hidden reviews stop counting, so an admin's decision changes the rating too.
create function public.refresh_ratings()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_product_id uuid := case when tg_op = 'DELETE' then old.product_id else new.product_id end;
  v_shop_id uuid;
begin
  select shop_id into v_shop_id from public.products where id = v_product_id;
  -- The whole product is being deleted, so there's nothing to update.
  if v_shop_id is null then
    return null;
  end if;

  update public.products p
  set
    rating_avg = coalesce(r.average, 0),
    rating_count = coalesce(r.total, 0)
  from (
    select round(avg(rating), 2) as average, count(*)::integer as total
    from public.reviews
    where product_id = v_product_id and status = 'visible'
  ) as r
  where p.id = v_product_id;

  update public.shops s
  set
    rating_avg = coalesce(r.average, 0),
    rating_count = coalesce(r.total, 0)
  from (
    select round(avg(v.rating), 2) as average, count(*)::integer as total
    from public.reviews v
    join public.products p on p.id = v.product_id
    where p.shop_id = v_shop_id and v.status = 'visible'
  ) as r
  where s.id = v_shop_id;

  return null;
end;
$$;

revoke all on function public.refresh_ratings() from public, anon, authenticated;

create trigger reviews_refresh_ratings
  after insert or delete or update of status, rating on public.reviews
  for each row execute function public.refresh_ratings();

create function public.submit_review(
  p_order_item_id uuid,
  p_rating integer,
  p_comment text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_buyer uuid := public.require_active_buyer();
  v_product_id uuid;
  v_id uuid;
begin
  if p_rating is null or p_rating not between 1 and 5 then
    raise exception 'INVALID_RATING';
  end if;
  if length(coalesce(p_comment, '')) > 1000 then
    raise exception 'REVIEW_TOO_LONG';
  end if;

  select i.product_id into v_product_id
  from public.order_items i
  join public.seller_order_groups g on g.id = i.group_id
  join public.orders o on o.id = g.order_id
  where i.id = p_order_item_id
    and o.buyer_id = v_buyer
    and g.status = 'completed';
  if v_product_id is null then
    raise exception 'NOT_REVIEWABLE';
  end if;

  insert into public.reviews (order_item_id, product_id, buyer_id, rating, comment)
  values (p_order_item_id, v_product_id, v_buyer, p_rating, coalesce(btrim(p_comment), ''))
  on conflict (order_item_id) do nothing
  returning id into v_id;
  if v_id is null then
    raise exception 'ALREADY_REVIEWED';
  end if;
  return v_id;
end;
$$;

revoke all on function public.submit_review(uuid, integer, text) from public, anon;
grant execute on function public.submit_review(uuid, integer, text) to authenticated;

-- Reviewers appear by first name only.
create function public.get_product_reviews(
  p_product_id uuid,
  p_cursor_key text default null,
  p_cursor_id uuid default null,
  p_limit integer default 20
)
returns table (
  id uuid,
  rating integer,
  comment text,
  reviewer_name text,
  created_at timestamptz,
  cursor_key text
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    r.id,
    r.rating,
    r.comment,
    coalesce(nullif(split_part(btrim(p.full_name), ' ', 1), ''), 'Buyer'),
    r.created_at,
    extract(epoch from r.created_at)::text
  from public.reviews r
  left join public.profiles p on p.id = r.buyer_id
  where r.product_id = p_product_id
    and r.status = 'visible'
    and (
      p_cursor_id is null
      or (extract(epoch from r.created_at), r.id) < (p_cursor_key::numeric, p_cursor_id)
    )
  order by r.created_at desc, r.id desc
  limit least(greatest(coalesce(p_limit, 20), 1), 60);
$$;

revoke all on function public.get_product_reviews(uuid, text, uuid, integer) from public;
grant execute on function public.get_product_reviews(uuid, text, uuid, integer) to anon, authenticated;

-- ---------------------------------------------------------------------- Reports

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid references public.profiles (id) on delete set null,
  target_type public.report_target not null,
  -- No foreign key: the report must outlive what it is about.
  target_id uuid not null,
  reason public.report_reason not null,
  details text not null default '' check (length(details) <= 1000),
  status public.report_status not null default 'open',
  resolved_by uuid references public.profiles (id) on delete set null,
  resolution_note text check (length(resolution_note) <= 1000),
  created_at timestamptz not null default clock_timestamp(),
  resolved_at timestamptz
);

create index reports_open_oldest_idx on public.reports (created_at) where status = 'open';
create index reports_target_idx on public.reports (target_type, target_id);
create index reports_resolved_by_idx on public.reports (resolved_by);
create unique index reports_one_open_per_reporter_idx
  on public.reports (reporter_id, target_type, target_id) where status = 'open';

alter table public.reports enable row level security;

revoke all on public.reports from anon, authenticated;
grant select on public.reports to authenticated;

create policy "Users can read their own reports"
  on public.reports for select to authenticated
  using (reporter_id = (select auth.uid()));

create policy "Admins can read all reports"
  on public.reports for select to authenticated
  using ((select public.is_admin()));

-- Admins can't browse private chats. They see a message only once it's reported.
create policy "Admins can read reported messages"
  on public.messages for select to authenticated
  using (
    (select public.is_admin())
    and exists (
      select 1 from public.reports r
      where r.target_type = 'message' and r.target_id = messages.id
    )
  );

-- Reporting the same thing twice is harmless and not an error.
create function public.submit_report(
  p_target_type public.report_target,
  p_target_id uuid,
  p_reason public.report_reason,
  p_details text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reporter uuid := public.require_active_buyer();
  v_exists boolean;
begin
  v_exists := case p_target_type
    when 'product' then exists (
      select 1 from public.products
      where id = p_target_id and status = 'active' and deleted_at is null
    )
    when 'shop' then exists (select 1 from public.shops where id = p_target_id)
    when 'review' then exists (
      select 1 from public.reviews where id = p_target_id and status = 'visible'
    )
    -- Only someone in a chat can report what was said in it.
    when 'message' then exists (
      select 1 from public.messages m
      join public.conversations c on c.id = m.conversation_id
      where m.id = p_target_id
        and (c.buyer_id = v_reporter or c.shop_id = public.current_shop_id())
    )
  end;
  if not v_exists then
    raise exception 'REPORT_TARGET_NOT_FOUND';
  end if;
  if length(coalesce(p_details, '')) > 1000 then
    raise exception 'REPORT_TOO_LONG';
  end if;
  if (
    select count(*) from public.reports
    where reporter_id = v_reporter and created_at > now() - interval '1 day'
  ) >= 20 then
    raise exception 'REPORT_LIMIT';
  end if;

  insert into public.reports (reporter_id, target_type, target_id, reason, details)
  values (v_reporter, p_target_type, p_target_id, p_reason, coalesce(btrim(p_details), ''))
  on conflict (reporter_id, target_type, target_id) where status = 'open' do nothing;
end;
$$;

revoke all on function public.submit_report(
  public.report_target, uuid, public.report_reason, text
) from public, anon;
grant execute on function public.submit_report(
  public.report_target, uuid, public.report_reason, text
) to authenticated;

-- ------------------------------------------------------------------- Statistics

create table public.analytics_events (
  id bigint generated always as identity primary key,
  event_type public.analytics_event_type not null,
  product_id uuid not null references public.products (id) on delete cascade,
  shop_id uuid not null references public.shops (id) on delete cascade,
  user_id uuid references public.profiles (id) on delete set null,
  session_id uuid not null,
  created_at timestamptz not null default now()
);

create index analytics_events_product_time_idx
  on public.analytics_events (product_id, created_at);
create index analytics_events_shop_time_idx on public.analytics_events (shop_id, created_at);
create index analytics_events_dedupe_idx
  on public.analytics_events (session_id, product_id, event_type, created_at);
create index analytics_events_user_id_idx on public.analytics_events (user_id);

-- Days are Bangladesh days, so "today" matches what sellers see on their phones.
create table public.product_daily_stats (
  product_id uuid not null references public.products (id) on delete cascade,
  day date not null,
  views integer not null default 0,
  clicks integer not null default 0,
  cart_adds integer not null default 0,
  primary key (product_id, day)
);

create index product_daily_stats_day_idx on public.product_daily_stats (day);

alter table public.analytics_events enable row level security;
alter table public.product_daily_stats enable row level security;
revoke all on public.analytics_events, public.product_daily_stats from anon, authenticated;

-- Works for guests too. It skips a seller's own products, and repeats within a
-- few minutes, so refreshing a page can't inflate the numbers.
create function public.track_event(
  p_type public.analytics_event_type,
  p_product_id uuid,
  p_session_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
  v_shop_id uuid;
begin
  if p_session_id is null then
    return;
  end if;

  select p.shop_id into v_shop_id
  from public.products p
  where p.id = p_product_id and p.status = 'active' and p.deleted_at is null;
  if v_shop_id is null or v_shop_id = public.current_shop_id() then
    return;
  end if;

  if exists (
    select 1 from public.analytics_events
    where session_id = p_session_id
      and product_id = p_product_id
      and event_type = p_type
      and created_at > now() - interval '10 minutes'
  ) or (
    select count(*) from public.analytics_events
    where session_id = p_session_id and created_at > now() - interval '1 hour'
  ) >= 300 then
    return;
  end if;

  insert into public.analytics_events (event_type, product_id, shop_id, user_id, session_id)
  values (p_type, p_product_id, v_shop_id, v_user, p_session_id);
end;
$$;

revoke all on function public.track_event(
  public.analytics_event_type, uuid, uuid
) from public;
grant execute on function public.track_event(
  public.analytics_event_type, uuid, uuid
) to anon, authenticated;

-- Nightly: totals up recent finished days, then removes what is no longer needed.
-- Rebuilding the past few days means a missed night corrects itself.
create function public.roll_up_analytics()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_today date := (now() at time zone 'Asia/Dhaka')::date;
begin
  insert into public.product_daily_stats (product_id, day, views, clicks, cart_adds)
  select
    e.product_id,
    (e.created_at at time zone 'Asia/Dhaka')::date,
    count(*) filter (where e.event_type = 'view'),
    count(*) filter (where e.event_type = 'click'),
    count(*) filter (where e.event_type = 'cart_add')
  from public.analytics_events e
  where (e.created_at at time zone 'Asia/Dhaka')::date between v_today - 7 and v_today - 1
  group by 1, 2
  on conflict (product_id, day) do update set
    views = excluded.views,
    clicks = excluded.clicks,
    cart_adds = excluded.cart_adds;

  delete from public.analytics_events where created_at < now() - interval '90 days';
  delete from public.device_tokens where last_seen_at < now() - interval '90 days';
  delete from public.notifications where created_at < now() - interval '180 days';
end;
$$;

revoke all on function public.roll_up_analytics() from public, anon, authenticated;

select cron.schedule('roll-up-analytics', '30 19 * * *', 'select public.roll_up_analytics()');

-- Views, clicks and cart adds per product per day: finished days are read from
-- the totals, and today straight from the events. Internal.
create function public.shop_daily_activity(p_shop_id uuid, p_from date)
returns table (product_id uuid, day date, views bigint, clicks bigint, cart_adds bigint)
language sql
stable
set search_path = ''
as $$
  select s.product_id, s.day, s.views::bigint, s.clicks::bigint, s.cart_adds::bigint
  from public.product_daily_stats s
  join public.products p on p.id = s.product_id
  where p.shop_id = p_shop_id
    and s.day >= p_from
    and s.day < (now() at time zone 'Asia/Dhaka')::date
  union all
  select
    e.product_id,
    (e.created_at at time zone 'Asia/Dhaka')::date,
    count(*) filter (where e.event_type = 'view'),
    count(*) filter (where e.event_type = 'click'),
    count(*) filter (where e.event_type = 'cart_add')
  from public.analytics_events e
  where e.shop_id = p_shop_id
    and e.created_at >= (((now() at time zone 'Asia/Dhaka')::date)::timestamp at time zone 'Asia/Dhaka')
  group by 1, 2;
$$;

revoke all on function public.shop_daily_activity(uuid, date) from public, anon, authenticated;

-- Everything on the Statistics tab for the last p_days days, including today.
-- Sales count on the day they were completed, and exclude delivery fees.
create function public.get_seller_stats(p_days integer default 7)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_shop_id uuid := public.current_shop_id();
  v_days integer := least(greatest(coalesce(p_days, 7), 1), 90);
  v_today date := (now() at time zone 'Asia/Dhaka')::date;
  v_from date := v_today - (v_days - 1);
begin
  if v_shop_id is null then
    return null;
  end if;

  return (
    with activity as (
      select * from public.shop_daily_activity(v_shop_id, v_from)
    ),
    placed as (
      select (g.created_at at time zone 'Asia/Dhaka')::date as day, count(*) as orders
      from public.seller_order_groups g
      where g.shop_id = v_shop_id
        and g.created_at >= (v_from::timestamp at time zone 'Asia/Dhaka')
        and g.status not in ('cancelled', 'delivery_failed')
      group by 1
    ),
    sold as (
      select (h.created_at at time zone 'Asia/Dhaka')::date as day, sum(g.subtotal) as sales
      from public.seller_order_groups g
      join public.order_status_history h on h.group_id = g.id and h.to_status = 'completed'
      where g.shop_id = v_shop_id
        and h.created_at >= (v_from::timestamp at time zone 'Asia/Dhaka')
      group by 1
    ),
    daily as (
      select
        d::date as day,
        coalesce((select sum(a.views) from activity a where a.day = d::date), 0) as views,
        coalesce((select sum(a.clicks) from activity a where a.day = d::date), 0) as clicks,
        coalesce((select sum(a.cart_adds) from activity a where a.day = d::date), 0) as cart_adds,
        coalesce((select p.orders from placed p where p.day = d::date), 0) as orders,
        coalesce((select s.sales from sold s where s.day = d::date), 0) as sales
      from generate_series(v_from, v_today, interval '1 day') as d
    ),
    product_sales as (
      select i.product_id, sum(i.quantity) as units, sum(i.line_total) as sales
      from public.order_items i
      join public.seller_order_groups g on g.id = i.group_id
      join public.order_status_history h on h.group_id = g.id and h.to_status = 'completed'
      where g.shop_id = v_shop_id
        and h.created_at >= (v_from::timestamp at time zone 'Asia/Dhaka')
        and i.product_id is not null
      group by 1
    ),
    product_views as (
      select a.product_id, sum(a.views) as views from activity a group by 1
    ),
    top_products as (
      select
        p.id,
        p.title,
        (
          select i.storage_path from public.product_images i
          where i.product_id = p.id
          order by i.sort_order
          limit 1
        ) as image_path,
        coalesce(v.views, 0) as views,
        coalesce(s.units, 0) as units,
        coalesce(s.sales, 0) as sales
      from public.products p
      left join product_views v on v.product_id = p.id
      left join product_sales s on s.product_id = p.id
      where p.shop_id = v_shop_id
        and p.deleted_at is null
        and (v.views > 0 or s.units > 0)
      order by coalesce(s.sales, 0) desc, coalesce(v.views, 0) desc, p.id
      limit 5
    )
    select jsonb_build_object(
      'views', (select sum(views) from daily),
      'clicks', (select sum(clicks) from daily),
      'cart_adds', (select sum(cart_adds) from daily),
      'orders', (select sum(orders) from daily),
      'sales', (select sum(sales) from daily),
      'daily', (
        select jsonb_agg(
          jsonb_build_object(
            'day', day, 'views', views, 'clicks', clicks,
            'orders', orders, 'sales', sales
          )
          order by day
        )
        from daily
      ),
      'top_products', coalesce(
        (select jsonb_agg(to_jsonb(t)) from top_products t),
        '[]'::jsonb
      )
    )
  );
end;
$$;

revoke all on function public.get_seller_stats(integer) from public, anon;
grant execute on function public.get_seller_stats(integer) to authenticated;

-- The seller's card on the Dashboard. Null if the user has no shop.
create function public.get_seller_dashboard()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_shop_id uuid := public.current_shop_id();
  v_today date := (now() at time zone 'Asia/Dhaka')::date;
  v_start timestamptz := (v_today::timestamp at time zone 'Asia/Dhaka');
begin
  if v_shop_id is null then
    return null;
  end if;

  return jsonb_build_object(
    'views_today', (
      select coalesce(sum(views), 0) from public.shop_daily_activity(v_shop_id, v_today)
    ),
    'clicks_today', (
      select coalesce(sum(clicks), 0) from public.shop_daily_activity(v_shop_id, v_today)
    ),
    'sales_today', (
      select coalesce(sum(g.subtotal), 0)
      from public.seller_order_groups g
      join public.order_status_history h on h.group_id = g.id and h.to_status = 'completed'
      where g.shop_id = v_shop_id and h.created_at >= v_start
    ),
    'new_orders', (
      select count(*) from public.seller_order_groups g
      where g.shop_id = v_shop_id and g.status = 'pending'
    ),
    'rating_avg', (select rating_avg from public.shops where id = v_shop_id),
    'rating_count', (select rating_count from public.shops where id = v_shop_id),
    'low_stock', (
      select count(*) from public.products p
      where p.shop_id = v_shop_id and p.status = 'active' and p.total_stock <= 3
    ),
    'amount_owed', public.seller_commission_balance((select auth.uid()))
  );
end;
$$;

revoke all on function public.get_seller_dashboard() from public, anon;
grant execute on function public.get_seller_dashboard() to authenticated;

-- ---------------------------------------------------------------- Live updates

alter publication supabase_realtime add table public.messages, public.notifications;
