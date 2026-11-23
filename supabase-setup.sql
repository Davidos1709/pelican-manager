-- PELICAN OPS · shared live database
-- Run once in Supabase → SQL Editor. Safe to re-run.

create table if not exists public.ops_docs (
  id          text primary key,          -- e.g. mission:<uuid>, carnet:<uuid>, draft:<missionId>, equipment, settings
  kind        text not null,
  data        jsonb not null,
  updated_by  text,
  updated_at  timestamptz not null default now()
);

-- Allowlist: only these emails can read/write mission data
create table if not exists public.ops_members (
  email text primary key
);

alter table public.ops_docs    enable row level security;
alter table public.ops_members enable row level security;

create or replace function public.is_ops_member()
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.ops_members
    where lower(email) = lower(auth.jwt() ->> 'email')
  );
$$;

drop policy if exists "ops members read"   on public.ops_docs;
drop policy if exists "ops members insert" on public.ops_docs;
drop policy if exists "ops members update" on public.ops_docs;
drop policy if exists "ops members delete" on public.ops_docs;
create policy "ops members read"   on public.ops_docs for select to authenticated using (public.is_ops_member());
create policy "ops members insert" on public.ops_docs for insert to authenticated with check (public.is_ops_member());
create policy "ops members update" on public.ops_docs for update to authenticated using (public.is_ops_member()) with check (public.is_ops_member());
create policy "ops members delete" on public.ops_docs for delete to authenticated using (public.is_ops_member());

drop policy if exists "ops member sees self" on public.ops_members;
create policy "ops member sees self" on public.ops_members for select to authenticated
  using (lower(email) = lower(auth.jwt() ->> 'email'));

-- Live updates
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'ops_docs'
  ) then
    alter publication supabase_realtime add table public.ops_docs;
  end if;
end $$;

-- Authorized operators — add one line per team member (lowercase)
insert into public.ops_members (email) values
  ('davids5@rafael.co.il')
on conflict do nothing;
