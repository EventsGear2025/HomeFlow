# Admin panel backend notes

This file explains the **extra Supabase tables** needed for the Flutter web admin console.

## What this adds

Run `docs/supabase-admin-panel.sql` **after** your main product schema (`docs/supabase-all-tables.sql`).

It adds backend support for:

- admin roles and internal admin users
- permission overrides
- support issues and internal comments
- notification templates and delivery logs
- household plan adjustments and feature limit overrides
- admin activity/audit logs
- system alerts and failed background jobs

## Tables included

### Access control
- `admin_roles`
- `admin_users`
- `admin_permissions_overrides`

### Support
- `support_issue_categories`
- `support_issues`
- `support_issue_comments`

### Notifications
- `notification_templates`
- `notification_delivery_logs`

### Billing / plan operations
- `household_plan_adjustments`
- `household_feature_limits`

### Audit / operations
- `admin_activity_logs`
- `system_alerts`
- `failed_jobs`

## Important assumptions

This schema assumes your main app schema already has:

- `public.profiles`
- `public.households`
- `public.notifications`

Those were part of the earlier full app schema.

## RLS note

The SQL enables RLS on all admin tables, but only includes a few **starter select policies**.

Recommended production setup:

1. mark internal staff accounts with a custom JWT claim like:
   - `app_role = admin`
2. add full insert/update/delete policies for admin workflows
3. do not expose these tables to standard household users

## Suggested next step

After running the SQL in Supabase, the next best step is wiring the Flutter admin pages to live queries instead of mock data.

Priority order:

1. `admin_users`
2. `support_issues`
3. `admin_activity_logs`
4. `notification_templates`
5. `household_plan_adjustments`

## Demo seed data for the web admin

There is now a companion file:

- `docs/supabase-admin-seed.sql`

Run it after:

1. `docs/supabase-all-tables.sql`
2. `docs/supabase-admin-panel.sql`

It seeds realistic demo records for:

- subscription plans
- admin users
- support issues and comments
- notification templates and delivery logs
- household plan adjustments
- household feature limits
- admin activity logs
- system alerts
- failed jobs

## Important constraint for seeding

In your current schema, `profiles.id` references `auth.users(id)`.

That means the profile demo rows in the seed file must use **real Auth user IDs** from Supabase Auth.

The seed file now ships in a **safe default mode**.

That means:

- auth-independent inserts run immediately
- auth-dependent inserts are commented out on purpose
- safe-mode alerts/jobs also avoid household foreign keys

Before enabling the full household demo dataset in `docs/supabase-admin-seed.sql`:

1. create the demo users in Supabase Auth
2. copy their Auth UUIDs
3. replace the placeholder profile UUIDs in the seed file
4. uncomment the auth-dependent blocks

If you skip that step, the profile inserts would fail due to the foreign key to `auth.users`.

## Fastest route to see the admin panel with Supabase data

Use this order:

1. run the base schema
2. run the admin schema
3. run the seed file once in safe mode for admin-only records
4. create demo Auth users
5. replace the placeholder UUIDs in `docs/supabase-admin-seed.sql`
6. uncomment the auth-dependent blocks
7. run the remaining seed sections
8. wire the admin Flutter pages to query these tables

## Example internal seed flow

After SQL runs successfully, create one internal admin row tied to a real profile:

- create/select a profile in `profiles`
- insert that profile into `admin_users`
- assign a role from `admin_roles`
- issue auth tokens with `app_role=admin`

## Why separate admin tables

Keeping admin operations separate from household-facing tables makes it easier to:

- audit internal actions
- protect sensitive workflows with stricter RLS
- track manual plan changes and support handling
- power admin dashboards without overloading user tables
