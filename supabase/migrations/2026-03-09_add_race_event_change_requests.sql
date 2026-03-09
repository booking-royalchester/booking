begin;

create table if not exists public.race_event_change_requests (
  id uuid primary key default gen_random_uuid(),
  race_event_id uuid not null references public.race_events(id) on delete cascade,
  requested_by_member_id uuid not null references public.members(id) on delete cascade,
  previous_boat_ids uuid[] not null default '{}',
  requested_boat_ids uuid[] not null default '{}',
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  review_reason text,
  reviewed_by_member_id uuid references public.members(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists race_event_change_requests_status_idx
  on public.race_event_change_requests (status, created_at desc);

create index if not exists race_event_change_requests_race_event_idx
  on public.race_event_change_requests (race_event_id);

alter table public.race_event_change_requests enable row level security;

drop policy if exists "Race event requests readable" on public.race_event_change_requests;
create policy "Race event requests readable" on public.race_event_change_requests
  for select to authenticated
  using (
    requested_by_member_id = (select id from public.members where email = auth.email())
    or exists (
      select 1 from public.admins
      where member_id = (select id from public.members where email = auth.email())
    )
  );

drop policy if exists "Race event requests insert by requester" on public.race_event_change_requests;
create policy "Race event requests insert by requester" on public.race_event_change_requests
  for insert to authenticated
  with check (
    requested_by_member_id = (select id from public.members where email = auth.email())
    and status = 'pending'
  );

drop policy if exists "Race event requests update by admins" on public.race_event_change_requests;
create policy "Race event requests update by admins" on public.race_event_change_requests
  for update to authenticated
  using (
    exists (
      select 1 from public.admins
      where member_id = (select id from public.members where email = auth.email())
    )
  )
  with check (
    exists (
      select 1 from public.admins
      where member_id = (select id from public.members where email = auth.email())
    )
  );

commit;
