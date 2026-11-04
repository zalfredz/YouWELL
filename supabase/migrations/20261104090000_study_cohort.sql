-- Phase 11 (4 Nov 2026): lock each participant's study group when the code
-- P1-P10 is assigned. The profile only holds the current path, so someone who
-- switched path later would land in the wrong group in the research
-- dashboard. The path, start date and measurement-rules version at
-- assignment are kept; changing the code number keeps them. Run after
-- phase 10.
begin;

alter table public.youwell_participant_codes
  add column if not exists study_path text
    check (study_path in ('wellness','reduction')),
  add column if not exists study_started date,
  add column if not exists measurement_version text;

-- Codes assigned before this phase: take today's profile, marked as a
-- backfill so the research team can check those participants by hand.
update public.youwell_participant_codes c
set study_path = coalesce(c.study_path,
      case when p.payload->'profile'->>'path' in ('wellness','reduction')
           then p.payload->'profile'->>'path' end),
    study_started = coalesce(c.study_started,
      case when p.payload->'profile'->>'started' ~ '^\d{4}-\d{2}-\d{2}$'
           then (p.payload->'profile'->>'started')::date end),
    measurement_version = coalesce(c.measurement_version, 'backfill-2026-11-04')
from public.youwell_progress p
where p.user_id = c.user_id;

-- Same checks as phase 6; a first assignment also records the study group.
create or replace function public.set_youwell_participant_code(
  p_account uuid, p_code text
)
returns void language plpgsql security definer set search_path = '' as $$
declare profile jsonb;
begin
  perform private.youwell_require_admin();
  if p_code is null then
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
  select p.payload->'profile' into profile
  from public.youwell_progress p where p.user_id = p_account;
  insert into public.youwell_participant_codes(
    user_id, code, study_path, study_started, measurement_version)
  values (
    p_account, p_code,
    case when profile->>'path' in ('wellness','reduction') then profile->>'path' end,
    case when profile->>'started' ~ '^\d{4}-\d{2}-\d{2}$'
         then (profile->>'started')::date end,
    'v2026-11-04'
  )
  -- A group already locked stays; one still empty (no progress synced at
  -- the first assignment) is filled now.
  on conflict (user_id) do update set
    code = excluded.code,
    assigned_at = now(),
    study_path = coalesce(public.youwell_participant_codes.study_path, excluded.study_path),
    study_started = coalesce(public.youwell_participant_codes.study_started, excluded.study_started),
    measurement_version = case
      when public.youwell_participant_codes.study_path is null then excluded.measurement_version
      else public.youwell_participant_codes.measurement_version end;
end;
$$;
revoke all on function public.set_youwell_participant_code(uuid, text) from public, anon, authenticated;
grant execute on function public.set_youwell_participant_code(uuid, text) to authenticated;

-- Phase 10 overview plus the locked study group.
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
      'study_path', c.study_path,
      'study_started', c.study_started,
      'measurement_version', c.measurement_version,
      'payload', p.payload
    ) order by c.code nulls last, p.updated_at desc)
    from public.youwell_progress p
    left join public.youwell_profiles pr on pr.user_id = p.user_id
    left join public.youwell_participant_codes c on c.user_id = p.user_id
  ), '[]'::jsonb);
end;
$$;
revoke all on function public.youwell_admin_progress_overview() from public, anon, authenticated;
grant execute on function public.youwell_admin_progress_overview() to authenticated;

commit;
