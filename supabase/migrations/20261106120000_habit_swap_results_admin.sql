-- Phase 14 (6 Nov 2026): an admin can restore Habit Swap results per day
-- in the Overview, as an admin intervention. Phase 13 validation plus an
-- optional `source` ('app' or 'admin') on each `swapResults` row, so the
-- research export can tell restored results apart. Run after phase 13.
begin;

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
    'adminOpenedDays','swapResults'
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
  -- Habit Swap results per day and product: counts only (phase 13), with
  -- an optional source marking admin restores (phase 14).
  if p_payload ? 'swapResults' then
    if jsonb_typeof(p_payload->'swapResults') <> 'array' then
      raise exception 'Invalid progress list: swapResults' using errcode = '22023';
    end if;
    for usage in select jsonb_array_elements(p_payload->'swapResults') loop
      if jsonb_typeof(usage) <> 'object'
         or usage - array['day','type','tried','skipped','used','source'] <> '{}'::jsonb
         or (usage ? 'source' and usage->>'source' not in ('app','admin'))
         or coalesce(usage->>'day', '') !~ '^\d{4}-\d{2}-\d{2}$'
         or coalesce(usage->>'type', '') not in ('rokok','vape')
         or jsonb_typeof(usage->'tried') is distinct from 'number'
         or jsonb_typeof(usage->'skipped') is distinct from 'number'
         or jsonb_typeof(usage->'used') is distinct from 'number'
         or (usage->>'tried')::numeric not between 0 and 200
         or (usage->>'skipped')::numeric not between 0 and 200
         or (usage->>'used')::numeric not between 0 and 200 then
        raise exception 'Invalid Habit Swap result' using errcode = '22023';
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

commit;
