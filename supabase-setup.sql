-- ===========================================================================
--  Bathla Creative Board — Supabase setup
--  Run this ONCE in your Supabase project: SQL Editor -> New query -> paste ->
--  Run. Safe to re-run (idempotent).
--
--  After it finishes: Settings -> API -> copy "Project URL" and the
--  "anon public" key into the CONFIG block at the top of creative-board.html.
-- ===========================================================================

-- ---------- tables ----------
create table if not exists public.people (
  id          text primary key,
  name        text not null,
  color       text not null default '#F2E64F',
  role        text not null default 'Reviewer',
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
  added_by      text references public.people(id) on delete set null,
  created_at    timestamptz not null default now()
);

create table if not exists public.reactions (
  id          bigint generated always as identity primary key,
  image_id    text not null references public.images(id) on delete cascade,
  person_id   text not null references public.people(id) on delete cascade,
  value       text not null check (value in ('up','down')),
  created_at  timestamptz not null default now(),
  unique (image_id, person_id)
);

create table if not exists public.comments (
  id          text primary key,
  image_id    text not null references public.images(id) on delete cascade,
  person_id   text references public.people(id) on delete set null,
  body        text not null,
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

-- ---------- row-level security ----------
-- Internal tool behind an unlisted URL: the public anon key may read and write
-- these six tables. Nothing else in the project is exposed.
-- Tighten later if the board ever needs to be locked down.
alter table public.people    enable row level security;
alter table public.weeks     enable row level security;
alter table public.images    enable row level security;
alter table public.reactions enable row level security;
alter table public.comments  enable row level security;
alter table public.requests  enable row level security;

do $$
declare t text;
begin
  foreach t in array array['people','weeks','images','reactions','comments','requests'] loop
    execute format('drop policy if exists "anon rw" on public.%I', t);
    execute format(
      'create policy "anon rw" on public.%I for all to anon using (true) with check (true)', t);
  end loop;
end $$;

-- ---------- storage bucket for the image files ----------
insert into storage.buckets (id, name, public)
values ('creatives', 'creatives', true)
on conflict (id) do update set public = true;

drop policy if exists "creatives read"   on storage.objects;
drop policy if exists "creatives upload" on storage.objects;
drop policy if exists "creatives delete" on storage.objects;

create policy "creatives read"   on storage.objects
  for select to anon using (bucket_id = 'creatives');
create policy "creatives upload" on storage.objects
  for insert to anon with check (bucket_id = 'creatives');
create policy "creatives delete" on storage.objects
  for delete to anon using (bucket_id = 'creatives');

-- ---------- seed: reviewers + first week ----------
insert into public.people (id, name, color, role) values
  ('dev',      'Dev',           '#F2E64F', 'Creative lead'),
  ('tannita',  'Tannita',       '#8AB4F8', 'Reviewer'),
  ('theerthi', 'Theerthi',      '#F49BC1', 'Reviewer'),
  ('divya',    'Divya',         '#79C388', 'Reviewer'),
  ('ashwini',  'Ashwini',       '#F0A45B', 'Reviewer'),
  ('harish',   'Harish',        '#B49BF4', 'Reviewer'),
  ('ruthra',   'Ruthrakesavan', '#6FD3C7', 'Reviewer'),
  ('shashank', 'Shashank',      '#E5735F', 'Reviewer'),
  ('shilpa',   'Shilpa',        '#D8C46A', 'Reviewer')
on conflict (id) do nothing;

insert into public.weeks (id, label) values
  ('w1', 'WBR — Sep 1, 2026')
on conflict (id) do nothing;
