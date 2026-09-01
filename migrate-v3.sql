-- ===========================================================================
--  Bathla Creative Board — migrate an existing v2 project to v3
--  (email login + admin-only feedback + pinned comments)
--  Run once: SQL Editor -> New query -> paste -> Run. Safe to re-run.
--
--  AFTER running this, in the Supabase dashboard:
--   Auth -> URL Configuration
--     Site URL:      https://tannitadigpati7-bit.github.io/imagedashboard/creative-board.html
--     Redirect URLs: add the same URL (and, optionally,
--                    https://tannitadigpati7-bit.github.io/imagedashboard/** )
--   Auth -> Providers -> Email : make sure it is enabled (it is by default).
-- ===========================================================================

-- 1. identity + admin flag on people
alter table public.people add column if not exists email    text;
alter table public.people add column if not exists is_admin boolean not null default false;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'people_email_key') then
    alter table public.people add constraint people_email_key unique (email);
  end if;
end $$;

update public.people set email = 'tannita@bathla.com',  is_admin = true where id = 'tannita';
update public.people set email = 'theerthi@bathla.com', is_admin = true where id = 'theerthi';

-- 2. pin coordinates on comments (null = general comment)
alter table public.comments add column if not exists x real;
alter table public.comments add column if not exists y real;

-- 3. helper functions
create or replace function public.current_person() returns text
  language sql stable security definer set search_path = public as $$
  select id from public.people where email = auth.email() limit 1
$$;

create or replace function public.is_admin() returns boolean
  language sql stable security definer set search_path = public as $$
  select coalesce((select is_admin from public.people where email = auth.email() limit 1), false)
$$;

-- 4. replace every existing policy on these tables with the v3 set
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

alter table public.people   enable row level security;
alter table public.weeks    enable row level security;
alter table public.images   enable row level security;
alter table public.ratings  enable row level security;
alter table public.comments enable row level security;
alter table public.requests enable row level security;

create policy "people read"  on public.people for select to authenticated using (true);
create policy "people claim" on public.people for update to authenticated
  using (email is null or email = auth.email())
  with check (email is null or email = auth.email());
create policy "people add"   on public.people for insert to authenticated
  with check (email = auth.email());

create policy "weeks all"    on public.weeks    for all to authenticated using (true) with check (true);
create policy "images all"   on public.images   for all to authenticated using (true) with check (true);
create policy "requests all" on public.requests for all to authenticated using (true) with check (true);

create policy "ratings read"   on public.ratings for select to authenticated
  using (public.is_admin() or person_id = public.current_person());
create policy "ratings insert" on public.ratings for insert to authenticated
  with check (person_id = public.current_person());
create policy "ratings update" on public.ratings for update to authenticated
  using (person_id = public.current_person())
  with check (person_id = public.current_person());
create policy "ratings delete" on public.ratings for delete to authenticated
  using (person_id = public.current_person());

create policy "comments read"   on public.comments for select to authenticated
  using (public.is_admin() or person_id = public.current_person());
create policy "comments insert" on public.comments for insert to authenticated
  with check (person_id = public.current_person());
create policy "comments update" on public.comments for update to authenticated
  using (person_id = public.current_person())
  with check (person_id = public.current_person());
create policy "comments delete" on public.comments for delete to authenticated
  using (person_id = public.current_person() or public.is_admin());

-- 5. storage: signed-in users only (was anon)
drop policy if exists "creatives read"   on storage.objects;
drop policy if exists "creatives upload" on storage.objects;
drop policy if exists "creatives delete" on storage.objects;
create policy "creatives read"   on storage.objects for select to authenticated using (bucket_id = 'creatives');
create policy "creatives upload" on storage.objects for insert to authenticated with check (bucket_id = 'creatives');
create policy "creatives delete" on storage.objects for delete to authenticated using (bucket_id = 'creatives');
