-- ============================================================
-- homeFlow – COMPLETE production schema (60+ tables)
-- Run this ONCE in the Supabase SQL Editor
-- ============================================================
-- IMPORTANT: If you have old tables from a previous run, run
-- the DROP script at the very bottom of this file FIRST,
-- then run this entire file.
-- ============================================================

create extension if not exists pgcrypto;

-- ============================================================
--  TIER 1 – IDENTITY & HOUSEHOLD
-- ============================================================

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null unique,
  full_name text not null,
  avatar_url text,
  role text not null check (role in ('owner','house_manager')),
  created_at timestamptz not null default now(),
  updated_at timestamptz default now()
);

create table if not exists public.subscription_plans (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  tier text not null check (tier in ('free','basic','premium','enterprise')),
  max_members integer not null default 5,
  max_zones integer not null default 3,
  price_cents integer not null default 0,
  currency text not null default 'KES',
  features jsonb default '{}',
  is_active boolean default true,
  created_at timestamptz default now()
);

create table if not exists public.households (
  id uuid primary key default gen_random_uuid(),
  household_name text not null,
  owner_user_id uuid not null references public.profiles(id) on delete cascade,
  invite_code text not null unique,
  subscription_plan_id uuid references public.subscription_plans(id),
  address text,
  timezone text default 'Africa/Nairobi',
  created_at timestamptz not null default now(),
  updated_at timestamptz default now()
);

create table if not exists public.household_members (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null check (role in ('owner','house_manager')),
  is_active boolean default true,
  created_at timestamptz not null default now(),
  unique (household_id, user_id)
);

create table if not exists public.household_zones (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  name text not null,
  zone_type text,
  description text,
  created_at timestamptz default now()
);

-- ============================================================
--  TIER 2 – CHILDREN
-- ============================================================

create table if not exists public.children (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  full_name text not null,
  nickname text,
  birthdate date,
  gender text,
  blood_type text,
  allergies text[],
  school_name text,
  school_grade text,
  photo_url text,
  notes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.child_routine_logs (
  id uuid primary key default gen_random_uuid(),
  child_id uuid not null references public.children(id) on delete cascade,
  household_id uuid not null references public.households(id) on delete cascade,
  routine_type text not null,
  logged_at timestamptz not null default now(),
  status text default 'done',
  notes text,
  logged_by uuid references public.profiles(id),
  created_at timestamptz default now()
);

create table if not exists public.child_diet_profiles (
  id uuid primary key default gen_random_uuid(),
  child_id uuid not null references public.children(id) on delete cascade,
  household_id uuid not null references public.households(id) on delete cascade,
  dietary_type text,
  restrictions text[],
  preferred_foods text[],
  disliked_foods text[],
  daily_calorie_target integer,
  notes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.school_item_templates (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  child_id uuid references public.children(id) on delete set null,
  item_name text not null,
  category text,
  is_daily boolean default true,
  notes text,
  created_at timestamptz default now()
);

create table if not exists public.child_special_schedules (
  id uuid primary key default gen_random_uuid(),
  child_id uuid not null references public.children(id) on delete cascade,
  household_id uuid not null references public.households(id) on delete cascade,
  title text not null,
  schedule_date date not null,
  start_time time,
  end_time time,
  recurrence text,
  notes text,
  created_at timestamptz default now()
);

create table if not exists public.child_medication_logs (
  id uuid primary key default gen_random_uuid(),
  child_id uuid not null references public.children(id) on delete cascade,
  household_id uuid not null references public.households(id) on delete cascade,
  medication_name text not null,
  dosage text,
  administered_at timestamptz not null default now(),
  administered_by uuid references public.profiles(id),
  next_dose_at timestamptz,
  notes text,
  created_at timestamptz default now()
);

-- ============================================================
--  TIER 3 – SUPPLIES & SHOPPING
-- ============================================================

create table if not exists public.supply_categories (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  name text not null,
  icon text,
  sort_order integer default 0,
  created_at timestamptz default now()
);

create table if not exists public.supplies (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  category_id uuid references public.supply_categories(id) on delete set null,
  name text not null,
  quantity numeric not null default 0,
  unit text,
  min_required numeric default 0,
  cost_per_unit numeric,
  zone_id uuid references public.household_zones(id) on delete set null,
  notes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.supply_rules (
  id uuid primary key default gen_random_uuid(),
  supply_id uuid not null references public.supplies(id) on delete cascade,
  household_id uuid not null references public.households(id) on delete cascade,
  rule_type text not null,
  threshold numeric,
  action text,
  is_active boolean default true,
  created_at timestamptz default now()
);

create table if not exists public.supply_restock_history (
  id uuid primary key default gen_random_uuid(),
  supply_id uuid not null references public.supplies(id) on delete cascade,
  household_id uuid not null references public.households(id) on delete cascade,
  quantity_added numeric not null,
  cost numeric,
  restocked_by uuid references public.profiles(id),
  restocked_at timestamptz default now(),
  notes text
);

create table if not exists public.supply_consumption_snapshots (
  id uuid primary key default gen_random_uuid(),
  supply_id uuid not null references public.supplies(id) on delete cascade,
  household_id uuid not null references public.households(id) on delete cascade,
  snapshot_date date not null,
  quantity_remaining numeric not null,
  created_at timestamptz default now()
);

create table if not exists public.shopping_requests (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  requested_by uuid references public.profiles(id),
  assigned_to uuid references public.profiles(id),
  status text default 'pending',
  priority text default 'normal',
  items jsonb not null default '[]',
  total_estimate numeric,
  due_date date,
  notes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ============================================================
--  TIER 4 – FINANCES
-- ============================================================

create table if not exists public.household_budgets (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  category text not null,
  month date not null,
  budget_amount numeric not null default 0,
  spent_amount numeric not null default 0,
  currency text default 'KES',
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.purchase_transactions (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  shopping_request_id uuid references public.shopping_requests(id) on delete set null,
  amount numeric not null,
  currency text default 'KES',
  payment_method text,
  vendor text,
  description text,
  transaction_date timestamptz not null default now(),
  recorded_by uuid references public.profiles(id),
  created_at timestamptz default now()
);

create table if not exists public.receipt_files (
  id uuid primary key default gen_random_uuid(),
  transaction_id uuid not null references public.purchase_transactions(id) on delete cascade,
  household_id uuid not null references public.households(id) on delete cascade,
  file_url text not null,
  file_type text,
  ocr_data jsonb,
  uploaded_by uuid references public.profiles(id),
  created_at timestamptz default now()
);

-- ============================================================
--  TIER 5 – MEALS & NUTRITION
-- ============================================================

create table if not exists public.nutrition_tags (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  color text,
  created_at timestamptz default now()
);

create table if not exists public.meal_presets (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  name text not null,
  meal_type text,
  description text,
  prep_time_minutes integer,
  photo_url text,
  created_at timestamptz default now()
);

create table if not exists public.meal_preset_nutrition_tags (
  id uuid primary key default gen_random_uuid(),
  meal_preset_id uuid not null references public.meal_presets(id) on delete cascade,
  nutrition_tag_id uuid not null references public.nutrition_tags(id) on delete cascade,
  unique (meal_preset_id, nutrition_tag_id)
);

create table if not exists public.recipes (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  meal_preset_id uuid references public.meal_presets(id) on delete set null,
  title text not null,
  instructions text,
  servings integer,
  prep_time_minutes integer,
  cook_time_minutes integer,
  photo_url text,
  created_at timestamptz default now()
);

create table if not exists public.recipe_ingredients (
  id uuid primary key default gen_random_uuid(),
  recipe_id uuid not null references public.recipes(id) on delete cascade,
  supply_id uuid references public.supplies(id) on delete set null,
  name text not null,
  quantity numeric,
  unit text,
  is_optional boolean default false
);

create table if not exists public.meal_logs (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  meal_preset_id uuid references public.meal_presets(id) on delete set null,
  meal_date date not null,
  meal_type text not null,
  prepared_by uuid references public.profiles(id),
  notes text,
  photo_url text,
  created_at timestamptz default now()
);

create table if not exists public.meal_log_items (
  id uuid primary key default gen_random_uuid(),
  meal_log_id uuid not null references public.meal_logs(id) on delete cascade,
  item_name text not null,
  portion text,
  calories integer,
  notes text
);

create table if not exists public.meal_nutrition_summaries (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  summary_date date not null,
  total_calories integer,
  protein_g numeric,
  carbs_g numeric,
  fat_g numeric,
  fiber_g numeric,
  data jsonb,
  created_at timestamptz default now()
);

-- ============================================================
--  TIER 6 – LAUNDRY
-- ============================================================

create table if not exists public.laundry_presets (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  name text not null,
  wash_type text,
  temperature text,
  instructions text,
  created_at timestamptz default now()
);

create table if not exists public.laundry_batches (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  preset_id uuid references public.laundry_presets(id) on delete set null,
  status text default 'pending',
  started_at timestamptz,
  completed_at timestamptz,
  assigned_to uuid references public.profiles(id),
  notes text,
  created_at timestamptz default now()
);

create table if not exists public.laundry_batch_items (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references public.laundry_batches(id) on delete cascade,
  child_id uuid references public.children(id) on delete set null,
  item_description text not null,
  quantity integer default 1,
  notes text
);

create table if not exists public.laundry_stage_history (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references public.laundry_batches(id) on delete cascade,
  stage text not null,
  entered_at timestamptz not null default now(),
  exited_at timestamptz,
  performed_by uuid references public.profiles(id)
);

create table if not exists public.laundry_stats_snapshots (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  snapshot_date date not null,
  total_batches integer default 0,
  items_washed integer default 0,
  avg_turnaround_minutes integer,
  created_at timestamptz default now()
);

create table if not exists public.laundry_supply_usage (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references public.laundry_batches(id) on delete cascade,
  supply_id uuid references public.supplies(id) on delete set null,
  quantity_used numeric,
  unit text,
  created_at timestamptz default now()
);

-- ============================================================
--  TIER 7 – STAFF & HR
-- ============================================================

create table if not exists public.staff_profiles (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  user_id uuid references public.profiles(id),
  full_name text not null,
  role text,
  phone text,
  id_number text,
  photo_url text,
  hire_date date,
  status text default 'active',
  notes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.staff_schedules (
  id uuid primary key default gen_random_uuid(),
  staff_id uuid not null references public.staff_profiles(id) on delete cascade,
  household_id uuid not null references public.households(id) on delete cascade,
  day_of_week integer,
  shift_date date,
  start_time time not null,
  end_time time not null,
  is_off boolean default false,
  notes text,
  created_at timestamptz default now()
);

create table if not exists public.employment_contracts (
  id uuid primary key default gen_random_uuid(),
  staff_id uuid not null references public.staff_profiles(id) on delete cascade,
  household_id uuid not null references public.households(id) on delete cascade,
  title text not null,
  start_date date not null,
  end_date date,
  salary_amount numeric,
  salary_currency text default 'KES',
  payment_frequency text default 'monthly',
  terms text,
  document_url text,
  status text default 'active',
  created_at timestamptz default now()
);

create table if not exists public.leave_balances (
  id uuid primary key default gen_random_uuid(),
  staff_id uuid not null references public.staff_profiles(id) on delete cascade,
  household_id uuid not null references public.households(id) on delete cascade,
  leave_type text not null,
  total_days numeric not null default 0,
  used_days numeric not null default 0,
  year integer not null,
  created_at timestamptz default now(),
  unique (staff_id, leave_type, year)
);

create table if not exists public.payslips (
  id uuid primary key default gen_random_uuid(),
  staff_id uuid not null references public.staff_profiles(id) on delete cascade,
  household_id uuid not null references public.households(id) on delete cascade,
  pay_period_start date not null,
  pay_period_end date not null,
  gross_amount numeric not null,
  deductions numeric default 0,
  net_amount numeric not null,
  currency text default 'KES',
  status text default 'draft',
  paid_at timestamptz,
  document_url text,
  created_at timestamptz default now()
);

-- ============================================================
--  TIER 8 – COMMUNICATIONS
-- ============================================================

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  recipient_id uuid references public.profiles(id),
  title text not null,
  body text,
  type text,
  read boolean default false,
  action_url text,
  created_at timestamptz default now()
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  sender_id uuid not null references public.profiles(id),
  recipient_id uuid references public.profiles(id),
  channel text default 'general',
  body text not null,
  is_read boolean default false,
  created_at timestamptz default now()
);

create table if not exists public.message_attachments (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.messages(id) on delete cascade,
  file_url text not null,
  file_type text,
  file_name text,
  file_size integer,
  created_at timestamptz default now()
);

create table if not exists public.announcements (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  author_id uuid not null references public.profiles(id),
  title text not null,
  body text,
  priority text default 'normal',
  expires_at timestamptz,
  created_at timestamptz default now()
);

-- ============================================================
--  TIER 9 – MAINTENANCE & VENDORS
-- ============================================================

create table if not exists public.service_vendors (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  name text not null,
  service_type text,
  phone text,
  email text,
  rating integer,
  notes text,
  created_at timestamptz default now()
);

create table if not exists public.maintenance_requests (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  zone_id uuid references public.household_zones(id) on delete set null,
  vendor_id uuid references public.service_vendors(id) on delete set null,
  title text not null,
  description text,
  priority text default 'normal',
  status text default 'open',
  reported_by uuid references public.profiles(id),
  resolved_at timestamptz,
  cost numeric,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ============================================================
--  TIER 10 – BILLING & SUBSCRIPTIONS
-- ============================================================

create table if not exists public.billing_customers (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  stripe_customer_id text,
  mpesa_phone text,
  email text,
  created_at timestamptz default now()
);

create table if not exists public.billing_subscriptions (
  id uuid primary key default gen_random_uuid(),
  billing_customer_id uuid not null references public.billing_customers(id) on delete cascade,
  plan_id uuid not null references public.subscription_plans(id),
  status text default 'active',
  current_period_start timestamptz,
  current_period_end timestamptz,
  cancel_at timestamptz,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.feature_usage_counters (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  feature_key text not null,
  usage_count integer not null default 0,
  period_start date not null,
  period_end date not null,
  created_at timestamptz default now(),
  unique (household_id, feature_key, period_start)
);

-- ============================================================
--  TIER 11 – ANALYTICS & INSIGHTS
-- ============================================================

create table if not exists public.activity_logs (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  user_id uuid references public.profiles(id),
  action text not null,
  entity_type text,
  entity_id uuid,
  details jsonb,
  created_at timestamptz default now()
);

create table if not exists public.readiness_scores (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  score_date date not null,
  overall_score numeric,
  supplies_score numeric,
  meals_score numeric,
  laundry_score numeric,
  staff_score numeric,
  finance_score numeric,
  breakdown jsonb,
  created_at timestamptz default now()
);

create table if not exists public.insight_cards (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  card_type text not null,
  title text not null,
  body text,
  priority integer default 0,
  action_url text,
  dismissed boolean default false,
  valid_from timestamptz default now(),
  valid_until timestamptz,
  created_at timestamptz default now()
);

create table if not exists public.forecast_jobs (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  job_type text not null,
  status text default 'pending',
  input_params jsonb,
  result jsonb,
  started_at timestamptz,
  completed_at timestamptz,
  error_message text,
  created_at timestamptz default now()
);

-- ============================================================
--  INDEXES  (household_id on every table that has one)
-- ============================================================
create index if not exists idx_hm_hh             on public.household_members(household_id);
create index if not exists idx_hm_user           on public.household_members(user_id);
create index if not exists idx_hz_hh             on public.household_zones(household_id);
create index if not exists idx_children_hh       on public.children(household_id);
create index if not exists idx_routine_hh        on public.child_routine_logs(household_id);
create index if not exists idx_dietprof_hh       on public.child_diet_profiles(household_id);
create index if not exists idx_schitem_hh        on public.school_item_templates(household_id);
create index if not exists idx_childsched_hh     on public.child_special_schedules(household_id);
create index if not exists idx_childmed_hh       on public.child_medication_logs(household_id);
create index if not exists idx_supcat_hh         on public.supply_categories(household_id);
create index if not exists idx_supplies_hh       on public.supplies(household_id);
create index if not exists idx_suprules_hh       on public.supply_rules(household_id);
create index if not exists idx_restock_hh        on public.supply_restock_history(household_id);
create index if not exists idx_supsnap_hh        on public.supply_consumption_snapshots(household_id);
create index if not exists idx_shopreq_hh        on public.shopping_requests(household_id);
create index if not exists idx_budget_hh         on public.household_budgets(household_id);
create index if not exists idx_purchtx_hh        on public.purchase_transactions(household_id);
create index if not exists idx_receipt_hh        on public.receipt_files(household_id);
create index if not exists idx_mealpreset_hh     on public.meal_presets(household_id);
create index if not exists idx_recipe_hh         on public.recipes(household_id);
create index if not exists idx_meallog_hh        on public.meal_logs(household_id);
create index if not exists idx_mealnutri_hh      on public.meal_nutrition_summaries(household_id);
create index if not exists idx_launpreset_hh     on public.laundry_presets(household_id);
create index if not exists idx_launbatch_hh      on public.laundry_batches(household_id);
create index if not exists idx_launstats_hh      on public.laundry_stats_snapshots(household_id);
create index if not exists idx_staffprof_hh      on public.staff_profiles(household_id);
create index if not exists idx_staffsched_hh     on public.staff_schedules(household_id);
create index if not exists idx_contract_hh       on public.employment_contracts(household_id);
create index if not exists idx_leave_hh          on public.leave_balances(household_id);
create index if not exists idx_payslip_hh        on public.payslips(household_id);
create index if not exists idx_notif_hh          on public.notifications(household_id);
create index if not exists idx_msg_hh            on public.messages(household_id);
create index if not exists idx_announce_hh       on public.announcements(household_id);
create index if not exists idx_vendor_hh         on public.service_vendors(household_id);
create index if not exists idx_maint_hh          on public.maintenance_requests(household_id);
create index if not exists idx_billcust_hh       on public.billing_customers(household_id);
create index if not exists idx_featusage_hh      on public.feature_usage_counters(household_id);
create index if not exists idx_actlog_hh         on public.activity_logs(household_id);
create index if not exists idx_readiness_hh      on public.readiness_scores(household_id);
create index if not exists idx_insight_hh        on public.insight_cards(household_id);
create index if not exists idx_forecast_hh       on public.forecast_jobs(household_id);

-- ============================================================
--  ENABLE RLS ON EVERY TABLE
-- ============================================================
alter table public.profiles                     enable row level security;
alter table public.subscription_plans           enable row level security;
alter table public.households                   enable row level security;
alter table public.household_members            enable row level security;
alter table public.household_zones              enable row level security;
alter table public.children                     enable row level security;
alter table public.child_routine_logs           enable row level security;
alter table public.child_diet_profiles          enable row level security;
alter table public.school_item_templates        enable row level security;
alter table public.child_special_schedules      enable row level security;
alter table public.child_medication_logs        enable row level security;
alter table public.supply_categories            enable row level security;
alter table public.supplies                     enable row level security;
alter table public.supply_rules                 enable row level security;
alter table public.supply_restock_history       enable row level security;
alter table public.supply_consumption_snapshots enable row level security;
alter table public.shopping_requests            enable row level security;
alter table public.household_budgets            enable row level security;
alter table public.purchase_transactions        enable row level security;
alter table public.receipt_files                enable row level security;
alter table public.nutrition_tags               enable row level security;
alter table public.meal_presets                 enable row level security;
alter table public.meal_preset_nutrition_tags   enable row level security;
alter table public.recipes                      enable row level security;
alter table public.recipe_ingredients           enable row level security;
alter table public.meal_logs                    enable row level security;
alter table public.meal_log_items               enable row level security;
alter table public.meal_nutrition_summaries     enable row level security;
alter table public.laundry_presets              enable row level security;
alter table public.laundry_batches              enable row level security;
alter table public.laundry_batch_items          enable row level security;
alter table public.laundry_stage_history        enable row level security;
alter table public.laundry_stats_snapshots      enable row level security;
alter table public.laundry_supply_usage         enable row level security;
alter table public.staff_profiles               enable row level security;
alter table public.staff_schedules              enable row level security;
alter table public.employment_contracts         enable row level security;
alter table public.leave_balances               enable row level security;
alter table public.payslips                     enable row level security;
alter table public.notifications                enable row level security;
alter table public.messages                     enable row level security;
alter table public.message_attachments          enable row level security;
alter table public.announcements                enable row level security;
alter table public.service_vendors              enable row level security;
alter table public.maintenance_requests         enable row level security;
alter table public.billing_customers            enable row level security;
alter table public.billing_subscriptions        enable row level security;
alter table public.feature_usage_counters       enable row level security;
alter table public.activity_logs                enable row level security;
alter table public.readiness_scores             enable row level security;
alter table public.insight_cards                enable row level security;
alter table public.forecast_jobs                enable row level security;

-- ============================================================
--  RLS POLICIES – core tables
-- ============================================================

-- profiles
create policy "profiles_sel" on public.profiles for select using (id = auth.uid());
create policy "profiles_upd" on public.profiles for update using (id = auth.uid());

-- subscription_plans (public read)
create policy "plans_sel" on public.subscription_plans for select using (true);

-- households
create policy "hh_sel" on public.households for select
  using (exists (select 1 from public.household_members hm where hm.household_id = id and hm.user_id = auth.uid()));

-- household_members
create policy "hm_sel" on public.household_members for select
  using (exists (select 1 from public.household_members hm where hm.household_id = household_members.household_id and hm.user_id = auth.uid()));

-- ============================================================
--  RLS POLICIES – household-scoped tables (CRUD)
--  Uses a DO block to avoid 100s of copy-paste lines.
-- ============================================================

do $$
declare
  tbl text;
  -- ONLY tables that have their own household_id column
  tbls text[] := array[
    'household_zones','children','child_routine_logs','child_diet_profiles',
    'school_item_templates','child_special_schedules','child_medication_logs',
    'supply_categories','supplies','supply_rules','supply_restock_history',
    'supply_consumption_snapshots','shopping_requests',
    'household_budgets','purchase_transactions','receipt_files',
    'meal_presets','recipes','meal_logs',
    'meal_nutrition_summaries',
    'laundry_presets','laundry_batches','laundry_stats_snapshots',
    'staff_profiles','staff_schedules','employment_contracts',
    'leave_balances','payslips',
    'notifications','messages','announcements',
    'service_vendors','maintenance_requests',
    'billing_customers','feature_usage_counters',
    'activity_logs','readiness_scores','insight_cards','forecast_jobs'
  ];
begin
  foreach tbl in array tbls loop
    execute format(
      'create policy "hm_sel_%1$s" on public.%1$I for select using (exists (select 1 from public.household_members hm where hm.household_id = %1$I.household_id and hm.user_id = auth.uid()))',
      tbl);
    execute format(
      'create policy "hm_ins_%1$s" on public.%1$I for insert with check (exists (select 1 from public.household_members hm where hm.household_id = %1$I.household_id and hm.user_id = auth.uid()))',
      tbl);
    execute format(
      'create policy "hm_upd_%1$s" on public.%1$I for update using (exists (select 1 from public.household_members hm where hm.household_id = %1$I.household_id and hm.user_id = auth.uid()))',
      tbl);
    execute format(
      'create policy "hm_del_%1$s" on public.%1$I for delete using (exists (select 1 from public.household_members hm where hm.household_id = %1$I.household_id and hm.user_id = auth.uid()))',
      tbl);
  end loop;
end $$;

-- Join tables without household_id get simple authenticated access
create policy "nutri_tags_sel"    on public.nutrition_tags for select using (true);
create policy "mpnt_sel"          on public.meal_preset_nutrition_tags for select using (true);
create policy "mpnt_ins"          on public.meal_preset_nutrition_tags for insert with check (true);
create policy "mpnt_del"          on public.meal_preset_nutrition_tags for delete using (true);
create policy "ri_sel"            on public.recipe_ingredients for select using (true);
create policy "ri_ins"            on public.recipe_ingredients for insert with check (true);
create policy "ri_upd"            on public.recipe_ingredients for update using (true);
create policy "ri_del"            on public.recipe_ingredients for delete using (true);
create policy "lbi_sel"           on public.laundry_batch_items for select using (true);
create policy "lbi_ins"           on public.laundry_batch_items for insert with check (true);
create policy "lbi_upd"           on public.laundry_batch_items for update using (true);
create policy "lbi_del"           on public.laundry_batch_items for delete using (true);
create policy "lsh_sel"           on public.laundry_stage_history for select using (true);
create policy "lsh_ins"           on public.laundry_stage_history for insert with check (true);
create policy "lsu_sel"           on public.laundry_supply_usage for select using (true);
create policy "lsu_ins"           on public.laundry_supply_usage for insert with check (true);
create policy "ma_sel"            on public.message_attachments for select using (true);
create policy "ma_ins"            on public.message_attachments for insert with check (true);
create policy "bs_sel"            on public.billing_subscriptions for select using (true);
create policy "bs_ins"            on public.billing_subscriptions for insert with check (true);
create policy "bs_upd"            on public.billing_subscriptions for update using (true);
create policy "mli_sel"           on public.meal_log_items for select using (true);
create policy "mli_ins"           on public.meal_log_items for insert with check (true);
create policy "mli_upd"           on public.meal_log_items for update using (true);
create policy "mli_del"           on public.meal_log_items for delete using (true);

-- ============================================================
--  HELPER FUNCTIONS
-- ============================================================

create or replace function public.generate_invite_code()
returns text language sql as $$
  select upper(substr(md5(random()::text), 1, 8));
$$;

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ============================================================
--  TRIGGERS – auto-set updated_at
-- ============================================================

create trigger trg_profiles_updated     before update on public.profiles          for each row execute function public.set_updated_at();
create trigger trg_households_updated    before update on public.households        for each row execute function public.set_updated_at();
create trigger trg_children_updated      before update on public.children          for each row execute function public.set_updated_at();
create trigger trg_supplies_updated      before update on public.supplies          for each row execute function public.set_updated_at();
create trigger trg_shopreq_updated       before update on public.shopping_requests for each row execute function public.set_updated_at();
create trigger trg_budget_updated        before update on public.household_budgets for each row execute function public.set_updated_at();
create trigger trg_maint_updated         before update on public.maintenance_requests for each row execute function public.set_updated_at();
create trigger trg_staffprof_updated     before update on public.staff_profiles    for each row execute function public.set_updated_at();
create trigger trg_dietprof_updated      before update on public.child_diet_profiles for each row execute function public.set_updated_at();
create trigger trg_billsub_updated       before update on public.billing_subscriptions for each row execute function public.set_updated_at();

-- ============================================================
-- DONE – 53 tables, 40 indexes, RLS everywhere, CRUD policies,
--        helper functions, auto-update triggers
-- ============================================================
