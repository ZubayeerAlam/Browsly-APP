-- Foundation: extensions, shared helpers, admin check, location and settings.

create extension if not exists pg_trgm with schema extensions;

-- Keeps updated_at correct on any table that uses this trigger.
create function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- Admins live in their own table so users can never make themselves admin.
create table public.admin_users (
  user_id uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.admin_users enable row level security;
revoke all on public.admin_users from anon, authenticated;

create function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.admin_users where user_id = (select auth.uid())
  );
$$;

revoke all on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated;

-- Countries. Release 1 activates only Bangladesh.
create table public.countries (
  code char(2) primary key check (code = upper(code)),
  name text not null unique check (length(trim(name)) > 0),
  currency_code char(3) not null check (currency_code = upper(currency_code)),
  is_active boolean not null default false,
  created_at timestamptz not null default now()
);

create type public.region_level as enum ('division', 'district', 'area');

create table public.regions (
  id uuid primary key default gen_random_uuid(),
  country_code char(2) not null references public.countries (code),
  parent_id uuid references public.regions (id),
  level public.region_level not null,
  name text not null check (length(trim(name)) > 0),
  created_at timestamptz not null default now(),
  -- Only divisions sit at the top of the tree.
  constraint regions_parent_matches_level
    check ((level = 'division') = (parent_id is null)),
  constraint regions_unique_name
    unique nulls not distinct (country_code, parent_id, level, name)
);

create index regions_parent_id_idx on public.regions (parent_id);

-- One row of marketplace rules per country.
create table public.platform_settings (
  country_code char(2) primary key references public.countries (code),
  commission_rate numeric(5, 2) not null default 1.00
    check (commission_rate between 0 and 100),
  commission_block_limit numeric(12, 2) not null
    check (commission_block_limit >= 0),
  max_cod_order_value numeric(12, 2) not null
    check (max_cod_order_value > 0),
  updated_at timestamptz not null default now()
);

create trigger platform_settings_set_updated_at
  before update on public.platform_settings
  for each row execute function public.set_updated_at();

-- Row Level Security: anyone can read; only admins can change settings.
alter table public.countries enable row level security;
alter table public.regions enable row level security;
alter table public.platform_settings enable row level security;

revoke all on public.countries, public.regions, public.platform_settings
  from anon, authenticated;
grant select on public.countries, public.regions, public.platform_settings
  to anon, authenticated;
grant update on public.platform_settings to authenticated;

create policy "Anyone can read countries"
  on public.countries for select to anon, authenticated
  using (true);

create policy "Anyone can read regions"
  on public.regions for select to anon, authenticated
  using (true);

create policy "Anyone can read platform settings"
  on public.platform_settings for select to anon, authenticated
  using (true);

create policy "Admins can update platform settings"
  on public.platform_settings for update to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));
