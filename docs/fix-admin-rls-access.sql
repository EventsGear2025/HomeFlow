-- ============================================================
-- FIX: Admin panel can't see real household data
--
-- Root cause: app_households and all app_* feature tables restrict
-- SELECT to household owners/members only (via app_hm() / get_my_household_ids()).
-- The admin panel signs in as a normal Supabase Auth user that is NOT a
-- member of any household, so every admin query on these tables returns
-- zero rows and the admin panel silently falls back to demo data on:
--   - Households page
--   - Dashboard stats / Analytics / Subscriptions (derived from app_households)
--   - Household Detail tabs (children, supplies, shopping, meals, laundry,
--     notifications) which all gate through app_hm()
--
-- This adds an "is an active admin" bypass to the relevant policies.
--
-- SECURITY NOTE: this also re-tightens app_household_members, which is
-- currently readable by ANY authenticated user regardless of household
-- membership (a broken-access-control bug letting any signed-up user
-- list every household's members/names/emails).
-- ============================================================

create or replace function public.is_active_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.admin_users
    where status <> 'disabled'
      and (
        profile_id = auth.uid()
        or lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
      )
  );
$$;

-- Feature tables (app_supplies, app_children, app_laundry_items, etc.)
-- all gate through app_hm(); adding the admin bypass here fixes all of them
-- in one place.
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
  ) or public.is_active_admin()
$$;

-- app_households: admins can now read every household, not just their own.
drop policy if exists "app_hh_sel" on public.app_households;
create policy "app_hh_sel" on public.app_households for select
  using (
    owner_user_id = auth.uid()
    or id::text in (select public.get_my_household_ids())
    or public.is_active_admin()
  );

-- app_household_members: re-tightens the membership-only read (closing the
-- current leak) while still letting active admins through.
drop policy if exists "app_hm_sel" on public.app_household_members;
create policy "app_hm_sel" on public.app_household_members
  for select using (
    user_id = auth.uid()
    or household_id in (select public.get_my_household_ids())
    or public.is_active_admin()
  );
