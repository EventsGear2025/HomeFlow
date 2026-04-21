## Supabase rollout plan

This document captures the next-stage cloud migration for `homeFlow`.

### Environment

- Project URL: `https://gmjttroimogdelumblgb.supabase.co`
- Client publishable key: configured in `lib/services/supabase_config.dart`
- Service role key: never ship in Flutter client apps

### Phase 1 goals

- Keep the app usable while backend integration is introduced
- Support Supabase initialization and session-aware login
- Preserve the owner/manager product model
- Prepare a safe schema for invite-code household membership

### SQL schema draft

```sql
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null unique,
  full_name text not null,
  role text not null check (role in ('owner', 'house_manager')),
  created_at timestamptz not null default now()
);

create table if not exists public.households (
  id uuid primary key default gen_random_uuid(),
  household_name text not null,
  owner_user_id uuid not null references public.profiles(id) on delete cascade,
  invite_code text not null unique,
  created_at timestamptz not null default now()
);

create table if not exists public.household_members (

## SQL Schema for Supabase (Full Feature Set)

### Core Tables (already created)
See previous section for `profiles`, `households`, `household_members`.

---

### Feature Tables

```sql
-- SUPPLIES (Inventory)
create table if not exists supplies (
  id uuid primary key default gen_random_uuid(),
  household_id uuid references households(id) on delete cascade,
  name text not null,
  category text,
  quantity integer not null default 0,
  unit text,
  min_required integer default 0,
  notes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- GAS (Fuel Tracking)
create table if not exists gas (
  id uuid primary key default gen_random_uuid(),
  household_id uuid references households(id) on delete cascade,
  amount_liters numeric,
  cost numeric,
  filled_at timestamptz default now(),
  notes text,
  created_by uuid references profiles(id),
  created_at timestamptz default now()
);

-- MEALS (Meal Planning/Logs)
create table if not exists meals (
  id uuid primary key default gen_random_uuid(),
  household_id uuid references households(id) on delete cascade,
  meal_date date not null,
  meal_type text, -- breakfast/lunch/dinner/snack
  description text,
  prepared_by uuid references profiles(id),
  notes text,
  created_at timestamptz default now()
);

-- KIDS (Children's Info)
create table if not exists kids (
  id uuid primary key default gen_random_uuid(),
  household_id uuid references households(id) on delete cascade,
  name text not null,
  birthdate date,
  gender text,
  notes text,
  created_at timestamptz default now()
);

-- LAUNDRY (Laundry Tracking)
create table if not exists laundry (
  id uuid primary key default gen_random_uuid(),
  household_id uuid references households(id) on delete cascade,
  kid_id uuid references kids(id),
  date date not null,
  status text, -- pending/done
  notes text,
  created_at timestamptz default now()
);

-- STAFF (Staff/Volunteers)
create table if not exists staff (
  id uuid primary key default gen_random_uuid(),
  household_id uuid references households(id) on delete cascade,
  profile_id uuid references profiles(id),
  role text, -- e.g. manager, volunteer
  joined_at timestamptz default now(),
  left_at timestamptz,
  notes text
);

-- NOTIFICATIONS (System/User Notifications)
create table if not exists notifications (
  id uuid primary key default gen_random_uuid(),
  household_id uuid references households(id) on delete cascade,
  recipient_id uuid references profiles(id),
  title text not null,
  body text,
  type text, -- info/warning/alert
  read boolean default false,
  created_at timestamptz default now()
);

-- TASKS (Chores/Assignments)
create table if not exists tasks (
  id uuid primary key default gen_random_uuid(),
  household_id uuid references households(id) on delete cascade,
  title text not null,
  description text,
  assigned_to uuid references profiles(id),
  due_date date,
  status text default 'pending',
  completed_at timestamptz,
  created_at timestamptz default now()
);

-- ATTENDANCE (Presence Logs)
create table if not exists attendance (
  id uuid primary key default gen_random_uuid(),
  household_id uuid references households(id) on delete cascade,
  profile_id uuid references profiles(id),
  date date not null,
  status text, -- present/absent
  notes text,
  created_at timestamptz default now()
);

-- ACTIVITY_LOG (Auditing)
create table if not exists activity_log (
  id uuid primary key default gen_random_uuid(),
  household_id uuid references households(id) on delete cascade,
  profile_id uuid references profiles(id),
  action text not null,
  details jsonb,
  created_at timestamptz default now()
);

-- Indexes (for performance)
create index if not exists idx_supplies_household on supplies(household_id);
create index if not exists idx_gas_household on gas(household_id);
create index if not exists idx_meals_household on meals(household_id);
create index if not exists idx_kids_household on kids(household_id);
create index if not exists idx_laundry_household on laundry(household_id);
create index if not exists idx_staff_household on staff(household_id);
create index if not exists idx_notifications_household on notifications(household_id);
create index if not exists idx_tasks_household on tasks(household_id);
create index if not exists idx_attendance_household on attendance(household_id);
create index if not exists idx_activitylog_household on activity_log(household_id);

-- Row Level Security (RLS) Policies
alter table supplies enable row level security;
alter table gas enable row level security;
alter table meals enable row level security;
alter table kids enable row level security;
alter table laundry enable row level security;
alter table staff enable row level security;
alter table notifications enable row level security;
alter table tasks enable row level security;
alter table attendance enable row level security;
alter table activity_log enable row level security;

-- Example RLS: Allow access to rows for users in the same household
create policy "Household members can access supplies" on supplies
  for select using (exists (
    select 1 from household_members
    where household_members.household_id = supplies.household_id
      and household_members.profile_id = auth.uid()
  ));

-- Repeat similar policies for other tables as needed
-- (You can copy/adapt the above for each table)
```

---

Paste the above SQL into the Supabase SQL Editor to create all required tables for your app modules.
```

### Suggested row-level security direction

1. Enable RLS on all three tables.
2. Allow authenticated users to read their own `profiles` row.
3. Allow owners to read and manage rows in their own household.
4. Allow managers to read their linked household and member rows.
5. Restrict `households.owner_user_id` updates to service-level workflows only.

### Immediate app-side work after this document

1. Add session restore from Supabase in `AuthProvider`.
2. Add `Profile` and `HouseholdMember` repositories for Supabase reads.
3. Replace local sign-up/login for non-demo accounts.
4. Add a dedicated invite-code validation query against Supabase.

### Migration note

The app still contains a local/demo fallback path for development continuity.
That path should be removed after the Supabase owner/manager flow is fully live.
