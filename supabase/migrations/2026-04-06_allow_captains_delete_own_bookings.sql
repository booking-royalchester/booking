begin;

drop policy if exists "Bookings delete for authed" on public.bookings;
create policy "Bookings delete for authed" on public.bookings
  for delete to authenticated
  using (
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
