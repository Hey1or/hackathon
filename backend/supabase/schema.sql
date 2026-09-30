-- Выполните этот файл в Supabase → SQL Editor → New query.
-- Секретный service_role key используется только сервером FastAPI.
create table if not exists public.tasks (
  id text primary key,
  data jsonb not null,
  created_at timestamptz not null default now()
);

create table if not exists public.responses (
  id text primary key,
  task_id text not null references public.tasks(id) on delete cascade,
  data jsonb not null,
  created_at timestamptz not null default now()
);

create table if not exists public.notifications (
  id text primary key,
  audience text not null,
  data jsonb not null,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);
alter table public.notifications drop constraint if exists notifications_audience_check;

-- User profiles for email/password accounts. Passwords are stored only as PBKDF2 hashes.
create table if not exists public.users (
  id text primary key,
  email text not null unique,
  name text not null,
  role text not null check (role in ('business', 'student')),
  password_hash text not null,
  email_verified boolean not null default false,
  verification_token_hash text unique,
  verification_expires_at timestamptz,
  consent_at timestamptz not null default now(),
  consent_version text not null default 'v1',
  session_version integer not null default 0,
  is_owner boolean not null default false,
  created_at timestamptz not null default now()
);
alter table public.users add column if not exists email_verified boolean not null default false;
alter table public.users add column if not exists verification_token_hash text unique;
alter table public.users add column if not exists verification_expires_at timestamptz;
alter table public.users add column if not exists consent_at timestamptz not null default now();
alter table public.users add column if not exists consent_version text not null default 'v1';
alter table public.users add column if not exists is_active boolean not null default true;
alter table public.users add column if not exists session_version integer not null default 0;
alter table public.users add column if not exists is_owner boolean not null default false;
alter table public.users enable row level security;
revoke all on public.users from anon, authenticated;

-- Anonymous, session-based page counters. No IP address or profile data is stored.
create table if not exists public.page_views (
  id text primary key,
  viewer_key text not null,
  page_key text not null,
  view_date date not null,
  viewed_at timestamptz not null default now(),
  unique (viewer_key, page_key, view_date)
);
alter table public.page_views enable row level security;
revoke all on public.page_views from anon, authenticated;
create index if not exists page_views_date_idx on public.page_views(view_date);

-- The app accesses these tables through FastAPI only, never directly from a browser.
alter table public.tasks enable row level security;
alter table public.responses enable row level security;
alter table public.notifications enable row level security;
revoke all on public.tasks, public.responses, public.notifications from anon, authenticated;

create index if not exists responses_task_id_idx on public.responses(task_id);
create index if not exists notifications_audience_idx on public.notifications(audience, is_read);

-- Запросы выполняются FastAPI с service_role key. Не кладите этот ключ в приложение.
