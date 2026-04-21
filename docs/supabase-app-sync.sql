-- ============================================================
-- homeFlow – App-level sync tables
-- Run this in the Supabase SQL Editor AFTER supabase-all-tables.sql
-- ============================================================
-- These lightweight tables mirror the Flutter app models exactly.
-- Data is stored as JSONB so no field-mapping is needed in Dart.
-- RLS ensures each user can only access their household's rows.
-- ============================================================

-- ============================================================
-- PATCH: Add missing INSERT policies to core tables
-- (the main schema only had SELECT/UPDATE for profiles/households)
-- ============================================================
do $$ begin
  if not exists (
    select 1 from pg_policies where tablename = 'profiles' and policyname = 'profiles_ins'
  ) then
    execute 'create policy "profiles_ins" on public.profiles for insert with check (id = auth.uid())';
  end if;
end $$;

do $$ begin
  if not exists (
    select 1 from pg_policies where tablename = 'households' and policyname = 'hh_ins'
  ) then
    execute 'create policy "hh_ins" on public.households for insert with check (owner_user_id = auth.uid())';
  end if;
end $$;

do $$ begin
  if not exists (
    select 1 from pg_policies where tablename = 'household_members' and policyname = 'hm_self_ins'
  ) then
    execute 'create policy "hm_self_ins" on public.household_members for insert with check (user_id = auth.uid())';
  end if;
end $$;

-- ============================================================
-- APP HOUSEHOLDS TABLE
-- Tracks household records for Supabase-authenticated users.
-- The id is UUID (auto-generated) stored as text in the Flutter app.
-- ============================================================
create table if not exists public.app_households (
  id uuid primary key default gen_random_uuid(),
  household_name text not null,
  invite_code text not null unique,
  owner_user_id uuid references auth.users(id) on delete set null,
  plan_code text not null default 'free' check (plan_code in ('free', 'home_pro')),
  plan_status text not null default 'active' check (plan_status in ('active', 'grace_period', 'expired', 'cancelled')),
  plan_expires_at timestamptz,
  created_at timestamptz default now()
);

alter table public.app_households add column if not exists plan_code text;
alter table public.app_households add column if not exists plan_status text;
alter table public.app_households add column if not exists plan_expires_at timestamptz;

update public.app_households
set plan_code = coalesce(plan_code, 'free'),
    plan_status = coalesce(plan_status, 'active')
where plan_code is null or plan_status is null;

alter table public.app_households alter column plan_code set default 'free';
alter table public.app_households alter column plan_status set default 'active';

create index if not exists idx_app_hh_invite on public.app_households (invite_code);
create index if not exists idx_app_hh_owner  on public.app_households (owner_user_id);

alter table public.app_households enable row level security;

-- ============================================================
-- APP HOUSEHOLD MEMBERS TABLE
-- Tracks which Supabase users belong to which household.
-- household_id is stored as TEXT (UUID string) to match Flutter models.
-- ============================================================
create table if not exists public.app_household_members (
  id uuid primary key default gen_random_uuid(),
  household_id text not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('owner', 'house_manager')),
  created_at timestamptz default now(),
  unique (household_id, user_id)
);

create index if not exists idx_app_hm_hh   on public.app_household_members (household_id);
create index if not exists idx_app_hm_user on public.app_household_members (user_id);

alter table public.app_household_members enable row level security;

-- Helper: returns the current user's household IDs without triggering RLS
-- (SECURITY DEFINER runs as DB owner, breaking the recursion cycle)
drop function if exists public.get_my_household_ids();
create or replace function public.get_my_household_ids()
returns setof text
language sql
stable
security definer
set search_path = public
as $$
  select household_id
  from public.app_household_members
  where user_id = auth.uid();
$$;

drop policy if exists "app_hm_sel" on public.app_household_members;
create policy "app_hm_sel" on public.app_household_members
  for select using (
    user_id = auth.uid()
    or household_id in (select public.get_my_household_ids())
  );

drop policy if exists "app_hm_ins" on public.app_household_members;
create policy "app_hm_ins" on public.app_household_members
  for insert with check (user_id = auth.uid());

drop policy if exists "app_hm_del" on public.app_household_members;
create policy "app_hm_del" on public.app_household_members
  for delete using (user_id = auth.uid());

-- RLS policies for app_households (defined here, after app_household_members exists)
drop policy if exists "app_hh_sel" on public.app_households;
create policy "app_hh_sel" on public.app_households for select
  using (
    owner_user_id = auth.uid()
    or id::text in (select public.get_my_household_ids())
  );

drop policy if exists "app_hh_ins" on public.app_households;
create policy "app_hh_ins" on public.app_households for insert
  with check (owner_user_id = auth.uid());

drop policy if exists "app_hh_upd" on public.app_households;
create policy "app_hh_upd" on public.app_households for update
  using (owner_user_id = auth.uid());

-- ============================================================
-- APP UPGRADE REQUESTS TABLE
-- Stores Home Pro upgrade intents until the external M-Pesa flow
-- is connected and can complete activation.
-- ============================================================
create table if not exists public.app_upgrade_requests (
  id uuid primary key default gen_random_uuid(),
  household_id text not null,
  requested_by_user_id uuid not null references auth.users(id) on delete cascade,
  requested_plan_code text not null default 'home_pro' check (requested_plan_code in ('home_pro')),
  source text,
  status text not null default 'requested' check (status in ('requested', 'contacted', 'completed', 'cancelled')),
  notes text,
  created_at timestamptz default now()
);

create index if not exists idx_app_upgrade_requests_hh on public.app_upgrade_requests (household_id);
create index if not exists idx_app_upgrade_requests_user on public.app_upgrade_requests (requested_by_user_id);

alter table public.app_upgrade_requests enable row level security;

drop policy if exists "app_upgrade_requests_sel" on public.app_upgrade_requests;
create policy "app_upgrade_requests_sel" on public.app_upgrade_requests
  for select using (
    public.app_hm(household_id)
    or requested_by_user_id = auth.uid()
  );

drop policy if exists "app_upgrade_requests_ins" on public.app_upgrade_requests;
create policy "app_upgrade_requests_ins" on public.app_upgrade_requests
  for insert with check (
    requested_by_user_id = auth.uid()
    and public.app_hm(household_id)
  );

-- ============================================================
-- HELPER: Is the current user a member of household [hid]?
-- SECURITY DEFINER so it bypasses RLS for the internal lookup.
-- ============================================================
create or replace function public.app_hm(hid text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.app_household_members
    where household_id = hid and user_id = auth.uid()
  )
$$;

-- ============================================================
-- RPC: Join a household by invite code.
-- Managers call this during signup. SECURITY DEFINER so it can
-- look up app_households without a prior membership.
-- p_user_id is passed explicitly from the client right after signUp,
-- before a Supabase session is established (email-confirm flow).
-- Falls back to auth.uid() when called from an authenticated session.
-- Returns the household_id (UUID as text) on success.
-- ============================================================
drop function if exists public.join_household_by_invite(text);
create or replace function public.join_household_by_invite(
  invite    text,
  p_user_id uuid default null
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  hid text;
  uid uuid;
begin
  uid := coalesce(p_user_id, auth.uid());
  if uid is null then
    raise exception 'Not authenticated';
  end if;

  select id::text into hid
    from public.app_households
    where upper(invite_code) = upper(invite)
    limit 1;

  if hid is null then
    raise exception 'Invalid invite code: %', invite;
  end if;

  insert into public.app_household_members (household_id, user_id, role)
  values (hid, uid, 'house_manager')
  on conflict (household_id, user_id) do nothing;

  return hid;
end;
$$;

-- Allow anon (pre-session signup) and authenticated callers to invoke this RPC.
grant execute on function public.join_household_by_invite(text, uuid) to anon, authenticated;

-- ============================================================
-- FEATURE DATA TABLES
-- Each table holds app model data as JSONB.
-- Schema: id TEXT PK, household_id TEXT, data JSONB, updated_at TIMESTAMPTZ
-- ============================================================

create table if not exists public.app_supplies (
  id text primary key,
  household_id text not null,
  data jsonb not null,
  updated_at timestamptz default now()
);

create table if not exists public.app_shopping_requests (
  id text primary key,
  household_id text not null,
  data jsonb not null,
  updated_at timestamptz default now()
);

create table if not exists public.app_meal_logs (
  id text primary key,
  household_id text not null,
  data jsonb not null,
  updated_at timestamptz default now()
);

create table if not exists public.app_children (
  id text primary key,
  household_id text not null,
  data jsonb not null,
  updated_at timestamptz default now()
);

create table if not exists public.app_child_logs (
  id text primary key,
  household_id text not null,
  data jsonb not null,
  updated_at timestamptz default now()
);

create table if not exists public.app_laundry_items (
  id text primary key,
  household_id text not null,
  data jsonb not null,
  updated_at timestamptz default now()
);

create table if not exists public.app_utilities (
  id text primary key,
  household_id text not null,
  data jsonb not null,
  updated_at timestamptz default now()
);

create table if not exists public.app_tasks (
  id text primary key,
  household_id text not null,
  data jsonb not null,
  updated_at timestamptz default now()
);

create table if not exists public.app_meal_timetable (
  id text primary key,
  household_id text not null,
  data jsonb not null,
  updated_at timestamptz default now()
);

create table if not exists public.app_staff_schedule (
  id text primary key,
  household_id text not null,
  data jsonb not null,
  updated_at timestamptz default now()
);

create table if not exists public.app_notifications (
  id text primary key,
  household_id text not null,
  data jsonb not null,
  updated_at timestamptz default now()
);

-- Indexes on household_id for all feature tables
create index if not exists idx_app_sup_hh    on public.app_supplies          (household_id);
create index if not exists idx_app_sreq_hh   on public.app_shopping_requests  (household_id);
create index if not exists idx_app_meal_hh   on public.app_meal_logs          (household_id);
create index if not exists idx_app_child_hh  on public.app_children           (household_id);
create index if not exists idx_app_clog_hh   on public.app_child_logs         (household_id);
create index if not exists idx_app_laun_hh   on public.app_laundry_items      (household_id);
create index if not exists idx_app_util_hh   on public.app_utilities          (household_id);
create index if not exists idx_app_task_hh   on public.app_tasks              (household_id);
create index if not exists idx_app_ttml_hh   on public.app_meal_timetable     (household_id);
create index if not exists idx_app_staff_hh  on public.app_staff_schedule     (household_id);
create index if not exists idx_app_notif_hh  on public.app_notifications      (household_id);

-- Enable RLS on all feature tables
alter table public.app_supplies          enable row level security;
alter table public.app_shopping_requests enable row level security;
alter table public.app_meal_logs         enable row level security;
alter table public.app_children          enable row level security;
alter table public.app_child_logs        enable row level security;
alter table public.app_laundry_items     enable row level security;
alter table public.app_utilities         enable row level security;
alter table public.app_tasks             enable row level security;
alter table public.app_meal_timetable    enable row level security;
alter table public.app_staff_schedule    enable row level security;
alter table public.app_notifications     enable row level security;

-- Single ALL policy per feature table using the app_hm() helper
do $$
declare
  tbl text;
  tbls text[] := array[
    'app_supplies', 'app_shopping_requests', 'app_meal_logs',
    'app_children', 'app_child_logs', 'app_laundry_items',
    'app_utilities', 'app_tasks', 'app_meal_timetable',
    'app_staff_schedule', 'app_notifications'
  ];
begin
  foreach tbl in array tbls loop
    execute format('drop policy if exists "sync_all_%1$s" on public.%1$I', tbl);
    execute format(
      'create policy "sync_all_%1$s" on public.%1$I '
      'for all using (public.app_hm(household_id)) '
      'with check (public.app_hm(household_id))',
      tbl
    );
  end loop;
end $$;

-- ============================================================
-- DONE
-- Tables: app_households, app_household_members + 11 feature tables
-- RLS: household-member-based access on all tables
-- RPC: join_household_by_invite(invite TEXT) → TEXT
-- ============================================================
