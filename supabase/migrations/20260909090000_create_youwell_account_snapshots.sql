-- Keeps YouWell account data separate from any pre-existing app snapshots.
-- Run this after 20260906060000_create_youwell_auth_and_sync.sql.

create table if not exists public.youwell_account_snapshots (
  user_id uuid primary key references auth.users(id) on delete cascade,
  state text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.youwell_account_snapshots enable row level security;

drop policy if exists "youwell snapshots: owner can read"
on public.youwell_account_snapshots;
create policy "youwell snapshots: owner can read"
on public.youwell_account_snapshots for select to authenticated
using (user_id = auth.uid());

drop policy if exists "youwell snapshots: owner can create"
on public.youwell_account_snapshots;
create policy "youwell snapshots: owner can create"
on public.youwell_account_snapshots for insert to authenticated
with check (user_id = auth.uid());

drop policy if exists "youwell snapshots: owner can update"
on public.youwell_account_snapshots;
create policy "youwell snapshots: owner can update"
on public.youwell_account_snapshots for update to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists youwell_account_snapshots_set_updated_at
on public.youwell_account_snapshots;
create trigger youwell_account_snapshots_set_updated_at
  before update on public.youwell_account_snapshots
  for each row execute procedure public.set_updated_at();
