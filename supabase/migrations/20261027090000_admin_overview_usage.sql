-- Phase 10 (27 Oct 2026): numbers-only daily smoking/vaping totals in the
-- synced progress (latest proposal: daily total per participant code, no
-- times, triggers or notes), the admin Overview that restores progress lost
-- by participants (force majeure) and records every edit as an admin
-- intervention, and a server-side history of progress snapshots so a lost
-- copy can be restored. Run after phase 9.
begin;

-- ---------------------------------------------------------------------------
-- One validation for participant saves and admin edits.
create or replace function private.youwell_check_progress_payload(p_payload jsonb)
returns void language plpgsql stable set search_path = '' as $$
declare
  profile jsonb;
  field text;
  usage jsonb;
begin
  if p_payload is null or jsonb_typeof(p_payload) <> 'object'
     or octet_length(p_payload::text) > 2097152
     or (p_payload->>'schemaVersion') is distinct from '1'
     or (p_payload->>'version') is distinct from '3' then
    raise exception 'Invalid progress schema or payload size' using errcode = '22023';
  end if;
  if p_payload - array[
    'schemaVersion','version','profile','days','capacity','mobileRewards',
    'achievements','openedDays','activityDays','levelFloor','themeMode',
    'reduceMotion','haptics','companionAccessory','companionBackground',
    'workoutSessions','mealCheckIns','habitDelays','habitSwaps','usageTotals',
    'adminOpenedDays'
  ] <> '{}'::jsonb or not private.youwell_cloud_fields_safe(p_payload) then
    raise exception 'Device-only or unknown fields are not allowed' using errcode = '22023';
  end if;
  foreach field in array array['days','capacity','mobileRewards','achievements'] loop
    if jsonb_typeof(p_payload->field) is distinct from 'object' then
      raise exception 'Invalid progress map: %', field using errcode = '22023';
    end if;
  end loop;
  foreach field in array array['openedDays','activityDays','workoutSessions','mealCheckIns','habitDelays','habitSwaps'] loop
    if jsonb_typeof(p_payload->field) is distinct from 'array' then
      raise exception 'Invalid progress list: %', field using errcode = '22023';
    end if;
  end loop;
  -- Daily totals: numbers only (day, rokok/vape, 0-500, confirmed, source).
  if p_payload ? 'usageTotals' then
    if jsonb_typeof(p_payload->'usageTotals') <> 'array' then
      raise exception 'Invalid progress list: usageTotals' using errcode = '22023';
    end if;
    for usage in select jsonb_array_elements(p_payload->'usageTotals') loop
      if jsonb_typeof(usage) <> 'object'
         or usage - array['day','type','total','confirmed','source'] <> '{}'::jsonb
         or coalesce(usage->>'day', '') !~ '^\d{4}-\d{2}-\d{2}$'
         or coalesce(usage->>'type', '') not in ('rokok','vape')
         or jsonb_typeof(usage->'total') is distinct from 'number'
         or (usage->>'total')::numeric not between 0 and 500
         or (usage ? 'source' and usage->>'source' not in ('app','admin')) then
        raise exception 'Invalid usage total' using errcode = '22023';
      end if;
    end loop;
  end if;
  -- Days an admin marked as opened (force majeure restore), dates only.
  if p_payload ? 'adminOpenedDays' and (
       jsonb_typeof(p_payload->'adminOpenedDays') <> 'array'
       or exists (select 1 from jsonb_array_elements(p_payload->'adminOpenedDays') d
                  where jsonb_typeof(d) <> 'string' or d #>> '{}' !~ '^\d{4}-\d{2}-\d{2}$')) then
    raise exception 'Invalid progress list: adminOpenedDays' using errcode = '22023';
  end if;
  profile := p_payload->'profile';
  if profile is null then raise exception 'Profile field required' using errcode = '22023'; end if;
  if profile <> 'null'::jsonb then
    if jsonb_typeof(profile) <> 'object'
       or profile - array['alias','path','pace','lowImpact','companion','started','waterGoal','ageGroup','companionName'] <> '{}'::jsonb
       or coalesce(profile->>'alias','') !~ '^[a-zA-Z][a-zA-Z0-9_]{2,19}$'
       or coalesce(profile->>'path','') not in ('wellness','reduction')
       or (profile ? 'companionName' and (
             jsonb_typeof(profile->'companionName') <> 'string'
             or char_length(btrim(profile->>'companionName')) not between 1 and 20
             or profile->>'companionName' ~ '[[:cntrl:]]'
          )) then
      raise exception 'Invalid profile' using errcode = '22023';
    end if;
  end if;
end;
$$;
revoke all on function private.youwell_check_progress_payload(jsonb) from public, anon, authenticated;

-- Same behaviour as phase 6, now accepting usageTotals.
create or replace function public.save_youwell_progress(
  p_payload jsonb, p_expected_revision bigint
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  caller uuid := (select auth.uid());
  existing public.youwell_progress%rowtype;
  profile jsonb;
begin
  if caller is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  if p_expected_revision is null or p_expected_revision < 0 then
    raise exception 'Invalid revision' using errcode = '22023';
  end if;
  perform private.youwell_check_progress_payload(p_payload);
  profile := p_payload->'profile';

  -- Serialize even the first insert, where there is no row to lock yet.
  perform pg_advisory_xact_lock(hashtextextended(caller::text, 0));
  select * into existing from public.youwell_progress where user_id = caller for update;
  if coalesce(existing.revision, 0) <> p_expected_revision then
    if existing.revision is null then
      return jsonb_build_object('saved', false, 'snapshot', null);
    end if;
    return jsonb_build_object('saved', false, 'snapshot',
      jsonb_build_object('revision', existing.revision, 'payload', existing.payload, 'updated_at', existing.updated_at));
  end if;

  insert into public.youwell_progress as target(user_id, revision, payload, updated_at)
  values(caller, p_expected_revision + 1, p_payload, now())
  on conflict (user_id) do update
    set revision = excluded.revision, payload = excluded.payload, updated_at = excluded.updated_at
  returning * into existing;

  if profile = 'null'::jsonb then
    delete from public.youwell_profiles where user_id = caller;
  else
    insert into public.youwell_profiles(user_id, alias)
    values(caller, profile->>'alias')
    on conflict (user_id) do update set alias = excluded.alias;
    update public.youwell_posts set alias = profile->>'alias'
    where author = caller and alias is distinct from profile->>'alias';
  end if;
  return jsonb_build_object('saved', true, 'snapshot',
    jsonb_build_object('revision', existing.revision, 'payload', existing.payload, 'updated_at', existing.updated_at));
end;
$$;
revoke all on function public.save_youwell_progress(jsonb,bigint) from public, anon, authenticated;
grant execute on function public.save_youwell_progress(jsonb,bigint) to authenticated;

-- ---------------------------------------------------------------------------
-- History: the previous snapshot is kept on every change (60 per account),
-- so progress overwritten from a reinstalled phone can be restored.
create table if not exists public.youwell_progress_history (
  user_id uuid not null references auth.users(id) on delete cascade,
  revision bigint not null,
  payload jsonb not null,
  saved_at timestamptz not null,
  primary key (user_id, revision)
);
alter table public.youwell_progress_history enable row level security;
revoke all on public.youwell_progress_history from public, anon, authenticated;

create or replace function private.youwell_keep_progress_history()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if old.payload is distinct from new.payload then
    insert into public.youwell_progress_history(user_id, revision, payload, saved_at)
    values (old.user_id, old.revision, old.payload, old.updated_at)
    on conflict (user_id, revision) do nothing;
    delete from public.youwell_progress_history h
    where h.user_id = old.user_id
      and h.revision not in (
        select k.revision from public.youwell_progress_history k
        where k.user_id = old.user_id order by k.revision desc limit 60
      );
  end if;
  return new;
end;
$$;
revoke all on function private.youwell_keep_progress_history() from public, anon, authenticated;
drop trigger if exists youwell_progress_history on public.youwell_progress;
create trigger youwell_progress_history before update on public.youwell_progress
  for each row execute function private.youwell_keep_progress_history();

-- ---------------------------------------------------------------------------
-- Admin interventions: every admin edit with its reason, kept on the server
-- even if the participant's phone later overwrites the progress.
create table if not exists public.youwell_admin_interventions (
  id uuid primary key default gen_random_uuid(),
  account uuid not null references auth.users(id) on delete cascade,
  admin uuid references auth.users(id) on delete set null,
  revision bigint not null,
  reason text not null check (char_length(btrim(reason)) between 5 and 500),
  changes jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);
alter table public.youwell_admin_interventions enable row level security;
revoke all on public.youwell_admin_interventions from public, anon, authenticated;

-- Writes an edited snapshot for a participant; the phone picks it up on its
-- next sync. The profile cannot be changed this way.
create or replace function public.admin_write_youwell_progress(
  p_account uuid, p_expected_revision bigint, p_payload jsonb,
  p_reason text, p_changes jsonb
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare existing public.youwell_progress%rowtype;
begin
  perform private.youwell_require_admin();
  if char_length(btrim(coalesce(p_reason, ''))) not between 5 and 500 then
    raise exception 'Reason required' using errcode = '22023';
  end if;
  perform private.youwell_check_progress_payload(p_payload);
  perform pg_advisory_xact_lock(hashtextextended(p_account::text, 0));
  select * into existing from public.youwell_progress where user_id = p_account for update;
  if existing.user_id is null then
    raise exception 'No progress for this account' using errcode = 'P0002';
  end if;
  if existing.revision <> p_expected_revision then
    return jsonb_build_object('saved', false, 'revision', existing.revision);
  end if;
  if (p_payload->'profile') is distinct from (existing.payload->'profile') then
    raise exception 'Profile cannot be changed by admin' using errcode = '22023';
  end if;
  update public.youwell_progress
  set revision = existing.revision + 1, payload = p_payload, updated_at = now()
  where user_id = p_account;
  insert into public.youwell_admin_interventions(account, admin, revision, reason, changes)
  values (p_account, (select auth.uid()), existing.revision + 1, btrim(p_reason),
          coalesce(p_changes, '[]'::jsonb));
  return jsonb_build_object('saved', true, 'revision', existing.revision + 1);
end;
$$;
revoke all on function public.admin_write_youwell_progress(uuid,bigint,jsonb,text,jsonb) from public, anon, authenticated;
grant execute on function public.admin_write_youwell_progress(uuid,bigint,jsonb,text,jsonb) to authenticated;

-- Admin: every intervention, newest first, with code and alias only.
create or replace function public.youwell_admin_interventions()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.youwell_require_admin();
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', i.id, 'account', i.account, 'code', c.code,
      'alias', coalesce(p.alias, 'peserta'), 'revision', i.revision,
      'reason', i.reason, 'changes', i.changes, 'created_at', i.created_at
    ) order by i.created_at desc)
    from public.youwell_admin_interventions i
    left join public.youwell_profiles p on p.user_id = i.account
    left join public.youwell_participant_codes c on c.user_id = i.account
  ), '[]'::jsonb);
end;
$$;
revoke all on function public.youwell_admin_interventions() from public, anon, authenticated;
grant execute on function public.youwell_admin_interventions() to authenticated;

-- Admin: earlier snapshots of one account, newest first, with the number of
-- finished quests so the right one can be picked.
create or replace function public.youwell_admin_progress_history(p_account uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.youwell_require_admin();
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'revision', h.revision, 'saved_at', h.saved_at,
      'quests_done', jsonb_array_length(jsonb_path_query_array(
        h.payload, '$.days.*.quests[*] ? (@.status == "completed")')),
      'days', (select count(*) from jsonb_object_keys(
        coalesce(h.payload->'days', '{}'::jsonb)))
    ) order by h.revision desc)
    from public.youwell_progress_history h
    where h.user_id = p_account
  ), '[]'::jsonb);
end;
$$;
revoke all on function public.youwell_admin_progress_history(uuid) from public, anon, authenticated;
grant execute on function public.youwell_admin_progress_history(uuid) to authenticated;

-- Admin: puts an earlier snapshot back as the newest one (an intervention).
create or replace function public.admin_restore_youwell_revision(
  p_account uuid, p_revision bigint, p_reason text
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  existing public.youwell_progress%rowtype;
  earlier jsonb;
begin
  perform private.youwell_require_admin();
  if char_length(btrim(coalesce(p_reason, ''))) not between 5 and 500 then
    raise exception 'Reason required' using errcode = '22023';
  end if;
  select payload into earlier from public.youwell_progress_history
  where user_id = p_account and revision = p_revision;
  if earlier is null then raise exception 'No such snapshot' using errcode = 'P0002'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_account::text, 0));
  select * into existing from public.youwell_progress where user_id = p_account for update;
  if existing.user_id is null then
    raise exception 'No progress for this account' using errcode = 'P0002';
  end if;
  update public.youwell_progress
  set revision = existing.revision + 1, payload = earlier, updated_at = now()
  where user_id = p_account;
  insert into public.youwell_admin_interventions(account, admin, revision, reason, changes)
  values (p_account, (select auth.uid()), existing.revision + 1, btrim(p_reason),
          jsonb_build_array(jsonb_build_object('kind', 'restore', 'from_revision', p_revision)));
  return jsonb_build_object('saved', true, 'revision', existing.revision + 1);
end;
$$;
revoke all on function public.admin_restore_youwell_revision(uuid,bigint,text) from public, anon, authenticated;
grant execute on function public.admin_restore_youwell_revision(uuid,bigint,text) to authenticated;

-- The overview also needs the revision, for safe concurrent edits.
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
