-- ============================================================
-- FIX: infinite recursion in RLS policies for
-- app_household_members / app_households
--
-- Root cause: app_hm_sel does a sub-select on itself,
-- which re-triggers app_hm_sel → infinite loop.
--
-- Solution: a SECURITY DEFINER helper that runs as the
-- DB owner (bypasses RLS), breaking the cycle.
-- ============================================================

-- 1. Helper function (runs as DB owner, skips RLS)
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

-- 2. Fix app_household_members SELECT policy
drop policy if exists "app_hm_sel" on public.app_household_members;
create policy "app_hm_sel" on public.app_household_members
  for select using (
    user_id = auth.uid()
    or household_id in (select public.get_my_household_ids())
  );

-- 3. Fix app_households SELECT policy
drop policy if exists "app_hh_sel" on public.app_households;
create policy "app_hh_sel" on public.app_households
  for select using (
    owner_user_id = auth.uid()
    or id::text in (select public.get_my_household_ids())
  );
