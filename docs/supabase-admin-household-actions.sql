-- ============================================================
-- HomeFlow – Admin household RPCs for invite and creation actions
-- Run this after supabase-admin-panel.sql and supabase-app-sync.sql
-- ============================================================

create or replace function public.admin_create_household(
  target_household_name text,
  target_invite_code text,
  target_plan_code text default 'free'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  acting_admin_id uuid;
  created_household_id uuid;
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

  if coalesce(trim(target_household_name), '') = '' then
    raise exception 'target_household_name is required';
  end if;

  if target_plan_code not in ('free', 'home_pro') then
    raise exception 'Unsupported target_plan_code: %', target_plan_code;
  end if;

  insert into public.app_households (
    household_name,
    invite_code,
    owner_user_id,
    plan_code,
    plan_status
  )
  values (
    trim(target_household_name),
    upper(trim(target_invite_code)),
    null,
    target_plan_code,
    'active'
  )
  returning id into created_household_id;

  insert into public.admin_activity_logs (
    admin_user_id,
    action,
    entity_type,
    metadata
  )
  values (
    acting_admin_id,
    'Created household',
    'app_household',
    jsonb_build_object(
      'app_household_id', created_household_id,
      'household_name', trim(target_household_name),
      'invite_code', upper(trim(target_invite_code)),
      'plan_code', target_plan_code
    )
  );

  return jsonb_build_object(
    'ok', true,
    'household_id', created_household_id,
    'invite_code', upper(trim(target_invite_code)),
    'message', format('Created household %s', trim(target_household_name))
  );
end;
$$;

create or replace function public.admin_reset_household_invite_code(
  target_household_id uuid,
  new_invite_code text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  acting_admin_id uuid;
  household_name text;
  previous_invite_code text;
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

  update public.app_households
  set invite_code = upper(trim(new_invite_code))
  where id = target_household_id
  returning household_name, invite_code into household_name, previous_invite_code;

  if household_name is null then
    raise exception 'app_households row % not found', target_household_id;
  end if;

  insert into public.admin_activity_logs (
    admin_user_id,
    action,
    entity_type,
    metadata
  )
  values (
    acting_admin_id,
    'Reset household invite code',
    'app_household',
    jsonb_build_object(
      'app_household_id', target_household_id,
      'household_name', household_name,
      'invite_code', upper(trim(new_invite_code))
    )
  );

  return jsonb_build_object(
    'ok', true,
    'household_id', target_household_id,
    'invite_code', upper(trim(new_invite_code)),
    'message', format('Reset invite code for %s', household_name)
  );
end;
$$;

revoke all on function public.admin_create_household(text, text, text) from public;
grant execute on function public.admin_create_household(text, text, text) to authenticated;

revoke all on function public.admin_reset_household_invite_code(uuid, text) from public;
grant execute on function public.admin_reset_household_invite_code(uuid, text) to authenticated;