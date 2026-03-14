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
create policy "Template season settings readable for authed" on public.template_season_settings
  for select to authenticated
  using (true);

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
