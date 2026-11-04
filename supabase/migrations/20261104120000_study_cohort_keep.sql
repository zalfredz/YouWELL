-- Phase 12 (4 Nov 2026): the study group survives removing a participant
-- code. Phase 11 kept it on the code row, so removing a code and assigning
-- it again re-locked the group from the profile's current path. The group
-- now lives in its own table, written once per account and only filled in
-- while still empty; removing a code no longer touches it. Run after
-- phase 11.
begin;

create table if not exists public.youwell_study_cohorts (
  user_id uuid primary key references auth.users(id) on delete cascade,
  study_path text check (study_path in ('wellness','reduction')),
  study_started date,
  measurement_version text,
  locked_at timestamptz not null default now()
);
alter table public.youwell_study_cohorts enable row level security;
revoke all on public.youwell_study_cohorts from public, anon, authenticated;

-- Groups already locked by phase 11.
insert into public.youwell_study_cohorts(user_id, study_path, study_started, measurement_version)
select user_id, study_path, study_started, measurement_version
from public.youwell_participant_codes
where study_path is not null
on conflict (user_id) do nothing;

create or replace function public.set_youwell_participant_code(
  p_account uuid, p_code text
)
returns void language plpgsql security definer set search_path = '' as $$
declare profile jsonb;
begin
  perform private.youwell_require_admin();
  if p_code is null then
    -- Only the code goes; the study group stays for a later assignment.
    delete from public.youwell_participant_codes where user_id = p_account;
    return;
  end if;
  if p_code !~ '^P([1-9]|10)$' then
    raise exception 'Invalid participant code' using errcode = '22023';
  end if;
  if exists (select 1 from public.youwell_participant_codes
             where code = p_code and user_id <> p_account) then
    raise exception 'Code already assigned' using errcode = '23505';
  end if;
  insert into public.youwell_participant_codes(user_id, code)
  values (p_account, p_code)
  on conflict (user_id) do update set code = excluded.code, assigned_at = now();

  select p.payload->'profile' into profile
  from public.youwell_progress p where p.user_id = p_account;
  insert into public.youwell_study_cohorts(user_id, study_path, study_started, measurement_version)
  values (
    p_account,
    case when profile->>'path' in ('wellness','reduction') then profile->>'path' end,
    case when profile->>'started' ~ '^\d{4}-\d{2}-\d{2}$'
         then (profile->>'started')::date end,
    'v2026-11-04'
  )
  -- A locked group stays; one still empty (nothing synced at the first
  -- assignment) is filled now.
  on conflict (user_id) do update set
    study_path = coalesce(public.youwell_study_cohorts.study_path, excluded.study_path),
    study_started = coalesce(public.youwell_study_cohorts.study_started, excluded.study_started),
    measurement_version = case
      when public.youwell_study_cohorts.study_path is null then excluded.measurement_version
      else public.youwell_study_cohorts.measurement_version end;
end;
$$;
revoke all on function public.set_youwell_participant_code(uuid, text) from public, anon, authenticated;
grant execute on function public.set_youwell_participant_code(uuid, text) to authenticated;

create or replace function public.youwell_admin_progress_overview()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.youwell_require_admin();
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'account', p.user_id,
      'code', c.code,
      'alias', coalesce(pr.alias, p.payload->'profile'->>'alias'),
      'updated_at', p.updated_at,
      'revision', p.revision,
      'study_path', s.study_path,
      'study_started', s.study_started,
      'measurement_version', s.measurement_version,
      'payload', p.payload
    ) order by c.code nulls last, p.updated_at desc)
    from public.youwell_progress p
    left join public.youwell_profiles pr on pr.user_id = p.user_id
    left join public.youwell_participant_codes c on c.user_id = p.user_id
    left join public.youwell_study_cohorts s on s.user_id = p.user_id
  ), '[]'::jsonb);
end;
$$;
revoke all on function public.youwell_admin_progress_overview() from public, anon, authenticated;
grant execute on function public.youwell_admin_progress_overview() to authenticated;

commit;
