-- SpaceSense AI: initial schema (replaces the Firestore data model).
-- Every table has RLS enabled. Clients only ever see their own rows; the
-- Edge Functions use the service role for rate limiting and the AI cache.

-- ---------------------------------------------------------------- helpers --
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- --------------------------------------------------------------- profiles --
create table public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  email        text,
  photo_url    text,
  is_guest     boolean not null default false,
  region       text not null default 'PH',
  currency     text not null default 'PHP',
  preferences  jsonb not null default jsonb_build_object(
    'themeMode', 'system', 'budgetTier', 'medium', 'occupants', 2,
    'hasChildren', false, 'hasPets', false, 'accessibilityNeeds', jsonb_build_array()
  ),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- Keep profiles in sync with auth.users (sign-up, guest -> permanent upgrade,
-- OAuth metadata). Replaces the client-side "ensure user doc" call.
create or replace function public.handle_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name, email, photo_url, is_guest)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name'),
    nullif(new.email, ''),
    coalesce(new.raw_user_meta_data ->> 'avatar_url', new.raw_user_meta_data ->> 'picture'),
    coalesce(new.is_anonymous, false)
  )
  on conflict (id) do update set
    display_name = coalesce(public.profiles.display_name, excluded.display_name),
    email        = excluded.email,
    photo_url    = coalesce(public.profiles.photo_url, excluded.photo_url),
    is_guest     = excluded.is_guest;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_auth_user();

create trigger on_auth_user_updated
  after update of email, is_anonymous, raw_user_meta_data on auth.users
  for each row execute function public.handle_auth_user();

alter table public.profiles enable row level security;

create policy "profiles: read own" on public.profiles
  for select to authenticated using (id = (select auth.uid()));
create policy "profiles: update own" on public.profiles
  for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

-- --------------------------------------------------------------- projects --
create table public.projects (
  id              uuid primary key default gen_random_uuid(),
  owner_id        uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name            text not null check (char_length(name) between 1 and 120),
  room_type       text not null default 'other',
  status          text not null default 'scanned'
                    check (status in ('scanned', 'analyzed', 'designed', 'archived')),
  cover_photo_url text,
  is_favorite     boolean not null default false,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index projects_owner_updated_idx on public.projects (owner_id, updated_at desc);

-- Toggling a favorite must not reorder the "recent projects" list.
create or replace function public.projects_touch()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.is_favorite is distinct from old.is_favorite
     and (to_jsonb(new) - 'is_favorite' - 'updated_at')
       = (to_jsonb(old) - 'is_favorite' - 'updated_at') then
    new.updated_at := old.updated_at;
  else
    new.updated_at := now();
  end if;
  return new;
end;
$$;

create trigger projects_touch
  before update on public.projects
  for each row execute function public.projects_touch();

alter table public.projects enable row level security;

create policy "projects: read own" on public.projects
  for select to authenticated using (owner_id = (select auth.uid()));
create policy "projects: insert own" on public.projects
  for insert to authenticated with check (owner_id = (select auth.uid()));
create policy "projects: update own" on public.projects
  for update to authenticated
  using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));
create policy "projects: delete own" on public.projects
  for delete to authenticated using (owner_id = (select auth.uid()));

-- ------------------------------------------- rooms / analyses / designs ----
-- The documents keep their original JSON shape in `data`; only the columns
-- the app queries or orders by are promoted to real columns.
create table public.rooms (
  id         uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects (id) on delete cascade,
  version    integer not null default 1,
  data       jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (project_id, version)
);

create table public.analyses (
  id           uuid primary key default gen_random_uuid(),
  project_id   uuid not null references public.projects (id) on delete cascade,
  room_version integer not null default 1,
  data         jsonb not null,
  created_at   timestamptz not null default now()
);
create index analyses_project_created_idx on public.analyses (project_id, created_at desc);

create table public.designs (
  id         uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects (id) on delete cascade,
  data       jsonb not null,
  created_at timestamptz not null default now()
);
create index designs_project_created_idx on public.designs (project_id, created_at desc);

create trigger rooms_set_updated_at
  before update on public.rooms
  for each row execute function public.set_updated_at();

alter table public.rooms enable row level security;
alter table public.analyses enable row level security;
alter table public.designs enable row level security;

create policy "rooms: owner all" on public.rooms
  for all to authenticated
  using (exists (select 1 from public.projects p
                 where p.id = project_id and p.owner_id = (select auth.uid())))
  with check (exists (select 1 from public.projects p
                      where p.id = project_id and p.owner_id = (select auth.uid())));

create policy "analyses: owner all" on public.analyses
  for all to authenticated
  using (exists (select 1 from public.projects p
                 where p.id = project_id and p.owner_id = (select auth.uid())))
  with check (exists (select 1 from public.projects p
                      where p.id = project_id and p.owner_id = (select auth.uid())));

create policy "designs: owner all" on public.designs
  for all to authenticated
  using (exists (select 1 from public.projects p
                 where p.id = project_id and p.owner_id = (select auth.uid())))
  with check (exists (select 1 from public.projects p
                      where p.id = project_id and p.owner_id = (select auth.uid())));

-- ------------------------------------------------------- public reference --
create table public.design_tips (
  id          uuid primary key default gen_random_uuid(),
  text        text not null,
  category    text,
  active_date date
);

create table public.cost_catalog (
  region   text primary key,
  currency text not null default 'PHP',
  rates    jsonb not null default '{}'::jsonb
);

alter table public.design_tips enable row level security;
alter table public.cost_catalog enable row level security;

create policy "design_tips: public read" on public.design_tips
  for select to anon, authenticated using (true);
create policy "cost_catalog: public read" on public.cost_catalog
  for select to anon, authenticated using (true);

-- ------------------------------------------- server-only AI bookkeeping ----
-- RLS is enabled with NO policies: only the service role (Edge Functions) can
-- touch these tables.
create table public.ai_cache (
  key        text primary key,
  task       text not null,
  response   jsonb not null,
  model      text not null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null
);
create index ai_cache_expires_idx on public.ai_cache (expires_at);

create table public.ai_usage (
  user_id      uuid primary key references auth.users (id) on delete cascade,
  window_start timestamptz not null default now(),
  calls        integer not null default 0
);

alter table public.ai_cache enable row level security;
alter table public.ai_usage enable row level security;

-- Atomic fixed-window rate limiter: returns false once `p_limit` calls have
-- been made inside the current one-hour window.
create or replace function public.consume_ai_call(p_user uuid, p_limit integer default 30)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_calls integer;
begin
  insert into public.ai_usage as u (user_id, window_start, calls)
  values (p_user, now(), 1)
  on conflict (user_id) do update set
    window_start = case when u.window_start <= now() - interval '1 hour'
                        then now() else u.window_start end,
    calls = case when u.window_start <= now() - interval '1 hour'
                 then 1 else u.calls + 1 end
  returning u.calls into v_calls;
  return v_calls <= p_limit;
end;
$$;

revoke all on function public.consume_ai_call(uuid, integer) from public, anon, authenticated;
grant execute on function public.consume_ai_call(uuid, integer) to service_role;

-- ---------------------------------------------------------------- storage --
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('scan-photos', 'scan-photos', false, 10485760,
        array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

-- Objects live under  <uid>/<projectId>/scan/<target>.jpg
create policy "scan-photos: read own" on storage.objects
  for select to authenticated
  using (bucket_id = 'scan-photos'
         and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "scan-photos: upload own" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'scan-photos'
              and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "scan-photos: update own" on storage.objects
  for update to authenticated
  using (bucket_id = 'scan-photos'
         and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "scan-photos: delete own" on storage.objects
  for delete to authenticated
  using (bucket_id = 'scan-photos'
         and (storage.foldername(name))[1] = (select auth.uid())::text);

-- --------------------------------------------------------------- realtime --
-- The Flutter app uses `.stream()` on these tables (Firestore snapshots).
do $$
declare
  t text;
begin
  foreach t in array array['projects', 'rooms', 'analyses', 'designs'] loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end;
$$;
