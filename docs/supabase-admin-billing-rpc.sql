-- ============================================================
-- homeFlow – Admin billing RPC for app_households plan actions
-- Run this after supabase-admin-panel.sql and supabase-app-sync.sql
-- ============================================================

create or replace function public.admin_apply_household_plan_action(
  target_household_id uuid,
  target_plan_code text,
  target_plan_status text,
  target_plan_expires_at timestamptz default null,
  adjustment_type text default 'upgrade',
  action_notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  acting_admin_id uuid;
  previous_plan_code text;
  previous_plan_status text;
begin
  if (auth.jwt() ->> 'app_role') <> 'admin' then
    raise exception 'Admin privileges required';
  end if;

  select id
  into acting_admin_id
  from public.admin_users
  where profile_id = auth.uid()
    and status = 'active'
  limit 1;

  if acting_admin_id is null then
    raise exception 'No active admin_users row found for %', auth.uid();
  end if;

  if target_plan_code not in ('free', 'home_pro') then
    raise exception 'Unsupported target_plan_code: %', target_plan_code;
  end if;

  if target_plan_status not in ('active', 'grace_period', 'expired', 'cancelled') then
    raise exception 'Unsupported target_plan_status: %', target_plan_status;
  end if;

  select plan_code, plan_status
  into previous_plan_code, previous_plan_status
  from public.app_households
  where id = target_household_id
  for update;

  if not found then
    raise exception 'app_households row % not found', target_household_id;
  end if;

  update public.app_households
  set plan_code = target_plan_code,
      plan_status = target_plan_status,
      plan_expires_at = target_plan_expires_at
  where id = target_household_id;

  insert into public.admin_activity_logs (
    admin_user_id,
    action,
    entity_type,
    metadata
  )
  values (
    acting_admin_id,
    case adjustment_type
      when 'trial' then 'Applied Home Pro trial'
      when 'suspend_paid_features' then 'Suspended paid features'
      else 'Updated household plan'
    end,
    'app_household',
    jsonb_build_object(
      'app_household_id', target_household_id,
      'adjustment_type', adjustment_type,
      'previous_plan_code', previous_plan_code,
      'previous_plan_status', previous_plan_status,
      'target_plan_code', target_plan_code,
      'target_plan_status', target_plan_status,
      'target_plan_expires_at', target_plan_expires_at,
      'notes', action_notes
    )
  );

  return jsonb_build_object(
    'ok', true,
    'message', format(
      'Updated household %s to %s (%s)',
      target_household_id,
      target_plan_code,
      target_plan_status
    )
  );
end;
$$;

revoke all on function public.admin_apply_household_plan_action(uuid, text, text, timestamptz, text, text) from public;
grant execute on function public.admin_apply_household_plan_action(uuid, text, text, timestamptz, text, text) to authenticated;