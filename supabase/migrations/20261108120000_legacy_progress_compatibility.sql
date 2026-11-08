-- Phase 15: accept compatible v3 clients without disabling payload validation.
-- Run after phase 14. Existing rows are untouched until their next save.
-- Missing/empty optional collections get defaults; nonempty malformed values
-- still fail. Private/unknown fields are projected out before strict checking.
begin;

create or replace function private.youwell_strip_legacy_fields(value jsonb)
returns jsonb language plpgsql immutable set search_path = '' as $$
declare result jsonb; entry record;
begin
  if jsonb_typeof(value) = 'object' then
    result := '{}'::jsonb;
    for entry in select * from jsonb_each(value) loop
      if lower(entry.key) = any(array[
        'photopath','photo','image','bytes','base64','latitude','longitude',
        'coordinates','route','note','noteeditedat','email','user_id',
        'researchparticipation','participant_code','access_token','refresh_token',
        'product','trigger','triggers','outcome','activity','activities','eventid',
        'cigarette','vape','nicotinedays','reductionsettings','reductionplans',
        'reductiontargets','reductionsetup','sleeplogs','opensleep','bedat','wakeat',
        'activeswapmoment','customtriggers','customactivities','usedproduct'
      ]) then continue; end if;
      result := result || jsonb_build_object(entry.key, private.youwell_strip_legacy_fields(entry.value));
    end loop;
    return result;
  elsif jsonb_typeof(value) = 'array' then
    select coalesce(jsonb_agg(private.youwell_strip_legacy_fields(item)), '[]'::jsonb)
    into result from jsonb_array_elements(value) item;
    return result;
  end if;
  return value;
end;
$$;
revoke all on function private.youwell_strip_legacy_fields(jsonb) from public, anon, authenticated;

create or replace function private.youwell_normalize_progress(value jsonb)
returns jsonb language plpgsql stable set search_path = '' as $$
declare result jsonb := '{}'::jsonb; field text; entry record; profile jsonb;
  totals jsonb := '[]'::jsonb; usage jsonb; day_value date;
begin
  if value is null or jsonb_typeof(value) <> 'object'
     or octet_length(value::text) > 2097152
     or (value->>'schemaVersion') is distinct from '1'
     or (value->>'version') is distinct from '3' then
    raise exception 'Invalid progress schema or payload size' using errcode = '22023';
  end if;
  foreach field in array array[
    'schemaVersion','version','profile','days','capacity','mobileRewards',
    'achievements','openedDays','activityDays','levelFloor','themeMode',
    'reduceMotion','haptics','companionAccessory','companionBackground',
    'workoutSessions','mealCheckIns','habitDelays','habitSwaps','usageTotals',
    'adminOpenedDays','swapResults'
  ] loop
    if value ? field then result := result || jsonb_build_object(field, value->field); end if;
  end loop;
  -- Do not turn a corrupt nonempty collection into an empty one.
  foreach field in array array['days','capacity','mobileRewards','achievements'] loop
    if result->field is null or result->field in ('null'::jsonb, '[]'::jsonb) then
      result := jsonb_set(result, array[field], '{}'::jsonb);
    end if;
  end loop;
  foreach field in array array['openedDays','activityDays','workoutSessions','mealCheckIns','habitDelays','habitSwaps','adminOpenedDays'] loop
    if result->field is null or result->field in ('null'::jsonb, '{}'::jsonb) then
      result := jsonb_set(result, array[field], '[]'::jsonb);
    end if;
  end loop;
  profile := result->'profile';
  if jsonb_typeof(profile) = 'object' then
    profile := '{}'::jsonb;
    for entry in select * from jsonb_each(result->'profile') loop
      if entry.key = any(array['alias','path','pace','lowImpact','companion','started','waterGoal','ageGroup','companionName']) then
        profile := profile || jsonb_build_object(entry.key, entry.value);
      end if;
    end loop;
    result := jsonb_set(result, '{profile}', profile);
  end if;
  result := private.youwell_strip_legacy_fields(result);
  if jsonb_typeof(result->'habitSwaps') = 'array' then
    select coalesce(jsonb_agg(jsonb_build_object('id', row->'id', 'day', row->'day')), '[]'::jsonb)
    into totals from jsonb_array_elements(result->'habitSwaps') row;
    result := jsonb_set(result, '{habitSwaps}', totals);
  end if;
  if result ? 'swapResults' and result->'swapResults' in ('null'::jsonb, '{}'::jsonb) then
    result := jsonb_set(result, '{swapResults}', '[]'::jsonb);
  end if;
  -- usageTotals did not exist in early clients; absence is preserved so
  -- save_youwell_progress can retain totals already held by the server.
  totals := '[]'::jsonb;
  if value ? 'usageTotals' then
    if value->'usageTotals' in ('null'::jsonb, '{}'::jsonb) then
      result := jsonb_set(result, '{usageTotals}', '[]'::jsonb);
    elsif jsonb_typeof(value->'usageTotals') = 'array' then
      for usage in select jsonb_array_elements(value->'usageTotals') loop
        if jsonb_typeof(usage) <> 'object' then
          raise exception 'Invalid usage total' using errcode = '22023';
        end if;
        -- Select only documented daily fields; never copy free text or time.
        select coalesce(jsonb_object_agg(key, val), '{}'::jsonb) into usage
        from jsonb_each(usage) e(key, val)
        where key = any(array['day','type','total','confirmed','source']);
        if usage->>'type' = 'cigarette' then usage := jsonb_set(usage, '{type}', '"rokok"'); end if;
        if jsonb_typeof(usage->'total') = 'string' and usage->>'total' ~ '^\d{1,3}$' then
          usage := jsonb_set(usage, '{total}', to_jsonb((usage->>'total')::integer));
        end if;
        -- Do not clamp 501 into 500, round fractional consumption, invent
        -- confirmation, or silently coerce invalid calendar dates.
        if coalesce(usage->>'day', '') !~ '^\d{4}-\d{2}-\d{2}$'
           or jsonb_typeof(usage->'total') is distinct from 'number'
           or (usage->>'total')::numeric <> trunc((usage->>'total')::numeric)
           or (usage ? 'confirmed' and jsonb_typeof(usage->'confirmed') <> 'boolean') then
          raise exception 'Invalid usage total' using errcode = '22023';
        end if;
        begin
          day_value := (usage->>'day')::date;
        exception when datetime_field_overflow or invalid_datetime_format then
          raise exception 'Invalid usage total: calendar date' using errcode = '22023';
        end;
        totals := totals || jsonb_build_array(usage);
      end loop;
      result := jsonb_set(result, '{usageTotals}', totals);
    end if;
  end if;
  perform private.youwell_check_progress_payload(result);
  return result;
end;
$$;
revoke all on function private.youwell_normalize_progress(jsonb) from public, anon, authenticated;

-- Keep the audited save behavior, grants, signatures and revision checks.
-- Wrappers delegate to the exact phase-10 implementation after normalization.
do $$ begin
  if to_regprocedure('public.youwell_save_progress_strict_v3(jsonb,bigint)') is null then
    alter function public.save_youwell_progress(jsonb,bigint) rename to youwell_save_progress_strict_v3;
  end if;
end $$;
revoke all on function public.youwell_save_progress_strict_v3(jsonb,bigint) from public, anon, authenticated;

create or replace function public.save_youwell_progress(p_payload jsonb, p_expected_revision bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare caller uuid := (select auth.uid()); existing public.youwell_progress%rowtype;
  result jsonb; totals jsonb; original_input jsonb := p_payload; field text;
begin
  if caller is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  p_payload := private.youwell_normalize_progress(p_payload);
  -- Same per-account lock as the underlying function, held through the save.
  perform pg_advisory_xact_lock(hashtextextended(caller::text, 0));
  select * into existing from public.youwell_progress where user_id = caller for update;
  if existing.user_id is not null and p_payload->'profile' <> 'null'::jsonb then
    -- An old client cannot clear collections it has never understood. An
    -- explicit profile:null remains the existing full reset operation.
    foreach field in array array[
      'days','capacity','mobileRewards','achievements','openedDays','activityDays',
      'workoutSessions','mealCheckIns','habitDelays','habitSwaps','levelFloor',
      'themeMode','reduceMotion','haptics','companionAccessory','companionBackground','swapResults'
    ] loop
      if (not (original_input ? field) or original_input->field = 'null'::jsonb)
         and existing.payload ? field then
        p_payload := jsonb_set(p_payload, array[field], existing.payload->field);
      end if;
    end loop;
    if not (p_payload ? 'usageTotals') then
      p_payload := p_payload || jsonb_build_object('usageTotals', coalesce(existing.payload->'usageTotals', '[]'::jsonb));
    else
      -- Admin-corrected daily totals remain authoritative when an older
      -- phone submits its stale values, including an empty usage list.
      totals := coalesce(p_payload->'usageTotals', '[]'::jsonb);
      select coalesce(jsonb_agg(incoming), '[]'::jsonb) into totals
      from jsonb_array_elements(totals) incoming
      where not exists (
        select 1 from jsonb_array_elements(coalesce(existing.payload->'usageTotals', '[]'::jsonb)) old
        where old->>'source' = 'admin' and old->>'day' = incoming->>'day' and old->>'type' = incoming->>'type'
      );
      select totals || coalesce(jsonb_agg(old), '[]'::jsonb) into totals
      from jsonb_array_elements(coalesce(existing.payload->'usageTotals', '[]'::jsonb)) old
      where old->>'source' = 'admin';
      p_payload := jsonb_set(p_payload, '{usageTotals}', totals);
    end if;
    if existing.payload ? 'swapResults' then
      -- Phase 13/14 results must survive an older client that cannot send
      -- them, and source:admin results cannot be replaced by stale counts.
      select coalesce(jsonb_agg(incoming), '[]'::jsonb) into totals
      from jsonb_array_elements(coalesce(p_payload->'swapResults', '[]'::jsonb)) incoming
      where not exists (
        select 1 from jsonb_array_elements(existing.payload->'swapResults') old
        where old->>'source' = 'admin' and old->>'day' = incoming->>'day' and old->>'type' = incoming->>'type'
      );
      select totals || coalesce(jsonb_agg(old), '[]'::jsonb) into totals
      from jsonb_array_elements(existing.payload->'swapResults') old
      where old->>'source' = 'admin';
      p_payload := jsonb_set(p_payload, '{swapResults}', totals);
    end if;
    if existing.payload ? 'adminOpenedDays' then
      select coalesce(jsonb_agg(distinct d), '[]'::jsonb) into result
      from jsonb_array_elements(coalesce(p_payload->'adminOpenedDays', '[]'::jsonb) || (existing.payload->'adminOpenedDays')) d;
      p_payload := jsonb_set(p_payload, '{adminOpenedDays}', result);
      select coalesce(jsonb_agg(distinct d), '[]'::jsonb) into result
      from jsonb_array_elements(coalesce(p_payload->'openedDays', '[]'::jsonb) || result) d;
      p_payload := jsonb_set(p_payload, '{openedDays}', result);
    end if;
    -- Retain recovered count-only moments; never copy raw outcome details.
    select coalesce(jsonb_agg(old), '[]'::jsonb) into result
    from jsonb_array_elements(coalesce(existing.payload->'habitSwaps', '[]'::jsonb)) old
    where old->>'id' like 'admin-%' and not exists (
      select 1 from jsonb_array_elements(p_payload->'habitSwaps') incoming where incoming->>'id' = old->>'id'
    );
    p_payload := jsonb_set(p_payload, '{habitSwaps}', p_payload->'habitSwaps' || result);
  end if;
  return public.youwell_save_progress_strict_v3(p_payload, p_expected_revision);
end;
$$;
revoke all on function public.save_youwell_progress(jsonb,bigint) from public, anon, authenticated;
grant execute on function public.save_youwell_progress(jsonb,bigint) to authenticated;

-- Admin edits of stored historical snapshots also use the adapter, while
-- retaining the exact stored profile (admins cannot change participants).
do $$ begin
  if to_regprocedure('public.youwell_admin_write_strict_v3(uuid,bigint,jsonb,text,jsonb)') is null then
    alter function public.admin_write_youwell_progress(uuid,bigint,jsonb,text,jsonb) rename to youwell_admin_write_strict_v3;
  end if;
end $$;
revoke all on function public.youwell_admin_write_strict_v3(uuid,bigint,jsonb,text,jsonb) from public, anon, authenticated;
create or replace function public.admin_write_youwell_progress(
  p_account uuid, p_expected_revision bigint, p_payload jsonb, p_reason text, p_changes jsonb
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare existing_profile jsonb;
begin
  perform private.youwell_require_admin();
  perform pg_advisory_xact_lock(hashtextextended(p_account::text, 0));
  select payload->'profile' into existing_profile from public.youwell_progress where user_id = p_account for update;
  p_payload := private.youwell_normalize_progress(p_payload);
  -- An old stored profile must be corrected explicitly; do not temporarily
  -- rewrite it or silently permit an admin to change identity/preferences.
  if p_payload->'profile' is distinct from existing_profile then
    raise exception 'Profile cannot be changed by admin; participant must sync the compatible profile first' using errcode = '22023';
  end if;
  return public.youwell_admin_write_strict_v3(p_account, p_expected_revision, p_payload, p_reason, p_changes);
end;
$$;
revoke all on function public.admin_write_youwell_progress(uuid,bigint,jsonb,text,jsonb) from public, anon, authenticated;
grant execute on function public.admin_write_youwell_progress(uuid,bigint,jsonb,text,jsonb) to authenticated;

commit;
