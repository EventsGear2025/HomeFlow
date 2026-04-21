-- ============================================================
-- homeFlow – Admin panel schema
-- Run AFTER the main app schema has already been created
-- ============================================================

create extension if not exists pgcrypto;

-- ============================================================
-- 1. ADMIN ROLES & USERS
-- ============================================================

create table if not exists public.admin_roles (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  description text,
  permissions jsonb not null default '[]',
  created_at timestamptz not null default now()
);

create table if not exists public.admin_users (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid references public.profiles(id) on delete set null,
  email text not null unique,
  full_name text not null,
  role_id uuid references public.admin_roles(id) on delete restrict,
  status text not null default 'active' check (status in ('active', 'limited', 'disabled')),
  last_active_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.admin_permissions_overrides (
  id uuid primary key default gen_random_uuid(),
  admin_user_id uuid not null references public.admin_users(id) on delete cascade,
  permission_key text not null,
  allowed boolean not null default true,
  created_at timestamptz not null default now(),
  unique (admin_user_id, permission_key)
);

-- ============================================================
-- 2. SUPPORT / TICKETING
-- ============================================================

create table if not exists public.support_issue_categories (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,
  label text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.support_issues (
  id uuid primary key default gen_random_uuid(),
  household_id uuid references public.households(id) on delete set null,
  profile_id uuid references public.profiles(id) on delete set null,
  category_id uuid references public.support_issue_categories(id) on delete set null,
  title text not null,
  description text,
  priority text not null default 'medium' check (priority in ('low', 'medium', 'high', 'critical')),
  status text not null default 'open' check (status in ('open', 'in_progress', 'resolved', 'closed')),
  assigned_admin_user_id uuid references public.admin_users(id) on delete set null,
  source text default 'admin',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  resolved_at timestamptz
);

create table if not exists public.support_issue_comments (
  id uuid primary key default gen_random_uuid(),
  support_issue_id uuid not null references public.support_issues(id) on delete cascade,
  admin_user_id uuid references public.admin_users(id) on delete set null,
  profile_id uuid references public.profiles(id) on delete set null,
  body text not null,
  is_internal boolean not null default true,
  created_at timestamptz not null default now()
);

-- ============================================================
-- 3. ADMIN NOTIFICATIONS / TEMPLATE MANAGEMENT
-- ============================================================

create table if not exists public.notification_templates (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,
  name text not null,
  channel text not null default 'in_app',
  subject text,
  body text not null,
  severity text default 'info',
  is_active boolean not null default true,
  created_by_admin_user_id uuid references public.admin_users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.notification_delivery_logs (
  id uuid primary key default gen_random_uuid(),
  notification_id uuid references public.notifications(id) on delete set null,
  template_id uuid references public.notification_templates(id) on delete set null,
  household_id uuid references public.households(id) on delete set null,
  recipient_profile_id uuid references public.profiles(id) on delete set null,
  status text not null default 'delivered' check (status in ('queued', 'sent', 'delivered', 'failed', 'read')),
  error_message text,
  metadata jsonb,
  delivered_at timestamptz,
  created_at timestamptz not null default now()
);

-- ============================================================
-- 4. HOUSEHOLD PLAN / ADMIN ADJUSTMENTS
-- ============================================================

create table if not exists public.household_plan_adjustments (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  admin_user_id uuid references public.admin_users(id) on delete set null,
  adjustment_type text not null check (adjustment_type in ('trial', 'complimentary', 'upgrade', 'downgrade', 'manual_extension', 'suspend_paid_features')),
  previous_plan text,
  new_plan text,
  starts_at timestamptz,
  ends_at timestamptz,
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists public.household_feature_limits (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  max_bedrooms integer,
  max_supplies integer,
  max_children integer,
  source text not null default 'plan',
  updated_by_admin_user_id uuid references public.admin_users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (household_id)
);

-- ============================================================
-- 5. ADMIN AUDIT TRAIL
-- ============================================================

create table if not exists public.admin_activity_logs (
  id uuid primary key default gen_random_uuid(),
  admin_user_id uuid references public.admin_users(id) on delete set null,
  household_id uuid references public.households(id) on delete set null,
  target_profile_id uuid references public.profiles(id) on delete set null,
  action text not null,
  entity_type text,
  entity_id uuid,
  metadata jsonb,
  created_at timestamptz not null default now()
);

-- ============================================================
-- 6. SYSTEM / JOB MONITORING
-- ============================================================

create table if not exists public.system_alerts (
  id uuid primary key default gen_random_uuid(),
  alert_type text not null,
  severity text not null default 'warning' check (severity in ('info', 'warning', 'critical')),
  title text not null,
  body text,
  source text,
  status text not null default 'open' check (status in ('open', 'acknowledged', 'resolved')),
  related_household_id uuid references public.households(id) on delete set null,
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

create table if not exists public.failed_jobs (
  id uuid primary key default gen_random_uuid(),
  job_key text not null,
  job_type text not null,
  related_household_id uuid references public.households(id) on delete set null,
  payload jsonb,
  error_message text,
  retry_count integer not null default 0,
  status text not null default 'failed' check (status in ('failed', 'retrying', 'resolved')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ============================================================
-- 7. INDEXES
-- ============================================================

create index if not exists idx_admin_users_role on public.admin_users(role_id);
create index if not exists idx_support_issues_household on public.support_issues(household_id);
create index if not exists idx_support_issues_status on public.support_issues(status);
create index if not exists idx_support_issues_assigned on public.support_issues(assigned_admin_user_id);
create index if not exists idx_notification_delivery_household on public.notification_delivery_logs(household_id);
create index if not exists idx_admin_activity_household on public.admin_activity_logs(household_id);
create index if not exists idx_failed_jobs_household on public.failed_jobs(related_household_id);
create index if not exists idx_system_alerts_household on public.system_alerts(related_household_id);

-- ============================================================
-- 8. RLS
-- ============================================================

alter table public.admin_roles enable row level security;
alter table public.admin_users enable row level security;
alter table public.admin_permissions_overrides enable row level security;
alter table public.support_issue_categories enable row level security;
alter table public.support_issues enable row level security;
alter table public.support_issue_comments enable row level security;
alter table public.notification_templates enable row level security;
alter table public.notification_delivery_logs enable row level security;
alter table public.household_plan_adjustments enable row level security;
alter table public.household_feature_limits enable row level security;
alter table public.admin_activity_logs enable row level security;
alter table public.system_alerts enable row level security;
alter table public.failed_jobs enable row level security;

-- NOTE:
-- These admin tables should be restricted to internal admin users only.
-- Recommended production approach:
--   1. Add custom JWT claim like app_role=admin for internal staff
--   2. Use policies checking auth.jwt() ->> 'app_role' = 'admin'
-- For now, example read policy:

create policy "admin_read_roles" on public.admin_roles
  for select using ((auth.jwt() ->> 'app_role') = 'admin');

create policy "admin_read_users" on public.admin_users
  for select using ((auth.jwt() ->> 'app_role') = 'admin');

create policy "admin_read_support_issues" on public.support_issues
  for select using ((auth.jwt() ->> 'app_role') = 'admin');

create policy "admin_read_admin_activity_logs" on public.admin_activity_logs
  for select using ((auth.jwt() ->> 'app_role') = 'admin');

-- Expand with insert/update/delete policies per workflow before production launch.

-- ============================================================
-- 9. SEED CORE ADMIN ROLES
-- ============================================================

insert into public.admin_roles (name, description, permissions)
values
  ('Super Admin', 'Full platform access', '["*"]'::jsonb),
  ('Support Admin', 'Households, users, support, activity visibility', '["households.read","users.read","support.manage","activity.read"]'::jsonb),
  ('Billing Admin', 'Plans, billing, trials, complimentary access', '["billing.manage","plans.manage","households.read"]'::jsonb),
  ('Content Admin', 'Presets, templates, onboarding content', '["presets.manage","templates.manage"]'::jsonb)
on conflict (name) do nothing;

-- ============================================================
-- 10. TIMESTAMP TRIGGER
-- ============================================================

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger trg_admin_users_updated_at
before update on public.admin_users
for each row execute function public.set_updated_at();

create trigger trg_support_issues_updated_at
before update on public.support_issues
for each row execute function public.set_updated_at();

create trigger trg_notification_templates_updated_at
before update on public.notification_templates
for each row execute function public.set_updated_at();

create trigger trg_household_feature_limits_updated_at
before update on public.household_feature_limits
for each row execute function public.set_updated_at();

create trigger trg_failed_jobs_updated_at
before update on public.failed_jobs
for each row execute function public.set_updated_at();

-- ============================================================
-- DONE – admin web backend schema
-- ============================================================
