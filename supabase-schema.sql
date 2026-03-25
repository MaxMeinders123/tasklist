-- Project Atlas / Supabase schema
-- Run this in the Supabase SQL editor.

create extension if not exists pgcrypto;

-- Profiles / roles
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text unique,
  role text not null default 'editor' check (role in ('senior','editor','admin')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Projects
create table if not exists public.projects (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  summary text default '',
  phase text not null default 'build',
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Tasks
create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  title text not null,
  summary text default '',
  details text default '',
  area text default 'general',
  priority text not null default 'medium' check (priority in ('low','medium','high')),
  status text not null default 'todo' check (status in ('todo','in_progress','blocked','done')),
  owner text default 'us',
  blockers text[] not null default '{}',
  dependencies text[] not null default '{}',
  subtasks text[] not null default '{}',
  notes text default '',
  created_by uuid references auth.users(id),
  updated_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Task history
create table if not exists public.task_history (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.tasks(id) on delete cascade,
  user_id uuid references auth.users(id),
  field_changed text not null,
  old_value text,
  new_value text,
  note text default '',
  created_at timestamptz not null default now()
);

-- Task notes
create table if not exists public.task_notes (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.tasks(id) on delete cascade,
  user_id uuid references auth.users(id),
  note text not null,
  created_at timestamptz not null default now()
);

-- updated_at helper
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_profiles_updated_at on public.profiles;
create trigger trg_profiles_updated_at before update on public.profiles for each row execute procedure public.set_updated_at();

drop trigger if exists trg_projects_updated_at on public.projects;
create trigger trg_projects_updated_at before update on public.projects for each row execute procedure public.set_updated_at();

drop trigger if exists trg_tasks_updated_at on public.tasks;
create trigger trg_tasks_updated_at before update on public.tasks for each row execute procedure public.set_updated_at();

-- Auto-create profile on signup
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, role)
  values (new.id, new.email, 'editor')
  on conflict (id) do update set email = excluded.email, updated_at = now();
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

-- Seed one default project
insert into public.projects (name, summary, phase, status)
select 'Project Atlas', 'Dashboard for senior visibility and daily execution', 'build', 'active'
where not exists (select 1 from public.projects where name = 'Project Atlas');

-- RLS
alter table public.profiles enable row level security;
alter table public.projects enable row level security;
alter table public.tasks enable row level security;
alter table public.task_history enable row level security;
alter table public.task_notes enable row level security;

-- Simple access rules: any authenticated user can read/write project data
-- tighten later with roles if needed.
drop policy if exists "profiles read own" on public.profiles;
create policy "profiles read own" on public.profiles for select using (auth.uid() = id or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'));
drop policy if exists "profiles update own" on public.profiles;
create policy "profiles update own" on public.profiles for update using (auth.uid() = id or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')) with check (auth.uid() = id or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'));

drop policy if exists "projects auth read" on public.projects;
create policy "projects auth read" on public.projects for select to authenticated using (true);
drop policy if exists "projects auth write" on public.projects;
create policy "projects auth write" on public.projects for insert to authenticated with check (true);
drop policy if exists "projects auth update" on public.projects;
create policy "projects auth update" on public.projects for update to authenticated using (true) with check (true);
drop policy if exists "projects auth delete" on public.projects;
create policy "projects auth delete" on public.projects for delete to authenticated using (true);

drop policy if exists "tasks auth read" on public.tasks;
create policy "tasks auth read" on public.tasks for select to authenticated using (true);
drop policy if exists "tasks auth write" on public.tasks;
create policy "tasks auth write" on public.tasks for insert to authenticated with check (true);
drop policy if exists "tasks auth update" on public.tasks;
create policy "tasks auth update" on public.tasks for update to authenticated using (true) with check (true);
drop policy if exists "tasks auth delete" on public.tasks;
create policy "tasks auth delete" on public.tasks for delete to authenticated using (true);

drop policy if exists "history auth read" on public.task_history;
create policy "history auth read" on public.task_history for select to authenticated using (true);
drop policy if exists "history auth write" on public.task_history;
create policy "history auth write" on public.task_history for insert to authenticated with check (true);

drop policy if exists "notes auth read" on public.task_notes;
create policy "notes auth read" on public.task_notes for select to authenticated using (true);
drop policy if exists "notes auth write" on public.task_notes;
create policy "notes auth write" on public.task_notes for insert to authenticated with check (true);
