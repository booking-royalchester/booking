begin;

create table if not exists public.coordinator_groups (
  id uuid primary key default gen_random_uuid(),
  coordinator_member_id uuid not null references public.members(id) on delete cascade,
  title text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.coordinator_group_members (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.coordinator_groups(id) on delete cascade,
  email text not null,
  created_at timestamptz not null default now(),
  unique (group_id, email)
);

alter table public.coordinator_groups enable row level security;
alter table public.coordinator_group_members enable row level security;

drop policy if exists "Coordinator groups readable for owner" on public.coordinator_groups;
create policy "Coordinator groups readable for owner" on public.coordinator_groups
  for select to authenticated
  using (coordinator_member_id = (select id from public.members where email = auth.email()));

drop policy if exists "Coordinator groups insert for owner" on public.coordinator_groups;
create policy "Coordinator groups insert for owner" on public.coordinator_groups
  for insert to authenticated
  with check (coordinator_member_id = (select id from public.members where email = auth.email()));

drop policy if exists "Coordinator groups update for owner" on public.coordinator_groups;
create policy "Coordinator groups update for owner" on public.coordinator_groups
  for update to authenticated
  using (coordinator_member_id = (select id from public.members where email = auth.email()))
  with check (coordinator_member_id = (select id from public.members where email = auth.email()));

drop policy if exists "Coordinator groups delete for owner" on public.coordinator_groups;
create policy "Coordinator groups delete for owner" on public.coordinator_groups
  for delete to authenticated
  using (coordinator_member_id = (select id from public.members where email = auth.email()));

drop policy if exists "Coordinator group members readable for owner" on public.coordinator_group_members;
create policy "Coordinator group members readable for owner" on public.coordinator_group_members
  for select to authenticated
  using (
    exists (
      select 1
      from public.coordinator_groups cg
      where cg.id = group_id
        and cg.coordinator_member_id = (select id from public.members where email = auth.email())
    )
  );

drop policy if exists "Coordinator group members insert for owner" on public.coordinator_group_members;
create policy "Coordinator group members insert for owner" on public.coordinator_group_members
  for insert to authenticated
  with check (
    exists (
      select 1
      from public.coordinator_groups cg
      where cg.id = group_id
        and cg.coordinator_member_id = (select id from public.members where email = auth.email())
    )
  );

drop policy if exists "Coordinator group members update for owner" on public.coordinator_group_members;
create policy "Coordinator group members update for owner" on public.coordinator_group_members
  for update to authenticated
  using (
    exists (
      select 1
      from public.coordinator_groups cg
      where cg.id = group_id
        and cg.coordinator_member_id = (select id from public.members where email = auth.email())
    )
  )
  with check (
    exists (
      select 1
      from public.coordinator_groups cg
      where cg.id = group_id
        and cg.coordinator_member_id = (select id from public.members where email = auth.email())
    )
  );

drop policy if exists "Coordinator group members delete for owner" on public.coordinator_group_members;
create policy "Coordinator group members delete for owner" on public.coordinator_group_members
  for delete to authenticated
  using (
    exists (
      select 1
      from public.coordinator_groups cg
      where cg.id = group_id
        and cg.coordinator_member_id = (select id from public.members where email = auth.email())
    )
  );

commit;
