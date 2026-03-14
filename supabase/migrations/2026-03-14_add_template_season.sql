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
