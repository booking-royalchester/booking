begin;

drop policy if exists "Allowed members delete for authed" on public.allowed_member;
create policy "Allowed members delete for authed" on public.allowed_member
  for delete to authenticated
  using (
    exists (
      select 1 from public.admins
      where member_id = (select id from public.members where email = auth.email())
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
  );

commit;
