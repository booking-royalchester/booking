begin;

drop policy if exists "Template exceptions insert for captains or admins" on public.template_exceptions;

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
