-- Phase 9: Meal Snap verification (team decision 23 Oct 2026; the proposal
-- is being updated). A meal photo is uploaded to a private bucket, an MFA
-- admin approves or rejects it, and after 3 hours without a decision the
-- Edge Function `meal-ai-check` asks Gemini (YA/TIDAK). The photo file is
-- removed once decided; only the decision stays. Run after phase 8.

create table if not exists public.youwell_meal_checks (
  id uuid primary key default gen_random_uuid(),
  author uuid not null references auth.users(id) on delete cascade,
  -- The meal row id on the device, so the app can match the decision.
  client_id text not null check (char_length(client_id) between 1 and 80),
  image_path text,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  reviewer text check (reviewer in ('admin', 'ai')),
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  unique (author, client_id)
);
alter table public.youwell_meal_checks enable row level security;
revoke all on public.youwell_meal_checks from public, anon, authenticated;
create index if not exists youwell_meal_checks_pending
  on public.youwell_meal_checks (created_at) where status = 'pending';

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('meals', 'meals', false, 3145728, array['image/png'])
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Meal photo upload own folder" on storage.objects;
create policy "Meal photo upload own folder" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'meals'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "Meal photo read own or admin" on storage.objects;
create policy "Meal photo read own or admin" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'meals'
    and (
      (storage.foldername(name))[1] = (select auth.uid())::text
      or public.youwell_admin_access() = 'allowed'
    )
  );

drop policy if exists "Meal photo delete own or admin" on storage.objects;
create policy "Meal photo delete own or admin" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'meals'
    and (
      (storage.foldername(name))[1] = (select auth.uid())::text
      or public.youwell_admin_access() = 'allowed'
    )
  );

-- Sends (or re-sends after a rejection) one meal photo for review.
create or replace function public.submit_youwell_meal(
  p_client_id text, p_image_path text
)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  caller uuid := (select auth.uid());
  created uuid;
begin
  if caller is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  if p_image_path !~ ('^' || caller::text || '/[0-9a-f-]{36}\.png$')
     or not exists (select 1 from storage.objects o
                    where o.bucket_id = 'meals' and o.name = p_image_path) then
    raise exception 'Photo not uploaded by this account' using errcode = '22023';
  end if;
  insert into public.youwell_meal_checks (author, client_id, image_path)
  values (caller, p_client_id, p_image_path)
  on conflict (author, client_id) do update
    set image_path = excluded.image_path, status = 'pending',
        reviewer = null, reviewed_at = null, created_at = now()
  returning id into created;
  return created;
end;
$$;
revoke all on function public.submit_youwell_meal(text, text) from public, anon, authenticated;
grant execute on function public.submit_youwell_meal(text, text) to authenticated;

-- The caller's own decisions of the last 30 days.
create or replace function public.youwell_my_meal_checks()
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'client_id', m.client_id, 'status', m.status, 'reviewer', m.reviewer,
    'created_at', m.created_at
  )), '[]'::jsonb)
  from public.youwell_meal_checks m
  where m.author = (select auth.uid())
    and m.created_at > now() - interval '30 days';
$$;
revoke all on function public.youwell_my_meal_checks() from public, anon, authenticated;
grant execute on function public.youwell_my_meal_checks() to authenticated;

-- Admin: photos waiting for a decision, oldest first, with the alias only.
create or replace function public.youwell_meal_queue()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.youwell_require_admin();
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', m.id, 'alias', coalesce(p.alias, 'peserta'),
      'image_path', m.image_path, 'created_at', m.created_at
    ) order by m.created_at)
    from public.youwell_meal_checks m
    left join public.youwell_profiles p on p.user_id = m.author
    where m.status = 'pending'
  ), '[]'::jsonb);
end;
$$;
revoke all on function public.youwell_meal_queue() from public, anon, authenticated;
grant execute on function public.youwell_meal_queue() to authenticated;

-- Admin: the latest 50 decisions, by admin or AI.
create or replace function public.youwell_meal_recent()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.youwell_require_admin();
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', r.id, 'alias', r.alias, 'status', r.status,
      'reviewer', r.reviewer, 'reviewed_at', r.reviewed_at
    ) order by r.reviewed_at desc)
    from (
      select m.id, coalesce(p.alias, 'peserta') as alias, m.status,
             m.reviewer, m.reviewed_at
      from public.youwell_meal_checks m
      left join public.youwell_profiles p on p.user_id = m.author
      where m.status <> 'pending'
      order by m.reviewed_at desc
      limit 50
    ) r
  ), '[]'::jsonb);
end;
$$;
revoke all on function public.youwell_meal_recent() from public, anon, authenticated;
grant execute on function public.youwell_meal_recent() to authenticated;

-- Admin decides a pending photo; returns the file path so the app can
-- delete the file (storage files cannot be removed from SQL).
create or replace function public.review_youwell_meal(p_id uuid, p_approve boolean)
returns text language plpgsql security definer set search_path = '' as $$
declare photo text;
begin
  perform private.youwell_require_admin();
  update public.youwell_meal_checks
  set status = case when p_approve then 'approved' else 'rejected' end,
      reviewer = 'admin', reviewed_at = now()
  where id = p_id and status = 'pending'
  returning image_path into photo;
  if not found then raise exception 'Already decided' using errcode = 'P0002'; end if;
  update public.youwell_meal_checks set image_path = null where id = p_id;
  return photo;
end;
$$;
revoke all on function public.review_youwell_meal(uuid, boolean) from public, anon, authenticated;
grant execute on function public.review_youwell_meal(uuid, boolean) to authenticated;
