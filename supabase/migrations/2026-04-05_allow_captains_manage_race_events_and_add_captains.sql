begin;

drop policy if exists "Race events insert for admins" on public.race_events;
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
