-- ASO-TECH SERVICES: database setup for Supabase
-- Run this ONCE: Supabase dashboard -> SQL Editor -> New query -> paste everything -> Run.

-- 1. Staff profiles (one row per login; the login itself lives in Supabase Auth)
create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  username    text not null unique,
  name        text not null,
  role        text not null default 'sales'
              check (role in ('admin','manager','purchasing','warehouse','sales','accounts')),
  branch_id   text not null default 'ALL',
  active      boolean not null default true,
  created_at  timestamptz not null default now()
);

-- 2. All business records (products, sales, journals, ...). One row per record.
create table if not exists public.records (
  coll        text not null,
  id          text not null,
  branch_id   text,
  data        jsonb not null,
  u           bigint not null default 0,
  updated_at  timestamptz not null default now(),
  primary key (coll, id)
);
create index if not exists records_updated_idx on public.records (updated_at);

-- 3. Helper functions (SECURITY DEFINER so they can read profiles without recursion)
create or replace function public.is_active() returns boolean
  language sql stable security definer set search_path = public as
$$ select exists (select 1 from public.profiles where id = auth.uid() and active) $$;

create or replace function public.is_admin() returns boolean
  language sql stable security definer set search_path = public as
$$ select exists (select 1 from public.profiles where id = auth.uid() and active and role = 'admin') $$;

create or replace function public.my_branch() returns text
  language sql stable security definer set search_path = public as
$$ select branch_id from public.profiles where id = auth.uid() and active $$;

create or replace function public.setup_needed() returns boolean
  language sql stable security definer set search_path = public as
$$ select not exists (select 1 from public.profiles) $$;

grant execute on function public.setup_needed() to anon, authenticated;
grant execute on function public.is_active(), public.is_admin(), public.my_branch() to authenticated;

-- 4. The very first profile always becomes the administrator
create or replace function public.profiles_first_admin() returns trigger
  language plpgsql security definer set search_path = public as
$$
begin
  if not exists (select 1 from public.profiles) then
    new.role := 'admin'; new.branch_id := 'ALL'; new.active := true;
  end if;
  return new;
end $$;
drop trigger if exists profiles_first_admin on public.profiles;
create trigger profiles_first_admin before insert on public.profiles
  for each row execute function public.profiles_first_admin();

-- 5. Records: stamp the time, copy the branch from the data, and never let an older edit overwrite a newer one
create or replace function public.records_guard() returns trigger
  language plpgsql as
$$
begin
  if tg_op = 'UPDATE' and new.u < old.u then
    return null;                      -- ignore stale write
  end if;
  new.branch_id  := nullif(new.data ->> 'branchId', '');
  new.updated_at := now();
  return new;
end $$;
drop trigger if exists records_guard on public.records;
create trigger records_guard before insert or update on public.records
  for each row execute function public.records_guard();

-- 6. Row Level Security: this is what actually protects the data
alter table public.profiles enable row level security;
alter table public.records  enable row level security;

drop policy if exists profiles_read   on public.profiles;
drop policy if exists profiles_insert on public.profiles;
drop policy if exists profiles_update on public.profiles;
drop policy if exists profiles_delete on public.profiles;
create policy profiles_read   on public.profiles for select to authenticated
  using (id = auth.uid() or public.is_admin());
create policy profiles_insert on public.profiles for insert to authenticated
  with check (public.is_admin() or (id = auth.uid() and public.setup_needed()));
create policy profiles_update on public.profiles for update to authenticated
  using (public.is_admin()) with check (public.is_admin());
create policy profiles_delete on public.profiles for delete to authenticated
  using (public.is_admin());

drop policy if exists records_read   on public.records;
drop policy if exists records_insert on public.records;
drop policy if exists records_update on public.records;
drop policy if exists records_delete on public.records;
-- Branch-limited staff only see their own branch's records plus shared ones (products, contacts, ...)
create policy records_read on public.records for select to authenticated
  using (public.is_active() and (branch_id is null or public.my_branch() = 'ALL' or branch_id = public.my_branch()));
create policy records_insert on public.records for insert to authenticated
  with check (public.is_active()
    and (coll not in ('_settings','branches') or public.is_admin())
    and (nullif(data ->> 'branchId','') is null or public.my_branch() = 'ALL' or data ->> 'branchId' = public.my_branch()));
create policy records_update on public.records for update to authenticated
  using (public.is_active() and (branch_id is null or public.my_branch() = 'ALL' or branch_id = public.my_branch()))
  with check (public.is_active()
    and (coll not in ('_settings','branches') or public.is_admin())
    and (nullif(data ->> 'branchId','') is null or public.my_branch() = 'ALL' or data ->> 'branchId' = public.my_branch()));
create policy records_delete on public.records for delete to authenticated
  using (public.is_admin());
