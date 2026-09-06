-- YouWell account, role and cross-device snapshot foundation.
-- Run with `supabase db push` or paste in Supabase SQL Editor once.

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null unique,
  role text not null default 'user' check (role in ('user', 'admin')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "profiles: user can read own role"
on public.profiles for select to authenticated
using (id = auth.uid());

create or replace function public.handle_new_youwell_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, role)
  values (
    new.id,
    lower(coalesce(new.email, '')),
    case
      when lower(coalesce(new.email, '')) = 'alfredonataniel2@gmail.com'
        then 'admin'
      else 'user'
    end
  )
  on conflict (id) do update set
    email = excluded.email,
    updated_at = now();
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_youwell on auth.users;
create trigger on_auth_user_created_youwell
  after insert on auth.users
  for each row execute procedure public.handle_new_youwell_user();

-- Also creates profiles for accounts that signed in before this migration ran.
insert into public.profiles (id, email, role)
select
  id,
  lower(coalesce(email, '')),
  case
    when lower(coalesce(email, '')) = 'alfredonataniel2@gmail.com'
      then 'admin'
    else 'user'
  end
from auth.users
on conflict (id) do update set
  email = excluded.email,
  role = excluded.role,
  updated_at = now();

create table if not exists public.wellness_snapshots (
  user_id uuid primary key references auth.users(id) on delete cascade,
  state text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.wellness_snapshots enable row level security;

create policy "snapshots: owner can read"
on public.wellness_snapshots for select to authenticated
using (user_id = auth.uid());

create policy "snapshots: owner can create"
on public.wellness_snapshots for insert to authenticated
with check (user_id = auth.uid());

create policy "snapshots: owner can update"
on public.wellness_snapshots for update to authenticated
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

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute procedure public.set_updated_at();

drop trigger if exists snapshots_set_updated_at on public.wellness_snapshots;
create trigger snapshots_set_updated_at
  before update on public.wellness_snapshots
  for each row execute procedure public.set_updated_at();
