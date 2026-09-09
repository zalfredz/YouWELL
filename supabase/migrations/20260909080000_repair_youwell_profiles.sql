-- Safe repair for a Supabase project that already has unrelated app tables.
-- It does not read, change, or delete public.wellness_snapshots.

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null unique,
  role text not null default 'user' check (role in ('user', 'admin')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists "profiles: user can read own role" on public.profiles;
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
    role = excluded.role,
    updated_at = now();
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_youwell on auth.users;
create trigger on_auth_user_created_youwell
  after insert on auth.users
  for each row execute procedure public.handle_new_youwell_user();

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
