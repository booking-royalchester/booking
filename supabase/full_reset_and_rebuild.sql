-- WARNING: This resets the public schema and all application tables/data.
-- It does NOT delete Supabase Auth users from auth.users.
-- Run on the NEW Supabase project only if you want a clean rebuild.

begin;
drop schema if exists public cascade;
create schema public;
grant usage on schema public to postgres, anon, authenticated, service_role;
grant all on schema public to postgres, service_role;
alter default privileges in schema public grant all on tables to postgres, anon, authenticated, service_role;
alter default privileges in schema public grant all on functions to postgres, anon, authenticated, service_role;
alter default privileges in schema public grant all on sequences to postgres, anon, authenticated, service_role;
commit;

-- === supabase/schema.sql ===

create extension if not exists "pgcrypto";

create table if not exists members (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  email text not null unique,
  created_at timestamptz not null default now()
);

create table if not exists boats (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  type text,
  weight text,
  build_year text,
  usage_type text,
  in_service text,
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists race_events (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  start_date date not null,
  end_date date not null,
  driver text,
  loadin_plan jsonb not null default '{}'::jsonb,
  created_by uuid references members(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint race_events_date_range_check check (end_date >= start_date)
);

create table if not exists race_event_boats (
  id uuid primary key default gen_random_uuid(),
  race_event_id uuid not null references race_events(id) on delete cascade,
  boat_id uuid not null references boats(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (race_event_id, boat_id)
);

create table if not exists race_event_change_requests (
  id uuid primary key default gen_random_uuid(),
  race_event_id uuid not null references race_events(id) on delete cascade,
  requested_by_member_id uuid not null references members(id) on delete cascade,
  previous_boat_ids uuid[] not null default '{}',
  requested_boat_ids uuid[] not null default '{}',
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  review_reason text,
  reviewed_by_member_id uuid references members(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists coordinator_groups (
  id uuid primary key default gen_random_uuid(),
  coordinator_member_id uuid not null references members(id) on delete cascade,
  title text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists coordinator_group_members (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references coordinator_groups(id) on delete cascade,
  email text not null,
  created_at timestamptz not null default now(),
  unique (group_id, email)
);

create table if not exists bookings (
  id uuid primary key default gen_random_uuid(),
  boat_id uuid not null references boats(id) on delete cascade,
  member_id uuid references members(id) on delete set null,
  start_time timestamptz not null,
  end_time timestamptz not null,
  usage_status text not null default 'scheduled' check (usage_status in ('scheduled', 'pending', 'confirmed', 'cancelled')),
  usage_confirmed_at timestamptz,
  usage_confirmed_by uuid references members(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint end_after_start check (end_time > start_time)
);

create table if not exists booking_templates (
  id uuid primary key default gen_random_uuid(),
  season text not null default 'winter time' check (season in ('summer time', 'winter time')),
  weekday int not null check (weekday >= 0 and weekday <= 6),
  boat_id uuid references boats(id) on delete cascade,
  member_id uuid references members(id) on delete set null,
  start_time time not null,
  end_time time not null,
  boat_label text,
  member_label text,
  created_at timestamptz not null default now(),
  constraint template_end_after_start check (end_time > start_time)
);

create table if not exists template_season_settings (
  id int primary key,
  next_switch_date date,
  updated_at timestamptz not null default now()
);

create table if not exists risk_assessments (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references members(id) on delete cascade,
  coordinator_name text not null,
  session_date date not null,
  session_time text not null,
  crew_type text not null,
  boat_type text not null,
  launch_supervision text not null,
  visibility text not null,
  river_level text not null,
  water_conditions text not null,
  air_temperature text not null,
  wind_conditions text not null,
  risk_actions text not null,
  incoming_tide text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists booking_risk_assessments (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique references bookings(id) on delete cascade,
  risk_assessment_id uuid not null references risk_assessments(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists template_exceptions (
  id uuid primary key default gen_random_uuid(),
  template_id uuid not null references booking_templates(id) on delete cascade,
  exception_date date not null,
  reason text,
  created_at timestamptz not null default now(),
  unique (template_id, exception_date)
);

create table if not exists template_confirmations (
  id uuid primary key default gen_random_uuid(),
  template_id uuid not null references booking_templates(id) on delete cascade,
  member_id uuid not null references members(id) on delete cascade,
  occurrence_date date not null,
  status text not null default 'pending' check (status in ('pending', 'confirmed', 'cancelled')),
  booking_id uuid unique references bookings(id) on delete set null,
  notified_at timestamptz,
  responded_at timestamptz,
  created_at timestamptz not null default now(),
  unique (template_id, occurrence_date)
);

create table if not exists boat_permissions (
  boat_id uuid not null references boats(id) on delete cascade,
  member_id uuid not null references members(id) on delete cascade,
  permission_until date,
  created_at timestamptz not null default now(),
  primary key (boat_id, member_id)
);

create table if not exists captain_booking_requests (
  id uuid primary key default gen_random_uuid(),
  boat_id uuid not null references boats(id) on delete cascade,
  member_id uuid not null references members(id) on delete cascade,
  requested_start_time timestamptz not null,
  requested_end_time timestamptz not null,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  review_reason text,
  decided_at timestamptz,
  decided_by_member_id uuid references members(id) on delete set null,
  booking_id uuid references bookings(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists admins (
  member_id uuid primary key references members(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists allowed_member (
  id uuid primary key default gen_random_uuid(),
  email text unique not null,
  name text not null,
  role text not null default 'coordinator' check (role in ('admin', 'captain', 'coordinator', 'guest')),
  is_admin boolean not null default false,
  force_password_reset boolean not null default false,
  created_at timestamptz not null default now()
);

alter table allowed_member add column if not exists role text;
update allowed_member
set role = case when is_admin then 'admin' else 'coordinator' end
where role is null;
alter table allowed_member alter column role set default 'coordinator';
do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'allowed_member_role_check'
  ) then
    alter table allowed_member
      add constraint allowed_member_role_check
      check (role in ('admin', 'captain', 'coordinator', 'guest'));
  end if;
end
$$;
alter table allowed_member alter column role set not null;

create or replace function handle_allowed_member_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into members (name, email)
  values (new.name, lower(new.email))
  on conflict (email) do nothing;

  if coalesce(new.role, case when new.is_admin then 'admin' else 'coordinator' end) = 'admin' then
    insert into admins (member_id)
    select id from members where lower(email) = lower(new.email)
    on conflict do nothing;
  end if;

  return new;
end;
$$;

drop trigger if exists allowed_member_sync on allowed_member;
create trigger allowed_member_sync
after insert on allowed_member
for each row execute function handle_allowed_member_insert();

create index if not exists bookings_boat_time_idx on bookings (boat_id, start_time, end_time);

alter table members enable row level security;
alter table boats enable row level security;
alter table bookings enable row level security;
alter table admins enable row level security;
alter table allowed_member enable row level security;
alter table booking_templates enable row level security;
alter table template_season_settings enable row level security;
alter table risk_assessments enable row level security;
alter table booking_risk_assessments enable row level security;
alter table template_exceptions enable row level security;
alter table template_confirmations enable row level security;
alter table boat_permissions enable row level security;
alter table captain_booking_requests enable row level security;
alter table race_events enable row level security;
alter table race_event_boats enable row level security;
alter table race_event_change_requests enable row level security;
alter table coordinator_groups enable row level security;
alter table coordinator_group_members enable row level security;

drop policy if exists "Members readable for login" on members;
create policy "Members readable for login" on members
  for select to anon, authenticated
  using (true);

drop policy if exists "Members insert for authed" on members;
create policy "Members insert for authed" on members
  for insert to authenticated
  with check (
    lower(email) = lower(auth.email())
    and exists (
      select 1 from allowed_member
      where lower(email) = lower(auth.email())
    )
  );

drop policy if exists "Members delete for authed" on members;
create policy "Members delete for authed" on members
  for delete to authenticated
  using (
    exists (
      select 1 from admins
      where member_id = (select id from members where email = auth.email())
    )
  );

drop policy if exists "Boats readable for authed" on boats;
create policy "Boats readable for authed" on boats
  for select to authenticated
  using (true);

drop policy if exists "Boats insert for captains or admins" on boats;
create policy "Boats insert for captains or admins" on boats
  for insert to authenticated
  with check (
    exists (
      select 1 from admins
      where member_id = (select id from members where email = auth.email())
    )
    or exists (
      select 1
      from allowed_member am
      where lower(am.email) = lower(auth.email())
      and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
  );

drop policy if exists "Boats update for captains or admins" on boats;
create policy "Boats update for captains or admins" on boats
  for update to authenticated
  using (
    exists (
      select 1 from admins
      where member_id = (select id from members where email = auth.email())
    )
    or exists (
      select 1
      from allowed_member am
      where lower(am.email) = lower(auth.email())
      and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
  )
  with check (
    exists (
      select 1 from admins
      where member_id = (select id from members where email = auth.email())
    )
    or exists (
      select 1
      from allowed_member am
      where lower(am.email) = lower(auth.email())
      and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
  );

drop policy if exists "Boats delete for captains or admins" on boats;
create policy "Boats delete for captains or admins" on boats
  for delete to authenticated
  using (
    exists (
      select 1 from admins
      where member_id = (select id from members where email = auth.email())
    )
    or exists (
      select 1
      from allowed_member am
      where lower(am.email) = lower(auth.email())
      and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
  );

drop policy if exists "Race events readable for authed" on race_events;
create policy "Race events readable for authed" on race_events
  for select to authenticated
  using (true);

drop policy if exists "Race event boats readable for authed" on race_event_boats;
create policy "Race event boats readable for authed" on race_event_boats
  for select to authenticated
  using (true);

drop policy if exists "Race event requests readable" on race_event_change_requests;
create policy "Race event requests readable" on race_event_change_requests
  for select to authenticated
  using (
    requested_by_member_id = (select id from members where email = auth.email())
    or exists (
      select 1 from admins
      where member_id = (select id from members where email = auth.email())
    )
    or exists (
      select 1
      from allowed_member am
      where lower(am.email) = lower(auth.email())
      and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
  );

drop policy if exists "Captain booking requests readable" on captain_booking_requests;
create policy "Captain booking requests readable" on captain_booking_requests
  for select to authenticated
  using (
    member_id = (select id from members where email = auth.email())
    or exists (
      select 1 from admins
      where member_id = (select id from members where email = auth.email())
    )
    or exists (
      select 1
      from allowed_member am
      where lower(am.email) = lower(auth.email())
      and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
  );

drop policy if exists "Captain booking requests insert by requester" on captain_booking_requests;
create policy "Captain booking requests insert by requester" on captain_booking_requests
  for insert to authenticated
  with check (
    member_id = (select id from members where email = auth.email())
    and status = 'pending'
  );

drop policy if exists "Captain booking requests update by approvers" on captain_booking_requests;
create policy "Captain booking requests update by approvers" on captain_booking_requests
  for update to authenticated
  using (
    exists (
      select 1 from admins
      where member_id = (select id from members where email = auth.email())
    )
    or exists (
      select 1
      from allowed_member am
      where lower(am.email) = lower(auth.email())
      and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
  )
  with check (
    exists (
      select 1 from admins
      where member_id = (select id from members where email = auth.email())
    )
    or exists (
      select 1
      from allowed_member am
      where lower(am.email) = lower(auth.email())
      and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
  );

drop policy if exists "Race events insert for captains or admins" on race_events;
create policy "Race events insert for captains or admins" on race_events
  for insert to authenticated
  with check (
    exists (
      select 1 from admins
      where member_id = (select id from members where email = auth.email())
    )
    or exists (
      select 1
      from allowed_member am
      where lower(am.email) = lower(auth.email())
      and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
  );

drop policy if exists "Race events update for captains or admins" on race_events;
create policy "Race events update for captains or admins" on race_events
  for update to authenticated
  using (
    exists (
      select 1 from admins
      where member_id = (select id from members where email = auth.email())
    )
    or exists (
      select 1
      from allowed_member am
      where lower(am.email) = lower(auth.email())
      and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
  )
  with check (
    exists (
      select 1 from admins
      where member_id = (select id from members where email = auth.email())
    )
    or exists (
      select 1
      from allowed_member am
      where lower(am.email) = lower(auth.email())
      and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
  );

drop policy if exists "Race events delete for captains or admins" on race_events;
create policy "Race events delete for captains or admins" on race_events
  for delete to authenticated
  using (
    exists (
      select 1 from admins
      where member_id = (select id from members where email = auth.email())
    )
    or exists (
      select 1
      from allowed_member am
      where lower(am.email) = lower(auth.email())
      and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
  );

drop policy if exists "Race event boats insert for captains or admins" on race_event_boats;
create policy "Race event boats insert for captains or admins" on race_event_boats
  for insert to authenticated
  with check (
    exists (
      select 1 from admins
      where member_id = (select id from members where email = auth.email())
    )
    or exists (
      select 1
      from allowed_member am
      where lower(am.email) = lower(auth.email())
      and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
  );

drop policy if exists "Race event boats update for captains or admins" on race_event_boats;
create policy "Race event boats update for captains or admins" on race_event_boats
  for update to authenticated
  using (
    exists (
      select 1 from admins
      where member_id = (select id from members where email = auth.email())
    )
    or exists (
      select 1
      from allowed_member am
      where lower(am.email) = lower(auth.email())
      and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
  )
  with check (
    exists (
      select 1 from admins
      where member_id = (select id from members where email = auth.email())
    )
    or exists (
      select 1
      from allowed_member am
      where lower(am.email) = lower(auth.email())
      and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
  );

drop policy if exists "Race event boats delete for captains or admins" on race_event_boats;
create policy "Race event boats delete for captains or admins" on race_event_boats
  for delete to authenticated
  using (
    exists (
      select 1 from admins
      where member_id = (select id from members where email = auth.email())
    )
    or exists (
      select 1
      from allowed_member am
      where lower(am.email) = lower(auth.email())
      and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
  );

drop policy if exists "Race event requests insert by requester" on race_event_change_requests;
create policy "Race event requests insert by requester" on race_event_change_requests
  for insert to authenticated
  with check (
    requested_by_member_id = (select id from members where email = auth.email())
    and status = 'pending'
  );

drop policy if exists "Race event requests update by captains or admins" on race_event_change_requests;
create policy "Race event requests update by captains or admins" on race_event_change_requests
  for update to authenticated
  using (
    exists (
      select 1 from admins
      where member_id = (select id from members where email = auth.email())
    )
    or exists (
      select 1
      from allowed_member am
      where lower(am.email) = lower(auth.email())
      and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
  )
  with check (
    exists (
      select 1 from admins
      where member_id = (select id from members where email = auth.email())
    )
    or exists (
      select 1
      from allowed_member am
      where lower(am.email) = lower(auth.email())
      and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
  );

drop policy if exists "Coordinator groups readable for owner" on coordinator_groups;
create policy "Coordinator groups readable for owner" on coordinator_groups
  for select to authenticated
  using (coordinator_member_id = (select id from members where email = auth.email()));

drop policy if exists "Coordinator groups insert for owner" on coordinator_groups;
create policy "Coordinator groups insert for owner" on coordinator_groups
  for insert to authenticated
  with check (coordinator_member_id = (select id from members where email = auth.email()));

drop policy if exists "Coordinator groups update for owner" on coordinator_groups;
create policy "Coordinator groups update for owner" on coordinator_groups
  for update to authenticated
  using (coordinator_member_id = (select id from members where email = auth.email()))
  with check (coordinator_member_id = (select id from members where email = auth.email()));

drop policy if exists "Coordinator groups delete for owner" on coordinator_groups;
create policy "Coordinator groups delete for owner" on coordinator_groups
  for delete to authenticated
  using (coordinator_member_id = (select id from members where email = auth.email()));

drop policy if exists "Coordinator group members readable for owner" on coordinator_group_members;
create policy "Coordinator group members readable for owner" on coordinator_group_members
  for select to authenticated
  using (
    exists (
      select 1
      from coordinator_groups cg
      where cg.id = group_id
        and cg.coordinator_member_id = (select id from members where email = auth.email())
    )
  );

drop policy if exists "Coordinator group members insert for owner" on coordinator_group_members;
create policy "Coordinator group members insert for owner" on coordinator_group_members
  for insert to authenticated
  with check (
    exists (
      select 1
      from coordinator_groups cg
      where cg.id = group_id
        and cg.coordinator_member_id = (select id from members where email = auth.email())
    )
  );

drop policy if exists "Coordinator group members update for owner" on coordinator_group_members;
create policy "Coordinator group members update for owner" on coordinator_group_members
  for update to authenticated
  using (
    exists (
      select 1
      from coordinator_groups cg
      where cg.id = group_id
        and cg.coordinator_member_id = (select id from members where email = auth.email())
    )
  )
  with check (
    exists (
      select 1
      from coordinator_groups cg
      where cg.id = group_id
        and cg.coordinator_member_id = (select id from members where email = auth.email())
    )
  );

drop policy if exists "Coordinator group members delete for owner" on coordinator_group_members;
create policy "Coordinator group members delete for owner" on coordinator_group_members
  for delete to authenticated
  using (
    exists (
      select 1
      from coordinator_groups cg
      where cg.id = group_id
        and cg.coordinator_member_id = (select id from members where email = auth.email())
    )
  );

drop policy if exists "Bookings readable for authed" on bookings;
create policy "Bookings readable for authed" on bookings
  for select to authenticated
  using (true);

drop policy if exists "Templates readable for authed" on booking_templates;
create policy "Templates readable for authed" on booking_templates
  for select to authenticated
  using (true);

drop policy if exists "Template season settings readable for authed" on template_season_settings;
create policy "Template season settings readable for authed" on template_season_settings
  for select to authenticated
  using (true);

drop policy if exists "Templates insert for captains or admins" on booking_templates;
create policy "Templates insert for captains or admins" on booking_templates
  for insert to authenticated
  with check (
    exists (
      select 1 from admins
      where member_id = (select id from members where email = auth.email())
    )
    or exists (
      select 1
      from allowed_member am
      where lower(am.email) = lower(auth.email())
      and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
  );

drop policy if exists "Templates update for captains or admins" on booking_templates;
create policy "Templates update for captains or admins" on booking_templates
  for update to authenticated
  using (
    exists (
      select 1 from admins
      where member_id = (select id from members where email = auth.email())
    )
    or exists (
      select 1
      from allowed_member am
      where lower(am.email) = lower(auth.email())
      and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
  )
  with check (
    exists (
      select 1 from admins
      where member_id = (select id from members where email = auth.email())
    )
    or exists (
      select 1
      from allowed_member am
      where lower(am.email) = lower(auth.email())
      and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
  );

drop policy if exists "Template season settings upsert for captains or admins" on template_season_settings;
create policy "Template season settings upsert for captains or admins" on template_season_settings
  for all to authenticated
  using (
    exists (
      select 1 from admins
      where member_id = (select id from members where email = auth.email())
    )
    or exists (
      select 1
      from allowed_member am
      where lower(am.email) = lower(auth.email())
      and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
  )
  with check (
    exists (
      select 1 from admins
      where member_id = (select id from members where email = auth.email())
    )
    or exists (
      select 1
      from allowed_member am
      where lower(am.email) = lower(auth.email())
      and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
  );

drop policy if exists "Risk assessments readable for authed" on risk_assessments;
create policy "Risk assessments readable for authed" on risk_assessments
  for select to authenticated
  using (
    member_id = (select id from members where email = auth.email())
    or exists (
      select 1 from admins
      where member_id = (select id from members where email = auth.email())
    )
  );

drop policy if exists "Risk assessments insert for authed" on risk_assessments;
create policy "Risk assessments insert for authed" on risk_assessments
  for insert to authenticated
  with check (
    member_id = (select id from members where email = auth.email())
    or exists (
      select 1 from admins
      where member_id = (select id from members where email = auth.email())
    )
  );

drop policy if exists "Risk assessments update for authed" on risk_assessments;
create policy "Risk assessments update for authed" on risk_assessments
  for update to authenticated
  using (
    member_id = (select id from members where email = auth.email())
    or exists (
      select 1 from admins
      where member_id = (select id from members where email = auth.email())
    )
  )
  with check (
    member_id = (select id from members where email = auth.email())
    or exists (
      select 1 from admins
      where member_id = (select id from members where email = auth.email())
    )
  );

drop policy if exists "Booking risk assessments readable for authed" on booking_risk_assessments;
create policy "Booking risk assessments readable for authed" on booking_risk_assessments
  for select to authenticated
  using (
    exists (
      select 1
      from risk_assessments ra
      where ra.id = risk_assessment_id
      and (
        ra.member_id = (select id from members where email = auth.email())
        or exists (
          select 1 from admins
          where member_id = (select id from members where email = auth.email())
        )
      )
    )
  );

drop policy if exists "Booking risk assessments insert for authed" on booking_risk_assessments;
create policy "Booking risk assessments insert for authed" on booking_risk_assessments
  for insert to authenticated
  with check (
    exists (
      select 1
      from risk_assessments ra
      where ra.id = risk_assessment_id
      and (
        ra.member_id = (select id from members where email = auth.email())
        or exists (
          select 1 from admins
          where member_id = (select id from members where email = auth.email())
        )
      )
    )
    and (
      exists (
        select 1 from bookings b
        where b.id = booking_id
        and b.member_id = (select id from members where email = auth.email())
      )
      or exists (
        select 1 from admins
        where member_id = (select id from members where email = auth.email())
      )
    )
  );

drop policy if exists "Booking risk assessments update for authed" on booking_risk_assessments;
create policy "Booking risk assessments update for authed" on booking_risk_assessments
  for update to authenticated
  using (
    exists (
      select 1
      from risk_assessments ra
      where ra.id = risk_assessment_id
      and (
        ra.member_id = (select id from members where email = auth.email())
        or exists (
          select 1 from admins
          where member_id = (select id from members where email = auth.email())
        )
      )
    )
  )
  with check (
    exists (
      select 1
      from risk_assessments ra
      where ra.id = risk_assessment_id
      and (
        ra.member_id = (select id from members where email = auth.email())
        or exists (
          select 1 from admins
          where member_id = (select id from members where email = auth.email())
        )
      )
    )
  );

drop policy if exists "Templates delete for captains or admins" on booking_templates;
create policy "Templates delete for captains or admins" on booking_templates
  for delete to authenticated
  using (
    exists (
      select 1 from admins
      where member_id = (select id from members where email = auth.email())
    )
    or exists (
      select 1
      from allowed_member am
      where lower(am.email) = lower(auth.email())
      and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
  );

drop policy if exists "Template exceptions readable for authed" on template_exceptions;
create policy "Template exceptions readable for authed" on template_exceptions
  for select to authenticated
  using (true);

drop policy if exists "Template exceptions insert for captains or admins" on template_exceptions;
create policy "Template exceptions insert for captains or admins" on template_exceptions
  for insert to authenticated
  with check (
    exists (
      select 1 from admins
      where member_id = (select id from members where email = auth.email())
    )
    or exists (
      select 1
      from allowed_member am
      where lower(am.email) = lower(auth.email())
      and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
  );

drop policy if exists "Template exceptions delete for captains or admins" on template_exceptions;
create policy "Template exceptions delete for captains or admins" on template_exceptions
  for delete to authenticated
  using (
    exists (
      select 1 from admins
      where member_id = (select id from members where email = auth.email())
    )
    or exists (
      select 1
      from allowed_member am
      where lower(am.email) = lower(auth.email())
      and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
  );

drop policy if exists "Template confirmations readable for authed" on template_confirmations;
create policy "Template confirmations readable for authed" on template_confirmations
  for select to authenticated
  using (
    member_id = (select id from members where email = auth.email())
    or exists (
      select 1 from admins
      where member_id = (select id from members where email = auth.email())
    )
  );

drop policy if exists "Template confirmations insert for authed" on template_confirmations;
create policy "Template confirmations insert for authed" on template_confirmations
  for insert to authenticated
  with check (
    member_id = (select id from members where email = auth.email())
    or exists (
      select 1 from admins
      where member_id = (select id from members where email = auth.email())
    )
  );

drop policy if exists "Template confirmations update for authed" on template_confirmations;
create policy "Template confirmations update for authed" on template_confirmations
  for update to authenticated
  using (
    member_id = (select id from members where email = auth.email())
    or exists (
      select 1 from admins
      where member_id = (select id from members where email = auth.email())
    )
  )
  with check (
    member_id = (select id from members where email = auth.email())
    or exists (
      select 1 from admins
      where member_id = (select id from members where email = auth.email())
    )
  );

drop policy if exists "Boat permissions readable for authed" on boat_permissions;
create policy "Boat permissions readable for authed" on boat_permissions
  for select to authenticated
  using (true);

drop policy if exists "Boat permissions insert for captains or admins" on boat_permissions;
create policy "Boat permissions insert for captains or admins" on boat_permissions
  for insert to authenticated
  with check (
    exists (
      select 1 from admins
      where member_id = (select id from members where email = auth.email())
    )
    or exists (
      select 1
      from allowed_member am
      where lower(am.email) = lower(auth.email())
      and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
  );

drop policy if exists "Boat permissions delete for captains or admins" on boat_permissions;
create policy "Boat permissions delete for captains or admins" on boat_permissions
  for delete to authenticated
  using (
    exists (
      select 1 from admins
      where member_id = (select id from members where email = auth.email())
    )
    or exists (
      select 1
      from allowed_member am
      where lower(am.email) = lower(auth.email())
      and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
  );

drop policy if exists "Bookings insert for authed" on bookings;
create policy "Bookings insert for authed" on bookings
  for insert to authenticated
  with check (
    exists (
      select 1
      from allowed_member am
      where lower(am.email) = lower(auth.email())
      and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end)
        in ('admin', 'captain', 'coordinator')
    )
    and (
      member_id = (select id from members where email = auth.email())
      or exists (
        select 1 from admins
        where member_id = (select id from members where email = auth.email())
      )
      or exists (
        select 1
        from allowed_member am
        where lower(am.email) = lower(auth.email())
        and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
      )
    )
  );

drop policy if exists "Bookings update for authed" on bookings;
create policy "Bookings update for authed" on bookings
  for update to authenticated
  using (
    exists (
      select 1
      from allowed_member am
      where lower(am.email) = lower(auth.email())
      and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) in ('admin', 'coordinator')
    )
    and (
      member_id = (select id from members where email = auth.email())
      or exists (
        select 1 from admins
        where member_id = (select id from members where email = auth.email())
      )
    )
  )
  with check (
    exists (
      select 1
      from allowed_member am
      where lower(am.email) = lower(auth.email())
      and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) in ('admin', 'coordinator')
    )
    and (
      member_id = (select id from members where email = auth.email())
      or exists (
        select 1 from admins
        where member_id = (select id from members where email = auth.email())
      )
    )
  );

drop policy if exists "Bookings delete for authed" on bookings;
create policy "Bookings delete for authed" on bookings
  for delete to authenticated
  using (
    exists (
      select 1
      from allowed_member am
      where lower(am.email) = lower(auth.email())
      and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) in ('admin', 'coordinator')
    )
    and (
      member_id = (select id from members where email = auth.email())
      or exists (
        select 1 from admins
        where member_id = (select id from members where email = auth.email())
      )
    )
  );

drop policy if exists "Admins self readable" on admins;
create policy "Admins self readable" on admins
  for select to authenticated
  using (
    member_id = (select id from members where email = auth.email())
  );

drop policy if exists "Admins insert for authed" on admins;
create policy "Admins insert for authed" on admins
  for insert to authenticated
  with check (
    exists (
      select 1
      from allowed_member am
      join members m on m.id = member_id
      where m.email = auth.email()
      and am.email = m.email
      and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'admin'
    )
  );

drop policy if exists "Admins delete for authed" on admins;
create policy "Admins delete for authed" on admins
  for delete to authenticated
  using (
    exists (
      select 1 from admins
      where member_id = (select id from members where email = auth.email())
    )
  );

drop policy if exists "Allowed members readable" on allowed_member;
create policy "Allowed members readable" on allowed_member
  for select to anon, authenticated
  using (true);

drop policy if exists "Allowed members insert for authed" on allowed_member;
create policy "Allowed members insert for authed" on allowed_member
  for insert to authenticated
  with check (
    (
      exists (
        select 1 from admins
        where member_id = (select id from members where email = auth.email())
      )
      and coalesce(role, case when is_admin then 'admin' else 'coordinator' end) in ('admin', 'captain', 'coordinator', 'guest')
    )
    or (
      exists (
        select 1
        from allowed_member am
        where lower(am.email) = lower(auth.email())
        and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
      )
      and coalesce(role, case when is_admin then 'admin' else 'coordinator' end) in ('captain', 'coordinator', 'guest')
      and coalesce(is_admin, false) = false
    )
    or (
      exists (
        select 1
        from allowed_member am
        where lower(am.email) = lower(auth.email())
        and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'coordinator'
      )
      and coalesce(role, case when is_admin then 'admin' else 'coordinator' end) = 'guest'
      and coalesce(is_admin, false) = false
    )
  );

drop policy if exists "Allowed members delete for authed" on allowed_member;
create policy "Allowed members delete for authed" on allowed_member
  for delete to authenticated
  using (
    exists (
      select 1 from admins
      where member_id = (select id from members where email = auth.email())
    )
  );

create table if not exists push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references members(id) on delete cascade,
  endpoint text not null unique,
  p256dh text not null,
  auth text not null,
  user_agent text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists booking_reminders (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references bookings(id) on delete cascade,
  remind_at timestamptz not null,
  created_at timestamptz not null default now(),
  unique (booking_id, remind_at)
);

create table if not exists booking_usage_notifications (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references bookings(id) on delete cascade,
  notified_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (booking_id)
);

create index if not exists push_subscriptions_member_idx on push_subscriptions (member_id);
create index if not exists booking_reminders_booking_idx on booking_reminders (booking_id);
create index if not exists bookings_usage_status_idx on bookings (usage_status, end_time);
create index if not exists booking_usage_notifications_booking_idx on booking_usage_notifications (booking_id);

alter table push_subscriptions enable row level security;
alter table booking_reminders enable row level security;
alter table booking_usage_notifications enable row level security;

drop policy if exists "Push subscriptions readable for authed" on push_subscriptions;
create policy "Push subscriptions readable for authed" on push_subscriptions
  for select to authenticated
  using (
    member_id = (select id from members where email = auth.email())
  );

drop policy if exists "Push subscriptions insert for authed" on push_subscriptions;
create policy "Push subscriptions insert for authed" on push_subscriptions
  for insert to authenticated
  with check (
    member_id = (select id from members where email = auth.email())
  );

drop policy if exists "Push subscriptions delete for authed" on push_subscriptions;
create policy "Push subscriptions delete for authed" on push_subscriptions
  for delete to authenticated
  using (
    member_id = (select id from members where email = auth.email())
  );


-- === supabase/migrations/2026-02-26_add_roles_admin_coordinator_guest.sql ===

-- Migration: introduce explicit roles in allowed_member
-- Roles:
-- - admin
-- - coordinator
-- - guest (read-only)
--
-- This migration is intended for an existing database.

begin;

-- 1) Add explicit role column and backfill from legacy is_admin flag.
alter table public.allowed_member
  add column if not exists role text;

update public.allowed_member
set role = case when is_admin then 'admin' else 'coordinator' end
where role is null;

alter table public.allowed_member
  alter column role set default 'coordinator';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'allowed_member_role_check'
  ) then
    alter table public.allowed_member
      add constraint allowed_member_role_check
      check (role in ('admin', 'coordinator', 'guest'));
  end if;
end
$$;

alter table public.allowed_member
  alter column role set not null;

-- Keep legacy boolean in sync for compatibility with existing code/policies.
update public.allowed_member
set is_admin = (role = 'admin')
where is_admin is distinct from (role = 'admin');

-- 2) Update trigger so only role=admin creates an admins row.
create or replace function public.handle_allowed_member_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into members (name, email)
  values (new.name, lower(new.email))
  on conflict (email) do nothing;

  if coalesce(new.role, case when new.is_admin then 'admin' else 'coordinator' end) = 'admin' then
    insert into admins (member_id)
    select id from members where lower(email) = lower(new.email)
    on conflict do nothing;
  end if;

  return new;
end;
$$;

-- 3) Guests are read-only for bookings.
drop policy if exists "Bookings insert for authed" on public.bookings;
drop policy if exists "Bookings insert for authed" on public.bookings;
create policy "Bookings insert for authed" on public.bookings
  for insert to authenticated
  with check (
    exists (
      select 1
      from public.allowed_member am
      where lower(am.email) = lower(auth.email())
        and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end)
          in ('admin', 'coordinator')
    )
    and (
      member_id = (select id from public.members where email = auth.email())
      or exists (
        select 1 from public.admins
        where member_id = (select id from public.members where email = auth.email())
      )
    )
  );

drop policy if exists "Bookings update for authed" on public.bookings;
drop policy if exists "Bookings update for authed" on public.bookings;
create policy "Bookings update for authed" on public.bookings
  for update to authenticated
  using (
    exists (
      select 1
      from public.allowed_member am
      where lower(am.email) = lower(auth.email())
        and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end)
          in ('admin', 'coordinator')
    )
    and (
      member_id = (select id from public.members where email = auth.email())
      or exists (
        select 1 from public.admins
        where member_id = (select id from public.members where email = auth.email())
      )
    )
  )
  with check (
    exists (
      select 1
      from public.allowed_member am
      where lower(am.email) = lower(auth.email())
        and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end)
          in ('admin', 'coordinator')
    )
    and (
      member_id = (select id from public.members where email = auth.email())
      or exists (
        select 1 from public.admins
        where member_id = (select id from public.members where email = auth.email())
      )
    )
  );

drop policy if exists "Bookings delete for authed" on public.bookings;
drop policy if exists "Bookings delete for authed" on public.bookings;
create policy "Bookings delete for authed" on public.bookings
  for delete to authenticated
  using (
    exists (
      select 1
      from public.allowed_member am
      where lower(am.email) = lower(auth.email())
        and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end)
          in ('admin', 'coordinator')
    )
    and (
      member_id = (select id from public.members where email = auth.email())
      or exists (
        select 1 from public.admins
        where member_id = (select id from public.members where email = auth.email())
      )
    )
  );

-- 4) Guests cannot skip template bookings (template exceptions).
drop policy if exists "Template exceptions insert for authed" on public.template_exceptions;
drop policy if exists "Template exceptions insert for authed" on public.template_exceptions;
create policy "Template exceptions insert for authed" on public.template_exceptions
  for insert to authenticated
  with check (
    exists (
      select 1 from public.booking_templates bt
      where bt.id = template_id
        and exists (
          select 1
          from public.allowed_member am
          where lower(am.email) = lower(auth.email())
            and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end)
              in ('admin', 'coordinator')
        )
        and (
          bt.member_id = (select id from public.members where email = auth.email())
          or exists (
            select 1 from public.admins
            where member_id = (select id from public.members where email = auth.email())
          )
        )
    )
  );

drop policy if exists "Template exceptions delete for authed" on public.template_exceptions;
drop policy if exists "Template exceptions delete for authed" on public.template_exceptions;
create policy "Template exceptions delete for authed" on public.template_exceptions
  for delete to authenticated
  using (
    exists (
      select 1 from public.booking_templates bt
      where bt.id = template_id
        and exists (
          select 1
          from public.allowed_member am
          where lower(am.email) = lower(auth.email())
            and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end)
              in ('admin', 'coordinator')
        )
        and (
          bt.member_id = (select id from public.members where email = auth.email())
          or exists (
            select 1 from public.admins
            where member_id = (select id from public.members where email = auth.email())
          )
        )
    )
  );

-- 5) Coordinators can add guests only; admins can add admins/coordinators.
drop policy if exists "Allowed members insert for authed" on public.allowed_member;
drop policy if exists "Allowed members insert for authed" on public.allowed_member;
create policy "Allowed members insert for authed" on public.allowed_member
  for insert to authenticated
  with check (
    (
      exists (
        select 1 from public.admins
        where member_id = (select id from public.members where email = auth.email())
      )
      and coalesce(role, case when is_admin then 'admin' else 'coordinator' end)
        in ('admin', 'coordinator', 'guest')
    )
    or (
      exists (
        select 1
        from public.allowed_member am
        where lower(am.email) = lower(auth.email())
          and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end)
            = 'coordinator'
      )
      and coalesce(role, case when is_admin then 'admin' else 'coordinator' end) = 'guest'
      and coalesce(is_admin, false) = false
    )
  );

commit;


-- === supabase/migrations/2026-02-27_add_booking_usage_confirmation.sql ===

-- Migration: track actual boat usage after a booking ends.
--
-- Booking lifecycle:
-- - scheduled: booking exists, not yet awaiting confirmation
-- - pending: booking ended, member must confirm if the outing actually happened
-- - confirmed: outing happened
-- - cancelled: outing did not happen

begin;

alter table public.bookings
  add column if not exists usage_status text;

alter table public.bookings
  add column if not exists usage_confirmed_at timestamptz;

alter table public.bookings
  add column if not exists usage_confirmed_by uuid references public.members(id) on delete set null;

update public.bookings
set usage_status = 'scheduled'
where usage_status is null;

alter table public.bookings
  alter column usage_status set default 'scheduled';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'bookings_usage_status_check'
  ) then
    alter table public.bookings
      add constraint bookings_usage_status_check
      check (usage_status in ('scheduled', 'pending', 'confirmed', 'cancelled'));
  end if;
end
$$;

alter table public.bookings
  alter column usage_status set not null;

create index if not exists bookings_usage_status_idx
  on public.bookings (usage_status, end_time);

create table if not exists public.booking_usage_notifications (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  notified_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (booking_id)
);

create index if not exists booking_usage_notifications_booking_idx
  on public.booking_usage_notifications (booking_id);

alter table public.booking_usage_notifications enable row level security;

commit;


-- === supabase/migrations/2026-02-27_add_risk_assessments.sql ===

begin;

create table if not exists public.risk_assessments (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique references public.bookings(id) on delete cascade,
  member_id uuid not null references public.members(id) on delete cascade,
  coordinator_name text not null,
  session_date date not null,
  session_time text not null,
  crew_type text not null,
  boat_type text not null,
  launch_supervision text not null,
  visibility text not null,
  river_level text not null,
  water_conditions text not null,
  air_temperature text not null,
  wind_conditions text not null,
  risk_actions text not null,
  incoming_tide text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.risk_assessments enable row level security;

drop policy if exists "Risk assessments readable for authed" on public.risk_assessments;
drop policy if exists "Risk assessments readable for authed" on public.risk_assessments;
create policy "Risk assessments readable for authed" on public.risk_assessments
  for select to authenticated
  using (
    member_id = (select id from public.members where email = auth.email())
    or exists (
      select 1 from public.admins
      where member_id = (select id from public.members where email = auth.email())
    )
  );

drop policy if exists "Risk assessments insert for authed" on public.risk_assessments;
drop policy if exists "Risk assessments insert for authed" on public.risk_assessments;
create policy "Risk assessments insert for authed" on public.risk_assessments
  for insert to authenticated
  with check (
    member_id = (select id from public.members where email = auth.email())
    or exists (
      select 1 from public.admins
      where member_id = (select id from public.members where email = auth.email())
    )
  );

drop policy if exists "Risk assessments update for authed" on public.risk_assessments;
drop policy if exists "Risk assessments update for authed" on public.risk_assessments;
create policy "Risk assessments update for authed" on public.risk_assessments
  for update to authenticated
  using (
    member_id = (select id from public.members where email = auth.email())
    or exists (
      select 1 from public.admins
      where member_id = (select id from public.members where email = auth.email())
    )
  )
  with check (
    member_id = (select id from public.members where email = auth.email())
    or exists (
      select 1 from public.admins
      where member_id = (select id from public.members where email = auth.email())
    )
  );

commit;


-- === supabase/migrations/2026-02-27_add_template_confirmations.sql ===

begin;

create table if not exists public.template_confirmations (
  id uuid primary key default gen_random_uuid(),
  template_id uuid not null references public.booking_templates(id) on delete cascade,
  member_id uuid not null references public.members(id) on delete cascade,
  occurrence_date date not null,
  status text not null default 'pending' check (status in ('pending', 'confirmed', 'cancelled')),
  booking_id uuid unique references public.bookings(id) on delete set null,
  notified_at timestamptz,
  responded_at timestamptz,
  created_at timestamptz not null default now(),
  unique (template_id, occurrence_date)
);

alter table public.template_confirmations enable row level security;

drop policy if exists "Template confirmations readable for authed" on public.template_confirmations;
drop policy if exists "Template confirmations readable for authed" on public.template_confirmations;
create policy "Template confirmations readable for authed" on public.template_confirmations
  for select to authenticated
  using (
    member_id = (select id from public.members where email = auth.email())
    or exists (
      select 1 from public.admins
      where member_id = (select id from public.members where email = auth.email())
    )
  );

drop policy if exists "Template confirmations insert for authed" on public.template_confirmations;
drop policy if exists "Template confirmations insert for authed" on public.template_confirmations;
create policy "Template confirmations insert for authed" on public.template_confirmations
  for insert to authenticated
  with check (
    member_id = (select id from public.members where email = auth.email())
    or exists (
      select 1 from public.admins
      where member_id = (select id from public.members where email = auth.email())
    )
  );

drop policy if exists "Template confirmations update for authed" on public.template_confirmations;
drop policy if exists "Template confirmations update for authed" on public.template_confirmations;
create policy "Template confirmations update for authed" on public.template_confirmations
  for update to authenticated
  using (
    member_id = (select id from public.members where email = auth.email())
    or exists (
      select 1 from public.admins
      where member_id = (select id from public.members where email = auth.email())
    )
  )
  with check (
    member_id = (select id from public.members where email = auth.email())
    or exists (
      select 1 from public.admins
      where member_id = (select id from public.members where email = auth.email())
    )
  );

commit;


-- === supabase/migrations/2026-02-27_refactor_risk_assessments_multi_booking.sql ===

begin;

create table if not exists public.booking_risk_assessments (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique references public.bookings(id) on delete cascade,
  risk_assessment_id uuid not null references public.risk_assessments(id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.booking_risk_assessments enable row level security;

drop policy if exists "Booking risk assessments readable for authed" on public.booking_risk_assessments;
drop policy if exists "Booking risk assessments readable for authed" on public.booking_risk_assessments;
create policy "Booking risk assessments readable for authed" on public.booking_risk_assessments
  for select to authenticated
  using (
    exists (
      select 1
      from public.risk_assessments ra
      where ra.id = risk_assessment_id
        and (
          ra.member_id = (select id from public.members where email = auth.email())
          or exists (
            select 1 from public.admins
            where member_id = (select id from public.members where email = auth.email())
          )
        )
    )
  );

drop policy if exists "Booking risk assessments insert for authed" on public.booking_risk_assessments;
drop policy if exists "Booking risk assessments insert for authed" on public.booking_risk_assessments;
create policy "Booking risk assessments insert for authed" on public.booking_risk_assessments
  for insert to authenticated
  with check (
    exists (
      select 1
      from public.risk_assessments ra
      where ra.id = risk_assessment_id
        and (
          ra.member_id = (select id from public.members where email = auth.email())
          or exists (
            select 1 from public.admins
            where member_id = (select id from public.members where email = auth.email())
          )
        )
    )
    and (
      exists (
        select 1
        from public.bookings b
        where b.id = booking_id
          and b.member_id = (select id from public.members where email = auth.email())
      )
      or exists (
        select 1 from public.admins
        where member_id = (select id from public.members where email = auth.email())
      )
    )
  );

drop policy if exists "Booking risk assessments update for authed" on public.booking_risk_assessments;
drop policy if exists "Booking risk assessments update for authed" on public.booking_risk_assessments;
create policy "Booking risk assessments update for authed" on public.booking_risk_assessments
  for update to authenticated
  using (
    exists (
      select 1
      from public.risk_assessments ra
      where ra.id = risk_assessment_id
        and (
          ra.member_id = (select id from public.members where email = auth.email())
          or exists (
            select 1 from public.admins
            where member_id = (select id from public.members where email = auth.email())
          )
        )
    )
  )
  with check (
    exists (
      select 1
      from public.risk_assessments ra
      where ra.id = risk_assessment_id
        and (
          ra.member_id = (select id from public.members where email = auth.email())
          or exists (
            select 1 from public.admins
            where member_id = (select id from public.members where email = auth.email())
          )
        )
    )
  );

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'risk_assessments'
      and column_name = 'booking_id'
  ) then
    execute '
      insert into public.booking_risk_assessments (booking_id, risk_assessment_id)
      select booking_id, id
      from public.risk_assessments
      where booking_id is not null
      on conflict (booking_id) do update
      set risk_assessment_id = excluded.risk_assessment_id
    ';

    execute 'alter table public.risk_assessments drop column booking_id';
  end if;
end
$$;

commit;


-- === supabase/migrations/2026-02-28_add_race_events.sql ===

begin;

create table if not exists public.race_events (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  event_date date not null,
  created_by uuid references public.members(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.race_event_boats (
  id uuid primary key default gen_random_uuid(),
  race_event_id uuid not null references public.race_events(id) on delete cascade,
  boat_id uuid not null references public.boats(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (race_event_id, boat_id)
);

alter table public.race_events enable row level security;
alter table public.race_event_boats enable row level security;

drop policy if exists "Race events readable for authed" on public.race_events;
drop policy if exists "Race events readable for authed" on public.race_events;
create policy "Race events readable for authed" on public.race_events
  for select to authenticated
  using (true);

drop policy if exists "Race event boats readable for authed" on public.race_event_boats;
drop policy if exists "Race event boats readable for authed" on public.race_event_boats;
create policy "Race event boats readable for authed" on public.race_event_boats
  for select to authenticated
  using (true);

drop policy if exists "Race events insert for admins" on public.race_events;
drop policy if exists "Race events insert for admins" on public.race_events;
create policy "Race events insert for admins" on public.race_events
  for insert to authenticated
  with check (
    exists (
      select 1 from public.admins
      where member_id = (select id from public.members where email = auth.email())
    )
  );

drop policy if exists "Race events update for admins" on public.race_events;
drop policy if exists "Race events update for admins" on public.race_events;
create policy "Race events update for admins" on public.race_events
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

drop policy if exists "Race events delete for admins" on public.race_events;
drop policy if exists "Race events delete for admins" on public.race_events;
create policy "Race events delete for admins" on public.race_events
  for delete to authenticated
  using (
    exists (
      select 1 from public.admins
      where member_id = (select id from public.members where email = auth.email())
    )
  );

drop policy if exists "Race event boats insert for admins" on public.race_event_boats;
drop policy if exists "Race event boats insert for admins" on public.race_event_boats;
create policy "Race event boats insert for admins" on public.race_event_boats
  for insert to authenticated
  with check (
    exists (
      select 1 from public.admins
      where member_id = (select id from public.members where email = auth.email())
    )
  );

drop policy if exists "Race event boats update for admins" on public.race_event_boats;
drop policy if exists "Race event boats update for admins" on public.race_event_boats;
create policy "Race event boats update for admins" on public.race_event_boats
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

drop policy if exists "Race event boats delete for admins" on public.race_event_boats;
drop policy if exists "Race event boats delete for admins" on public.race_event_boats;
create policy "Race event boats delete for admins" on public.race_event_boats
  for delete to authenticated
  using (
    exists (
      select 1 from public.admins
      where member_id = (select id from public.members where email = auth.email())
    )
  );

commit;


-- === supabase/migrations/2026-03-08_add_coordinator_groups.sql ===

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
drop policy if exists "Coordinator groups readable for owner" on public.coordinator_groups;
create policy "Coordinator groups readable for owner" on public.coordinator_groups
  for select to authenticated
  using (coordinator_member_id = (select id from public.members where email = auth.email()));

drop policy if exists "Coordinator groups insert for owner" on public.coordinator_groups;
drop policy if exists "Coordinator groups insert for owner" on public.coordinator_groups;
create policy "Coordinator groups insert for owner" on public.coordinator_groups
  for insert to authenticated
  with check (coordinator_member_id = (select id from public.members where email = auth.email()));

drop policy if exists "Coordinator groups update for owner" on public.coordinator_groups;
drop policy if exists "Coordinator groups update for owner" on public.coordinator_groups;
create policy "Coordinator groups update for owner" on public.coordinator_groups
  for update to authenticated
  using (coordinator_member_id = (select id from public.members where email = auth.email()))
  with check (coordinator_member_id = (select id from public.members where email = auth.email()));

drop policy if exists "Coordinator groups delete for owner" on public.coordinator_groups;
drop policy if exists "Coordinator groups delete for owner" on public.coordinator_groups;
create policy "Coordinator groups delete for owner" on public.coordinator_groups
  for delete to authenticated
  using (coordinator_member_id = (select id from public.members where email = auth.email()));

drop policy if exists "Coordinator group members readable for owner" on public.coordinator_group_members;
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


-- === supabase/migrations/2026-03-08_update_race_events_date_range_driver.sql ===

begin;

alter table public.race_events
  add column if not exists start_date date,
  add column if not exists end_date date,
  add column if not exists driver text;

alter table public.race_events
  alter column start_date set not null,
  alter column end_date set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'race_events_date_range_check'
  ) then
    alter table public.race_events
      add constraint race_events_date_range_check
      check (end_date >= start_date);
  end if;
end
$$;

commit;


-- === supabase/migrations/2026-03-09_add_captain_booking_requests_and_permission_expiry.sql ===

begin;

alter table public.boat_permissions
  add column if not exists permission_until date;

create table if not exists public.captain_booking_requests (
  id uuid primary key default gen_random_uuid(),
  boat_id uuid not null references public.boats(id) on delete cascade,
  member_id uuid not null references public.members(id) on delete cascade,
  requested_start_time timestamptz not null,
  requested_end_time timestamptz not null,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  review_reason text,
  decided_at timestamptz,
  decided_by_member_id uuid references public.members(id) on delete set null,
  booking_id uuid references public.bookings(id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists captain_booking_requests_status_idx
  on public.captain_booking_requests (status, created_at);

alter table public.captain_booking_requests enable row level security;

drop policy if exists "Captain booking requests readable" on public.captain_booking_requests;
drop policy if exists "Captain booking requests readable" on public.captain_booking_requests;
create policy "Captain booking requests readable" on public.captain_booking_requests
  for select to authenticated
  using (
    member_id = (select id from public.members where email = auth.email())
    or exists (
      select 1 from public.admins
      where member_id = (select id from public.members where email = auth.email())
    )
    or exists (
      select 1
      from public.allowed_member am
      where lower(am.email) = lower(auth.email())
        and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
  );

drop policy if exists "Captain booking requests insert by requester" on public.captain_booking_requests;
drop policy if exists "Captain booking requests insert by requester" on public.captain_booking_requests;
create policy "Captain booking requests insert by requester" on public.captain_booking_requests
  for insert to authenticated
  with check (
    member_id = (select id from public.members where email = auth.email())
    and status = 'pending'
  );

drop policy if exists "Captain booking requests update by approvers" on public.captain_booking_requests;
drop policy if exists "Captain booking requests update by approvers" on public.captain_booking_requests;
create policy "Captain booking requests update by approvers" on public.captain_booking_requests
  for update to authenticated
  using (
    exists (
      select 1 from public.admins
      where member_id = (select id from public.members where email = auth.email())
    )
    or exists (
      select 1
      from public.allowed_member am
      where lower(am.email) = lower(auth.email())
        and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
  )
  with check (
    exists (
      select 1 from public.admins
      where member_id = (select id from public.members where email = auth.email())
    )
    or exists (
      select 1
      from public.allowed_member am
      where lower(am.email) = lower(auth.email())
        and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
  );

drop policy if exists "Bookings insert for authed" on public.bookings;
drop policy if exists "Bookings insert for authed" on public.bookings;
create policy "Bookings insert for authed" on public.bookings
  for insert to authenticated
  with check (
    exists (
      select 1
      from public.allowed_member am
      where lower(am.email) = lower(auth.email())
      and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end)
        in ('admin', 'captain', 'coordinator')
    )
    and (
      member_id = (select id from public.members where email = auth.email())
      or exists (
        select 1 from public.admins
        where member_id = (select id from public.members where email = auth.email())
      )
      or exists (
        select 1
        from public.allowed_member am
        where lower(am.email) = lower(auth.email())
          and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
      )
    )
  );

commit;


-- === supabase/migrations/2026-03-09_add_captain_role_for_race_event_approvals.sql ===

begin;

alter table public.allowed_member
  drop constraint if exists allowed_member_role_check;

alter table public.allowed_member
  add constraint allowed_member_role_check
  check (role in ('admin', 'captain', 'coordinator', 'guest'));

drop policy if exists "Race event requests readable" on public.race_event_change_requests;
drop policy if exists "Race event requests readable" on public.race_event_change_requests;
create policy "Race event requests readable" on public.race_event_change_requests
  for select to authenticated
  using (
    requested_by_member_id = (select id from public.members where email = auth.email())
    or exists (
      select 1 from public.admins
      where member_id = (select id from public.members where email = auth.email())
    )
    or exists (
      select 1
      from public.allowed_member am
      where lower(am.email) = lower(auth.email())
        and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
  );

drop policy if exists "Race event requests update by admins" on public.race_event_change_requests;
drop policy if exists "Race event requests update by captains or admins" on public.race_event_change_requests;
drop policy if exists "Race event requests update by captains or admins" on public.race_event_change_requests;
create policy "Race event requests update by captains or admins" on public.race_event_change_requests
  for update to authenticated
  using (
    exists (
      select 1 from public.admins
      where member_id = (select id from public.members where email = auth.email())
    )
    or exists (
      select 1
      from public.allowed_member am
      where lower(am.email) = lower(auth.email())
        and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
  )
  with check (
    exists (
      select 1 from public.admins
      where member_id = (select id from public.members where email = auth.email())
    )
    or exists (
      select 1
      from public.allowed_member am
      where lower(am.email) = lower(auth.email())
        and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
  );

drop policy if exists "Allowed members insert for authed" on public.allowed_member;
drop policy if exists "Allowed members insert for authed" on public.allowed_member;
create policy "Allowed members insert for authed" on public.allowed_member
  for insert to authenticated
  with check (
    (
      exists (
        select 1 from public.admins
        where member_id = (select id from public.members where email = auth.email())
      )
      and coalesce(role, case when is_admin then 'admin' else 'coordinator' end)
        in ('admin', 'captain', 'coordinator', 'guest')
    )
    or (
      exists (
        select 1
        from public.allowed_member am
        where lower(am.email) = lower(auth.email())
          and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
      )
      and coalesce(role, case when is_admin then 'admin' else 'coordinator' end) in ('coordinator', 'guest')
      and coalesce(is_admin, false) = false
    )
    or (
      exists (
        select 1
        from public.allowed_member am
        where lower(am.email) = lower(auth.email())
          and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'coordinator'
      )
      and coalesce(role, case when is_admin then 'admin' else 'coordinator' end) = 'guest'
      and coalesce(is_admin, false) = false
    )
  );

commit;


-- === supabase/migrations/2026-03-09_add_race_event_change_requests.sql ===

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
drop policy if exists "Race event requests insert by requester" on public.race_event_change_requests;
create policy "Race event requests insert by requester" on public.race_event_change_requests
  for insert to authenticated
  with check (
    requested_by_member_id = (select id from public.members where email = auth.email())
    and status = 'pending'
  );

drop policy if exists "Race event requests update by admins" on public.race_event_change_requests;
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


-- === supabase/migrations/2026-03-09_allow_captains_manage_boats_templates.sql ===

begin;

drop policy if exists "Boats insert for authed" on public.boats;
drop policy if exists "Boats update for authed" on public.boats;
drop policy if exists "Boats delete for authed" on public.boats;
drop policy if exists "Boats insert for captains or admins" on public.boats;
create policy "Boats insert for captains or admins" on public.boats
  for insert to authenticated
  with check (
    exists (
      select 1 from public.admins
      where member_id = (select id from public.members where email = auth.email())
    )
    or exists (
      select 1
      from public.allowed_member am
      where lower(am.email) = lower(auth.email())
        and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
  );
drop policy if exists "Boats update for captains or admins" on public.boats;
create policy "Boats update for captains or admins" on public.boats
  for update to authenticated
  using (
    exists (
      select 1 from public.admins
      where member_id = (select id from public.members where email = auth.email())
    )
    or exists (
      select 1
      from public.allowed_member am
      where lower(am.email) = lower(auth.email())
        and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
  )
  with check (
    exists (
      select 1 from public.admins
      where member_id = (select id from public.members where email = auth.email())
    )
    or exists (
      select 1
      from public.allowed_member am
      where lower(am.email) = lower(auth.email())
        and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
  );
drop policy if exists "Boats delete for captains or admins" on public.boats;
create policy "Boats delete for captains or admins" on public.boats
  for delete to authenticated
  using (
    exists (
      select 1 from public.admins
      where member_id = (select id from public.members where email = auth.email())
    )
    or exists (
      select 1
      from public.allowed_member am
      where lower(am.email) = lower(auth.email())
        and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
  );

drop policy if exists "Templates insert for authed" on public.booking_templates;
drop policy if exists "Templates update for authed" on public.booking_templates;
drop policy if exists "Templates delete for authed" on public.booking_templates;
drop policy if exists "Templates insert for captains or admins" on public.booking_templates;
create policy "Templates insert for captains or admins" on public.booking_templates
  for insert to authenticated
  with check (
    exists (
      select 1 from public.admins
      where member_id = (select id from public.members where email = auth.email())
    )
    or exists (
      select 1
      from public.allowed_member am
      where lower(am.email) = lower(auth.email())
        and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
  );
drop policy if exists "Templates update for captains or admins" on public.booking_templates;
create policy "Templates update for captains or admins" on public.booking_templates
  for update to authenticated
  using (
    exists (
      select 1 from public.admins
      where member_id = (select id from public.members where email = auth.email())
    )
    or exists (
      select 1
      from public.allowed_member am
      where lower(am.email) = lower(auth.email())
        and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
  )
  with check (
    exists (
      select 1 from public.admins
      where member_id = (select id from public.members where email = auth.email())
    )
    or exists (
      select 1
      from public.allowed_member am
      where lower(am.email) = lower(auth.email())
        and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
  );
drop policy if exists "Templates delete for captains or admins" on public.booking_templates;
create policy "Templates delete for captains or admins" on public.booking_templates
  for delete to authenticated
  using (
    exists (
      select 1 from public.admins
      where member_id = (select id from public.members where email = auth.email())
    )
    or exists (
      select 1
      from public.allowed_member am
      where lower(am.email) = lower(auth.email())
        and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
  );

drop policy if exists "Template exceptions insert for authed" on public.template_exceptions;
drop policy if exists "Template exceptions delete for authed" on public.template_exceptions;
drop policy if exists "Template exceptions insert for captains or admins" on public.template_exceptions;
create policy "Template exceptions insert for captains or admins" on public.template_exceptions
  for insert to authenticated
  with check (
    exists (
      select 1 from public.admins
      where member_id = (select id from public.members where email = auth.email())
    )
    or exists (
      select 1
      from public.allowed_member am
      where lower(am.email) = lower(auth.email())
        and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
  );
drop policy if exists "Template exceptions delete for captains or admins" on public.template_exceptions;
create policy "Template exceptions delete for captains or admins" on public.template_exceptions
  for delete to authenticated
  using (
    exists (
      select 1 from public.admins
      where member_id = (select id from public.members where email = auth.email())
    )
    or exists (
      select 1
      from public.allowed_member am
      where lower(am.email) = lower(auth.email())
        and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
  );

drop policy if exists "Boat permissions insert for authed" on public.boat_permissions;
drop policy if exists "Boat permissions delete for authed" on public.boat_permissions;
drop policy if exists "Boat permissions insert for captains or admins" on public.boat_permissions;
create policy "Boat permissions insert for captains or admins" on public.boat_permissions
  for insert to authenticated
  with check (
    exists (
      select 1 from public.admins
      where member_id = (select id from public.members where email = auth.email())
    )
    or exists (
      select 1
      from public.allowed_member am
      where lower(am.email) = lower(auth.email())
        and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
  );
drop policy if exists "Boat permissions delete for captains or admins" on public.boat_permissions;
create policy "Boat permissions delete for captains or admins" on public.boat_permissions
  for delete to authenticated
  using (
    exists (
      select 1 from public.admins
      where member_id = (select id from public.members where email = auth.email())
    )
    or exists (
      select 1
      from public.allowed_member am
      where lower(am.email) = lower(auth.email())
        and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
  );

commit;


-- === supabase/migrations/2026-03-11_add_booking_group_id.sql ===

begin;

alter table public.bookings
  add column if not exists booking_group_id uuid;

update public.bookings
set booking_group_id = gen_random_uuid()
where booking_group_id is null;

alter table public.bookings
  alter column booking_group_id set default gen_random_uuid();

alter table public.bookings
  alter column booking_group_id set not null;

create index if not exists bookings_group_idx on public.bookings (booking_group_id);

commit;


-- === supabase/migrations/2026-03-11_add_template_group_id.sql ===

begin;

alter table public.booking_templates
  add column if not exists template_group_id uuid;

update public.booking_templates
set template_group_id = gen_random_uuid()
where template_group_id is null;

alter table public.booking_templates
  alter column template_group_id set default gen_random_uuid();

alter table public.booking_templates
  alter column template_group_id set not null;

create index if not exists booking_templates_group_idx on public.booking_templates (template_group_id);

commit;


-- === supabase/migrations/2026-03-11_allow_coordinators_skip_own_template_occurrences.sql ===

begin;

drop policy if exists "Template exceptions insert for captains or admins" on public.template_exceptions;

drop policy if exists "Template exceptions insert for owners captains or admins" on public.template_exceptions;
create policy "Template exceptions insert for owners captains or admins" on public.template_exceptions
  for insert to authenticated
  with check (
    exists (
      select 1 from public.admins
      where member_id = (select id from public.members where email = auth.email())
    )
    or exists (
      select 1
      from public.allowed_member am
      where lower(am.email) = lower(auth.email())
        and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
    or exists (
      select 1
      from public.booking_templates bt
      join public.members m on m.id = bt.member_id
      where bt.id = template_id
        and lower(m.email) = lower(auth.email())
    )
  );

commit;


-- === supabase/migrations/2026-03-14_add_template_season.sql ===

alter table public.booking_templates
  add column if not exists season text;

update public.booking_templates
set season = 'winter time'
where season is null;

alter table public.booking_templates
  alter column season set default 'winter time';

alter table public.booking_templates
  alter column season set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'booking_templates_season_check'
      and conrelid = 'public.booking_templates'::regclass
  ) then
    alter table public.booking_templates
      add constraint booking_templates_season_check
      check (season in ('summer time', 'winter time'));
  end if;
end $$;

create index if not exists booking_templates_season_weekday_idx
  on public.booking_templates (season, weekday);


-- === supabase/migrations/2026-03-14_add_template_season_settings.sql ===

create table if not exists public.template_season_settings (
  id int primary key,
  next_switch_date date,
  updated_at timestamptz not null default now()
);

insert into public.template_season_settings (id, next_switch_date)
values (1, null)
on conflict (id) do nothing;

alter table public.template_season_settings enable row level security;

drop policy if exists "Template season settings readable for authed" on public.template_season_settings;
drop policy if exists "Template season settings readable for authed" on public.template_season_settings;
create policy "Template season settings readable for authed" on public.template_season_settings
  for select to authenticated
  using (true);

drop policy if exists "Template season settings upsert for captains or admins" on public.template_season_settings;
drop policy if exists "Template season settings upsert for captains or admins" on public.template_season_settings;
create policy "Template season settings upsert for captains or admins" on public.template_season_settings
  for all to authenticated
  using (
    exists (
      select 1 from public.admins
      where member_id = (select id from public.members where email = auth.email())
    )
    or exists (
      select 1
      from public.allowed_member am
      where lower(am.email) = lower(auth.email())
        and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
  )
  with check (
    exists (
      select 1 from public.admins
      where member_id = (select id from public.members where email = auth.email())
    )
    or exists (
      select 1
      from public.allowed_member am
      where lower(am.email) = lower(auth.email())
        and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
  );


-- === supabase/migrations/2026-03-16_add_race_event_loadin_plan.sql ===

alter table public.race_events
  add column if not exists loadin_plan jsonb;

update public.race_events
set loadin_plan = '{}'::jsonb
where loadin_plan is null;

alter table public.race_events
  alter column loadin_plan set default '{}'::jsonb;

alter table public.race_events
  alter column loadin_plan set not null;


-- === supabase/migrations/2026-04-05_add_force_password_reset_to_allowed_member.sql ===

begin;

alter table public.allowed_member
  add column if not exists force_password_reset boolean not null default false;

commit;


-- === supabase/migrations/2026-04-05_allow_captains_manage_race_events_and_add_captains.sql ===

begin;

drop policy if exists "Race events insert for admins" on public.race_events;
drop policy if exists "Race events insert for captains or admins" on public.race_events;
drop policy if exists "Race events insert for captains or admins" on public.race_events;
create policy "Race events insert for captains or admins" on public.race_events
  for insert to authenticated
  with check (
    exists (
      select 1 from public.admins
      where member_id = (select id from public.members where email = auth.email())
    )
    or exists (
      select 1
      from public.allowed_member am
      where lower(am.email) = lower(auth.email())
        and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
  );

drop policy if exists "Race events update for admins" on public.race_events;
drop policy if exists "Race events update for captains or admins" on public.race_events;
drop policy if exists "Race events update for captains or admins" on public.race_events;
create policy "Race events update for captains or admins" on public.race_events
  for update to authenticated
  using (
    exists (
      select 1 from public.admins
      where member_id = (select id from public.members where email = auth.email())
    )
    or exists (
      select 1
      from public.allowed_member am
      where lower(am.email) = lower(auth.email())
        and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
  )
  with check (
    exists (
      select 1 from public.admins
      where member_id = (select id from public.members where email = auth.email())
    )
    or exists (
      select 1
      from public.allowed_member am
      where lower(am.email) = lower(auth.email())
        and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
  );

drop policy if exists "Race events delete for admins" on public.race_events;
drop policy if exists "Race events delete for captains or admins" on public.race_events;
drop policy if exists "Race events delete for captains or admins" on public.race_events;
create policy "Race events delete for captains or admins" on public.race_events
  for delete to authenticated
  using (
    exists (
      select 1 from public.admins
      where member_id = (select id from public.members where email = auth.email())
    )
    or exists (
      select 1
      from public.allowed_member am
      where lower(am.email) = lower(auth.email())
        and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
  );

drop policy if exists "Race event boats insert for admins" on public.race_event_boats;
drop policy if exists "Race event boats insert for captains or admins" on public.race_event_boats;
drop policy if exists "Race event boats insert for captains or admins" on public.race_event_boats;
create policy "Race event boats insert for captains or admins" on public.race_event_boats
  for insert to authenticated
  with check (
    exists (
      select 1 from public.admins
      where member_id = (select id from public.members where email = auth.email())
    )
    or exists (
      select 1
      from public.allowed_member am
      where lower(am.email) = lower(auth.email())
        and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
  );

drop policy if exists "Race event boats update for admins" on public.race_event_boats;
drop policy if exists "Race event boats update for captains or admins" on public.race_event_boats;
drop policy if exists "Race event boats update for captains or admins" on public.race_event_boats;
create policy "Race event boats update for captains or admins" on public.race_event_boats
  for update to authenticated
  using (
    exists (
      select 1 from public.admins
      where member_id = (select id from public.members where email = auth.email())
    )
    or exists (
      select 1
      from public.allowed_member am
      where lower(am.email) = lower(auth.email())
        and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
  )
  with check (
    exists (
      select 1 from public.admins
      where member_id = (select id from public.members where email = auth.email())
    )
    or exists (
      select 1
      from public.allowed_member am
      where lower(am.email) = lower(auth.email())
        and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
  );

drop policy if exists "Race event boats delete for admins" on public.race_event_boats;
drop policy if exists "Race event boats delete for captains or admins" on public.race_event_boats;
drop policy if exists "Race event boats delete for captains or admins" on public.race_event_boats;
create policy "Race event boats delete for captains or admins" on public.race_event_boats
  for delete to authenticated
  using (
    exists (
      select 1 from public.admins
      where member_id = (select id from public.members where email = auth.email())
    )
    or exists (
      select 1
      from public.allowed_member am
      where lower(am.email) = lower(auth.email())
        and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
    )
  );

drop policy if exists "Allowed members insert for authed" on public.allowed_member;
drop policy if exists "Allowed members insert for authed" on public.allowed_member;
create policy "Allowed members insert for authed" on public.allowed_member
  for insert to authenticated
  with check (
    (
      exists (
        select 1 from public.admins
        where member_id = (select id from public.members where email = auth.email())
      )
      and coalesce(role, case when is_admin then 'admin' else 'coordinator' end)
        in ('admin', 'captain', 'coordinator', 'guest')
    )
    or (
      exists (
        select 1
        from public.allowed_member am
        where lower(am.email) = lower(auth.email())
          and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'captain'
      )
      and coalesce(role, case when is_admin then 'admin' else 'coordinator' end)
        in ('captain', 'coordinator', 'guest')
      and coalesce(is_admin, false) = false
    )
    or (
      exists (
        select 1
        from public.allowed_member am
        where lower(am.email) = lower(auth.email())
          and coalesce(am.role, case when am.is_admin then 'admin' else 'coordinator' end) = 'coordinator'
      )
      and coalesce(role, case when is_admin then 'admin' else 'coordinator' end) = 'guest'
      and coalesce(is_admin, false) = false
    )
  );

commit;
