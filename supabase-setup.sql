-- ===========================================================================
--  Bathla Creative Board — Supabase setup (v3: email login + admin-only feedback)
--  Run once in a fresh project: SQL Editor -> New query -> paste -> Run.
--  Safe to re-run. For an EXISTING v2 project, run migrate-v3.sql instead.
--
--  Access model:
--   - Everyone signs in with an email magic-link (Supabase Auth, email provider).
--   - A person's email is linked to one row in `people` (claimed on first login).
--   - Reviewers can read/write only their OWN ratings and comments.
--   - Admins (people.is_admin = true) can read everyone's ratings and comments.
--   - Images, weeks and the request queue are visible to every signed-in user.
--
--  After running: Auth -> URL Configuration -> set Site URL and add a Redirect URL
--  of  https://tannitadigpati7-bit.github.io/imagedashboard/creative-board.html
-- ===========================================================================

-- ---------- tables ----------
create table if not exists public.people (
  id          text primary key,
  name        text not null,
  color       text not null default '#F2E64F',
  role        text not null default 'Reviewer',
  email       text unique,
  is_admin    boolean not null default false,
  created_at  timestamptz not null default now()
);

create table if not exists public.weeks (
  id          text primary key,
  label       text not null,
  created_at  timestamptz not null default now()
);

create table if not exists public.images (
  id            text primary key,
  week_id       text not null references public.weeks(id) on delete cascade,
  title         text not null default 'Untitled',
  url           text not null,
  storage_path  text,
  bytes         bigint,
  added_by      text references public.people(id) on delete set null,
  created_at    timestamptz not null default now()
);

create table if not exists public.ratings (
  id          bigint generated always as identity primary key,
  image_id    text not null references public.images(id) on delete cascade,
  person_id   text not null references public.people(id) on delete cascade,
  stars       smallint not null check (stars between 1 and 5),
  created_at  timestamptz not null default now(),
  unique (image_id, person_id)
);

create table if not exists public.comments (
  id          text primary key,
  image_id    text not null references public.images(id) on delete cascade,
  person_id   text references public.people(id) on delete set null,
  body        text not null,
  x           real,            -- 0..1 fraction across the image (null = general comment)
  y           real,            -- 0..1 fraction down the image
  created_at  timestamptz not null default now()
);

create table if not exists public.requests (
  id            text primary key,
  title         text not null,
  detail        text not null default '',
  requested_by  text references public.people(id) on delete set null,
  status        text not null default 'open' check (status in ('open','in_progress','done')),
  assigned_to   text references public.people(id) on delete set null,
  done_by       text references public.people(id) on delete set null,
  created_at    timestamptz not null default now(),
  done_at       timestamptz
);

drop table if exists public.reactions cascade;   -- pre-star thumbs table, if present

-- ---------- helper functions ----------
create or replace function public.current_person() returns text
  language sql stable security definer set search_path = public as $$
  select id from public.people where email = auth.email() limit 1
$$;

create or replace function public.is_admin() returns boolean
  language sql stable security definer set search_path = public as $$
  select coalesce((select is_admin from public.people where email = auth.email() limit 1), false)
$$;

-- ---------- row-level security ----------
alter table public.people   enable row level security;
alter table public.weeks    enable row level security;
alter table public.images   enable row level security;
alter table public.ratings  enable row level security;
alter table public.comments enable row level security;
alter table public.requests enable row level security;

-- clear any policy this script may have created before
do $$
declare r record;
begin
  for r in
    select policyname, tablename from pg_policies
    where schemaname = 'public'
      and tablename in ('people','weeks','images','ratings','comments','requests')
  loop
    execute format('drop policy if exists %I on public.%I', r.policyname, r.tablename);
  end loop;
end $$;

-- people: any signed-in user can read; you may claim an unclaimed row or edit your own; add yourself
create policy "people read"  on public.people for select to authenticated using (true);
create policy "people claim" on public.people for update to authenticated
  using (email is null or email = auth.email())
  with check (email is null or email = auth.email());
create policy "people add"   on public.people for insert to authenticated
  with check (email = auth.email());

-- weeks / images / requests: any signed-in user, full access
create policy "weeks all"    on public.weeks    for all to authenticated using (true) with check (true);
create policy "images all"   on public.images   for all to authenticated using (true) with check (true);
create policy "requests all" on public.requests for all to authenticated using (true) with check (true);

-- ratings: read your own (admins read all); write only your own
create policy "ratings read"   on public.ratings for select to authenticated
  using (public.is_admin() or person_id = public.current_person());
create policy "ratings insert" on public.ratings for insert to authenticated
  with check (person_id = public.current_person());
create policy "ratings update" on public.ratings for update to authenticated
  using (person_id = public.current_person())
  with check (person_id = public.current_person());
create policy "ratings delete" on public.ratings for delete to authenticated
  using (person_id = public.current_person());

-- comments: same rule (admins may also delete)
create policy "comments read"   on public.comments for select to authenticated
  using (public.is_admin() or person_id = public.current_person());
create policy "comments insert" on public.comments for insert to authenticated
  with check (person_id = public.current_person());
create policy "comments update" on public.comments for update to authenticated
  using (person_id = public.current_person())
  with check (person_id = public.current_person());
create policy "comments delete" on public.comments for delete to authenticated
  using (person_id = public.current_person() or public.is_admin());

-- ---------- storage bucket ----------
insert into storage.buckets (id, name, public)
values ('creatives', 'creatives', true)
on conflict (id) do update set public = true;

drop policy if exists "creatives read"   on storage.objects;
drop policy if exists "creatives upload" on storage.objects;
drop policy if exists "creatives delete" on storage.objects;
create policy "creatives read"   on storage.objects for select to authenticated using (bucket_id = 'creatives');
create policy "creatives upload" on storage.objects for insert to authenticated with check (bucket_id = 'creatives');
create policy "creatives delete" on storage.objects for delete to authenticated using (bucket_id = 'creatives');

-- ---------- seed: reviewers + first week ----------
insert into public.people (id, name, color, role, email, is_admin) values
  ('dev',      'Dev',           '#F2E64F', 'Creative lead', null,                  false),
  ('tannita',  'Tannita',       '#8AB4F8', 'Reviewer',      'tannita@bathla.com',  true),
  ('theerthi', 'Theerthi',      '#F49BC1', 'Reviewer',      'theerthi@bathla.com', true),
  ('divya',    'Divya',         '#79C388', 'Reviewer',      null,                  false),
  ('ashwini',  'Ashwini',       '#F0A45B', 'Reviewer',      null,                  false),
  ('harish',   'Harish',        '#B49BF4', 'Reviewer',      null,                  false),
  ('ruthra',   'Ruthrakesavan', '#6FD3C7', 'Reviewer',      null,                  false),
  ('shashank', 'Shashank',      '#E5735F', 'Reviewer',      null,                  false),
  ('shilpa',   'Shilpa',        '#D8C46A', 'Reviewer',      null,                  false)
on conflict (id) do nothing;

insert into public.weeks (id, label) values
  ('w1', 'WBR — Sep 1, 2026')
on conflict (id) do nothing;
