-- Accounts: profiles, addresses and avatar storage.

create type public.profile_status as enum ('active', 'suspended');

-- One profile per sign-in account. The same profile can both buy and sell.
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null default '' check (length(full_name) <= 100),
  avatar_path text check (length(avatar_path) <= 500),
  -- Copied from auth.users by triggers, so users cannot fake a verified phone.
  phone text unique,
  phone_verified_at timestamptz,
  country_code char(2) not null default 'BD' references public.countries (code),
  status public.profile_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- auth.users stores phones without the leading plus.
create function public.normalize_auth_phone(raw_phone text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when raw_phone is null or raw_phone = '' then null
    else '+' || ltrim(raw_phone, '+')
  end;
$$;

revoke all on function public.normalize_auth_phone(text) from public, anon, authenticated;

create function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name, phone, phone_verified_at)
  values (
    new.id,
    left(trim(coalesce(
      new.raw_user_meta_data ->> 'full_name',
      new.raw_user_meta_data ->> 'name',
      ''
    )), 100),
    public.normalize_auth_phone(new.phone),
    new.phone_confirmed_at
  );
  return new;
end;
$$;

revoke all on function public.handle_new_auth_user() from public, anon, authenticated;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_auth_user();

-- Only a confirmed phone reaches the profile.
create function public.handle_auth_user_phone_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.profiles
  set
    phone = case
      when new.phone_confirmed_at is null then null
      else public.normalize_auth_phone(new.phone)
    end,
    phone_verified_at = new.phone_confirmed_at
  where id = new.id;
  return new;
end;
$$;

revoke all on function public.handle_auth_user_phone_change() from public, anon, authenticated;

create trigger on_auth_user_phone_changed
  after update of phone, phone_confirmed_at on auth.users
  for each row
  when (
    old.phone is distinct from new.phone
    or old.phone_confirmed_at is distinct from new.phone_confirmed_at
  )
  execute function public.handle_auth_user_phone_change();

alter table public.profiles enable row level security;

revoke all on public.profiles from anon, authenticated;
grant select on public.profiles to authenticated;
-- Column grants stop users changing their phone, status or country directly.
grant update (full_name, avatar_path) on public.profiles to authenticated;

create policy "Users can read their own profile"
  on public.profiles for select to authenticated
  using (id = (select auth.uid()));

create policy "Admins can read all profiles"
  on public.profiles for select to authenticated
  using ((select public.is_admin()));

create policy "Users can update their own profile"
  on public.profiles for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- Delivery addresses.
create table public.addresses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid()
    references public.profiles (id) on delete cascade,
  recipient_name text not null
    check (length(trim(recipient_name)) between 1 and 100),
  phone text not null check (phone ~ '^\+8801[3-9][0-9]{8}$'),
  region_id uuid not null references public.regions (id),
  line1 text not null check (length(trim(line1)) between 1 and 300),
  postal_code text check (postal_code ~ '^[0-9]{4}$'),
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index addresses_user_id_idx on public.addresses (user_id);
create index addresses_region_id_idx on public.addresses (region_id);
create unique index addresses_one_default_per_user_idx
  on public.addresses (user_id) where is_default;

create trigger addresses_set_updated_at
  before update on public.addresses
  for each row execute function public.set_updated_at();

-- Addresses must point to a district or area, and the first one is the default.
create function public.prepare_address()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1 from public.regions
    where id = new.region_id and level in ('district', 'area')
  ) then
    raise exception 'Choose a district or area' using errcode = '23514';
  end if;

  if tg_op = 'INSERT' then
    new.is_default := not exists (
      select 1 from public.addresses where user_id = new.user_id
    );
  end if;

  return new;
end;
$$;

revoke all on function public.prepare_address() from public, anon, authenticated;

create trigger addresses_prepare
  before insert or update of region_id on public.addresses
  for each row execute function public.prepare_address();

-- When the default address is deleted, the newest remaining one takes over.
create function public.promote_default_address()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.is_default then
    update public.addresses
    set is_default = true
    where id = (
      select id from public.addresses
      where user_id = old.user_id
      order by created_at desc, id
      limit 1
    );
  end if;
  return old;
end;
$$;

revoke all on function public.promote_default_address() from public, anon, authenticated;

create trigger addresses_promote_default
  after delete on public.addresses
  for each row execute function public.promote_default_address();

create function public.set_default_address(p_address_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
begin
  if v_user_id is null then
    raise exception 'NOT_SIGNED_IN' using errcode = 'P0001';
  end if;

  if not exists (
    select 1 from public.addresses
    where id = p_address_id and user_id = v_user_id
  ) then
    raise exception 'ADDRESS_NOT_FOUND' using errcode = 'P0001';
  end if;

  update public.addresses
  set is_default = false
  where user_id = v_user_id and is_default and id <> p_address_id;

  update public.addresses
  set is_default = true
  where id = p_address_id;
end;
$$;

revoke all on function public.set_default_address(uuid) from public, anon;
grant execute on function public.set_default_address(uuid) to authenticated;

alter table public.addresses enable row level security;

revoke all on public.addresses from anon, authenticated;
grant select, delete on public.addresses to authenticated;
-- is_default and user_id are left out, so only the server can set them.
grant insert (recipient_name, phone, region_id, line1, postal_code)
  on public.addresses to authenticated;
grant update (recipient_name, phone, region_id, line1, postal_code)
  on public.addresses to authenticated;

create policy "Users can read their own addresses"
  on public.addresses for select to authenticated
  using (user_id = (select auth.uid()));

create policy "Users can add their own addresses"
  on public.addresses for insert to authenticated
  with check (user_id = (select auth.uid()));

create policy "Users can update their own addresses"
  on public.addresses for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy "Users can delete their own addresses"
  on public.addresses for delete to authenticated
  using (user_id = (select auth.uid()));

-- Avatar photos: public to read, and writable only in the user's own folder.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', true, 5242880, array['image/jpeg', 'image/png'])
on conflict (id) do nothing;

create policy "Users can add their own avatar"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "Users can read their own avatar files"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "Users can replace their own avatar"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "Users can delete their own avatar"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
