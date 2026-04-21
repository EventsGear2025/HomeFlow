-- ============================================================
-- homeFlow – Admin panel demo seed
-- Run AFTER:
--   1) docs/supabase-all-tables.sql
--   2) docs/supabase-admin-panel.sql
-- ============================================================
-- PURPOSE
-- This creates realistic demo/test data for the Flutter web admin panel.
--
-- IMPORTANT
-- `profiles.id` references `auth.users(id)` in the main schema.
-- That means profile rows must point to real auth users.
--
-- Fastest safe usage:
--   OPTION A (recommended)
--     - create the demo users in Supabase Auth first
--     - replace the placeholder UUIDs below with the real auth user ids
--     - uncomment the AUTH-DEPENDENT blocks in this file
--
--   OPTION B (quick partial demo)
--     - run this file as-is
--     - only the auth-INDEPENDENT admin records will be created
--     - this is enough for early admin tables like roles, system alerts,
--       failed jobs, and some template content
-- ============================================================

-- ------------------------------------------------------------
-- 0. DEMO AUTH USER IDS (REPLACE THESE)
-- ------------------------------------------------------------
-- Household-facing users
-- Janet Mwaura (owner)
-- Lucy Wambui (manager)
-- Grace Kariuki (owner)
-- Kevin Otieno (manager)
--
-- Internal admin users
-- Ruth Ops
-- Kevin Support
-- Mary Billing
-- Brian Content

-- Reusable IDs
-- households
--   Mwaura Residence      10000000-0000-0000-0000-000000000001
--   Kariuki Home          10000000-0000-0000-0000-000000000002
--   Akinyi Apartment      10000000-0000-0000-0000-000000000003
--   Mwende Family         10000000-0000-0000-0000-000000000004

-- ------------------------------------------------------------
-- 1. SUBSCRIPTION PLANS
-- ------------------------------------------------------------

insert into public.subscription_plans (id, name, tier, max_members, max_zones, price_cents, currency, features, is_active)
values
  ('20000000-0000-0000-0000-000000000001', 'Free', 'free', 3, 2, 0, 'KES', '{"supplies":25,"children":2,"support":"community"}'::jsonb, true),
  ('20000000-0000-0000-0000-000000000002', 'Basic', 'basic', 5, 4, 250000, 'KES', '{"supplies":60,"children":4,"support":"standard"}'::jsonb, true),
  ('20000000-0000-0000-0000-000000000003', 'Gold', 'premium', 10, 8, 550000, 'KES', '{"supplies":100,"children":10,"support":"priority"}'::jsonb, true)
on conflict (id) do nothing;

-- ------------------------------------------------------------
-- 2. PROFILES (AUTH-DEPENDENT)
-- ------------------------------------------------------------

-- This block is intentionally commented out.
-- Replace the placeholder UUIDs with real auth.users ids, then uncomment.

/*
insert into public.profiles (id, email, full_name, role)
values
  ('30000000-0000-0000-0000-000000000001', 'janet@homeflow.app', 'Janet Mwaura', 'owner'),
  ('30000000-0000-0000-0000-000000000002', 'lucy.manager@homeflow.app', 'Lucy Wambui', 'house_manager'),
  ('30000000-0000-0000-0000-000000000003', 'grace@homeflow.app', 'Grace Kariuki', 'owner'),
  ('30000000-0000-0000-0000-000000000004', 'kevin.ops@homeflow.app', 'Kevin Otieno', 'house_manager')
on conflict (id) do nothing;

insert into public.profiles (id, email, full_name, role)
values
  ('30000000-0000-0000-0000-000000000101', 'ruth.ops@homeflow.app', 'Ruth Ops', 'owner'),
  ('30000000-0000-0000-0000-000000000102', 'kevin.support@homeflow.app', 'Kevin Support', 'owner'),
  ('30000000-0000-0000-0000-000000000103', 'mary.billing@homeflow.app', 'Mary Billing', 'owner'),
  ('30000000-0000-0000-0000-000000000104', 'brian.content@homeflow.app', 'Brian Content', 'owner')
on conflict (id) do nothing;
*/

-- ------------------------------------------------------------
-- 3. HOUSEHOLDS (AUTH-DEPENDENT)
-- ------------------------------------------------------------

/*
insert into public.households (id, household_name, owner_user_id, invite_code, subscription_plan_id, address, timezone)
values
  ('10000000-0000-0000-0000-000000000001', 'Mwaura Residence', '30000000-0000-0000-0000-000000000001', 'MWAURA25', '20000000-0000-0000-0000-000000000003', 'Nairobi', 'Africa/Nairobi'),
  ('10000000-0000-0000-0000-000000000002', 'Kariuki Home', '30000000-0000-0000-0000-000000000003', 'KARIBASIC', '20000000-0000-0000-0000-000000000002', 'Kiambu', 'Africa/Nairobi'),
  ('10000000-0000-0000-0000-000000000003', 'Akinyi Apartment', '30000000-0000-0000-0000-000000000003', 'AKINYI01', '20000000-0000-0000-0000-000000000001', 'Kisumu', 'Africa/Nairobi'),
  ('10000000-0000-0000-0000-000000000004', 'Mwende Family', '30000000-0000-0000-0000-000000000001', 'MWENDE88', '20000000-0000-0000-0000-000000000003', 'Mombasa', 'Africa/Nairobi')
on conflict (id) do nothing;
*/

-- ------------------------------------------------------------
-- 4. HOUSEHOLD MEMBERS (AUTH-DEPENDENT)
-- ------------------------------------------------------------

/*
insert into public.household_members (household_id, user_id, role, is_active)
values
  ('10000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', 'owner', true),
  ('10000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000002', 'house_manager', true),
  ('10000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000003', 'owner', true),
  ('10000000-0000-0000-0000-000000000003', '30000000-0000-0000-0000-000000000004', 'house_manager', false),
  ('10000000-0000-0000-0000-000000000004', '30000000-0000-0000-0000-000000000001', 'owner', true)
on conflict (household_id, user_id) do nothing;
*/

-- ------------------------------------------------------------
-- 5. CHILDREN (AUTH-DEPENDENT THROUGH HOUSEHOLDS)
-- ------------------------------------------------------------

/*
insert into public.children (id, household_id, full_name, nickname, school_name, school_grade)
values
  ('40000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Tamara Mwaura', 'Tami', 'Greenview Academy', 'Grade 2'),
  ('40000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', 'Jay Mwaura', 'Jay', 'Greenview Academy', 'PP2'),
  ('40000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000002', 'Nia Kariuki', 'Nia', 'Kiambu Junior', 'Grade 1'),
  ('40000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000003', 'Lulu Akinyi', 'Lulu', 'Lake Primary', 'PP1'),
  ('40000000-0000-0000-0000-000000000005', '10000000-0000-0000-0000-000000000003', 'Toni Akinyi', 'Toni', 'Lake Primary', 'Baby Class')
on conflict (id) do nothing;
*/

-- ------------------------------------------------------------
-- 6. NOTIFICATIONS (AUTH-DEPENDENT THROUGH HOUSEHOLDS/PROFILES)
-- ------------------------------------------------------------

/*
insert into public.notifications (id, household_id, recipient_id, title, body, type, read, action_url)
values
  ('50000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000002', 'Low stock alert', 'Washing powder is below threshold.', 'inventory', false, '/supplies'),
  ('50000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000003', '30000000-0000-0000-0000-000000000003', 'Plan limit warning', 'Your household has reached the free plan supply limit.', 'billing', false, '/billing'),
  ('50000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000003', 'Laundry delayed notice', 'The white load batch is still pending.', 'laundry', true, '/laundry')
on conflict (id) do nothing;
*/

-- ------------------------------------------------------------
-- 7. ADMIN USERS (SAFE VERSION)
-- ------------------------------------------------------------

insert into public.admin_users (id, profile_id, email, full_name, role_id, status, last_active_at)
select
  seeded.id,
  null,
  seeded.email,
  seeded.full_name,
  ar.id,
  seeded.status,
  seeded.last_active_at
from (
  values
  ('60000000-0000-0000-0000-000000000001'::uuid, 'ruth.ops@homeflow.app', 'Ruth Ops', 'Super Admin', 'active', now() - interval '5 minutes'),
  ('60000000-0000-0000-0000-000000000002'::uuid, 'kevin.support@homeflow.app', 'Kevin Support', 'Support Admin', 'active', now() - interval '22 minutes'),
  ('60000000-0000-0000-0000-000000000003'::uuid, 'mary.billing@homeflow.app', 'Mary Billing', 'Billing Admin', 'active', now() - interval '1 hour'),
  ('60000000-0000-0000-0000-000000000004'::uuid, 'brian.content@homeflow.app', 'Brian Content', 'Content Admin', 'limited', now() - interval '1 day')
) as seeded(id, email, full_name, role_name, status, last_active_at)
join public.admin_roles ar on ar.name = seeded.role_name
on conflict (id) do nothing;

-- ------------------------------------------------------------
-- 8. SUPPORT CATEGORIES
-- ------------------------------------------------------------

insert into public.support_issue_categories (id, key, label)
values
  ('70000000-0000-0000-0000-000000000001', 'notifications', 'Notifications'),
  ('70000000-0000-0000-0000-000000000002', 'subscription', 'Subscription'),
  ('70000000-0000-0000-0000-000000000003', 'laundry_bug', 'Laundry bug')
on conflict (key) do nothing;

-- ------------------------------------------------------------
-- 9. SUPPORT ISSUES (AUTH-DEPENDENT THROUGH HOUSEHOLDS/PROFILES)
-- ------------------------------------------------------------

/*
insert into public.support_issues (id, household_id, profile_id, category_id, title, description, priority, status, assigned_admin_user_id, source, created_at)
values
  (
    '71000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000002',
    '30000000-0000-0000-0000-000000000003',
    '70000000-0000-0000-0000-000000000001',
    'Notifications not showing on Android',
    'Push alerts are generated but not appearing on one Android device.',
    'high',
    'open',
    '60000000-0000-0000-0000-000000000002',
    'mobile_app',
    now() - interval '2 hours'
  ),
  (
    '71000000-0000-0000-0000-000000000002',
    '10000000-0000-0000-0000-000000000003',
    '30000000-0000-0000-0000-000000000003',
    '70000000-0000-0000-0000-000000000002',
    'Cannot upgrade from free to gold',
    'Upgrade CTA redirects, but billing confirmation never completes.',
    'critical',
    'in_progress',
    '60000000-0000-0000-0000-000000000003',
    'web_admin',
    now() - interval '3 hours'
  ),
  (
    '71000000-0000-0000-0000-000000000003',
    '10000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000002',
    '70000000-0000-0000-0000-000000000003',
    'Laundry stage stuck on washing',
    'Batch LB-129 remains in washing despite completion tick.',
    'medium',
    'open',
    '60000000-0000-0000-0000-000000000002',
    'mobile_app',
    now() - interval '1 day'
  )
on conflict (id) do nothing;

insert into public.support_issue_comments (support_issue_id, admin_user_id, profile_id, body, is_internal)
values
  ('71000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000002', null, 'Replicated on Android 14 emulator. Investigating notification permission handshake.', true),
  ('71000000-0000-0000-0000-000000000002', '60000000-0000-0000-0000-000000000003', null, 'Temporary complimentary extension may unblock the customer while billing is checked.', true),
  ('71000000-0000-0000-0000-000000000003', null, '30000000-0000-0000-0000-000000000002', 'The load has already finished in real life, but the app still shows washing.', false);
*/

-- ------------------------------------------------------------
-- 10. TEMPLATES + DELIVERY LOGS
-- ------------------------------------------------------------

insert into public.notification_templates (id, key, name, channel, subject, body, severity, is_active, created_by_admin_user_id)
values
  ('80000000-0000-0000-0000-000000000001', 'low_stock_alert', 'Low stock alert', 'in_app', 'Supply running low', 'A tracked supply item is below your configured threshold.', 'warning', true, null),
  ('80000000-0000-0000-0000-000000000002', 'plan_limit_warning', 'Plan limit warning', 'in_app', 'Plan usage warning', 'Your household is close to or at a plan limit.', 'critical', true, null),
  ('80000000-0000-0000-0000-000000000003', 'laundry_delayed_notice', 'Laundry delayed notice', 'push', 'Laundry delayed', 'A laundry batch is delayed and may need reassignment.', 'warning', true, null)
on conflict (key) do nothing;

/*
insert into public.notification_delivery_logs (id, notification_id, template_id, household_id, recipient_profile_id, status, error_message, metadata, delivered_at)
values
  ('81000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', '80000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000002', 'delivered', null, '{"channel":"in_app","latency_ms":210}'::jsonb, now() - interval '10 minutes'),
  ('81000000-0000-0000-0000-000000000002', '50000000-0000-0000-0000-000000000002', '80000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000003', '30000000-0000-0000-0000-000000000003', 'delivered', null, '{"channel":"in_app","escalated":true}'::jsonb, now() - interval '20 minutes'),
  ('81000000-0000-0000-0000-000000000003', null, null, null, null, 'failed', 'Push queue timeout on worker-2', '{"failed_count":11,"job_group":"push-retry-batch"}'::jsonb, null)
on conflict (id) do nothing;
*/

insert into public.notification_delivery_logs (id, notification_id, template_id, household_id, recipient_profile_id, status, error_message, metadata, delivered_at)
values
  ('81000000-0000-0000-0000-000000000003', null, null, null, null, 'failed', 'Push queue timeout on worker-2', '{"failed_count":11,"job_group":"push-retry-batch"}'::jsonb, null)
on conflict (id) do nothing;

-- ------------------------------------------------------------
-- 11. BILLING / HOUSEHOLD OVERRIDES (AUTH-DEPENDENT THROUGH HOUSEHOLDS)
-- ------------------------------------------------------------

/*
insert into public.household_plan_adjustments (id, household_id, admin_user_id, adjustment_type, previous_plan, new_plan, starts_at, ends_at, notes)
values
  ('90000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000003', '60000000-0000-0000-0000-000000000003', 'trial', 'Free', 'Gold', now() - interval '1 day', now() + interval '14 days', 'Manual sales assist while upgrade flow is investigated'),
  ('90000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000003', 'upgrade', 'Basic', 'Gold', now() - interval '12 days', null, 'Customer upgraded successfully after onboarding')
on conflict (id) do nothing;

insert into public.household_feature_limits (household_id, max_bedrooms, max_supplies, max_children, source, updated_by_admin_user_id)
values
  ('10000000-0000-0000-0000-000000000001', 8, 100, 10, 'plan', '60000000-0000-0000-0000-000000000003'),
  ('10000000-0000-0000-0000-000000000002', 4, 25, 3, 'plan', '60000000-0000-0000-0000-000000000003'),
  ('10000000-0000-0000-0000-000000000003', 2, 25, 2, 'plan', '60000000-0000-0000-0000-000000000003'),
  ('10000000-0000-0000-0000-000000000004', 8, 100, 10, 'plan', '60000000-0000-0000-0000-000000000003')
on conflict (household_id) do nothing;
*/

-- ------------------------------------------------------------
-- 12. ADMIN ACTIVITY (PARTIAL SAFE VERSION)
-- ------------------------------------------------------------

insert into public.admin_activity_logs (id, admin_user_id, household_id, target_profile_id, action, entity_type, entity_id, metadata, created_at)
values
  ('91000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000003', null, null, 'Reviewed plan upgrade queue', 'subscription', null, '{"summary":"Gold upgrade demand increasing"}'::jsonb, now() - interval '9 hours'),
  ('91000000-0000-0000-0000-000000000002', '60000000-0000-0000-0000-000000000002', null, null, 'Opened support triage shift', 'support', null, '{"queue":"mobile_app"}'::jsonb, now() - interval '18 hours'),
  ('91000000-0000-0000-0000-000000000003', '60000000-0000-0000-0000-000000000004', null, null, 'Updated low stock alert template', 'notification_template', '80000000-0000-0000-0000-000000000001', '{"version":"v2"}'::jsonb, now() - interval '1 day')
on conflict (id) do nothing;

-- ------------------------------------------------------------
-- 13. ALERTS + FAILED JOBS (SAFE VERSION)
-- ------------------------------------------------------------

insert into public.system_alerts (id, alert_type, severity, title, body, source, status, related_household_id, created_at)
values
  ('92000000-0000-0000-0000-000000000001', 'plan_limit', 'warning', 'Akinyi Apartment hitting free-plan limits', '2/2 children and 25/25 supplies reached.', 'billing-watchdog', 'open', null, now() - interval '40 minutes'),
  ('92000000-0000-0000-0000-000000000002', 'notification_queue', 'critical', 'Notification retry queue growing', '11 delayed push jobs since 06:00.', 'notifications-worker', 'open', null, now() - interval '1 hour'),
  ('92000000-0000-0000-0000-000000000003', 'forecast_worker', 'critical', 'Forecast worker error spike', '3 jobs failed due to stale schema cache.', 'forecast-worker', 'open', null, now() - interval '2 hours')
on conflict (id) do nothing;

insert into public.failed_jobs (id, job_key, job_type, related_household_id, payload, error_message, retry_count, status, created_at)
values
  ('93000000-0000-0000-0000-000000000001', 'push-retry-20260323-01', 'notifications', null, '{"batch":11}'::jsonb, 'Push provider timeout', 2, 'retrying', now() - interval '1 hour'),
  ('93000000-0000-0000-0000-000000000002', 'forecast-refresh-20260323-02', 'forecast', null, '{"zones":18}'::jsonb, 'Cached metadata mismatch', 1, 'failed', now() - interval '2 hours'),
  ('93000000-0000-0000-0000-000000000003', 'billing-upgrade-20260323-03', 'billing', null, '{"plan":"Gold"}'::jsonb, 'Payment callback missing reference', 3, 'failed', now() - interval '3 hours')
on conflict (id) do nothing;

-- ============================================================
-- DONE – admin demo/test seed
-- ============================================================
