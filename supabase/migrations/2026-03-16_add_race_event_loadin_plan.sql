alter table public.race_events
  add column if not exists loadin_plan jsonb;

update public.race_events
set loadin_plan = '{}'::jsonb
where loadin_plan is null;

alter table public.race_events
  alter column loadin_plan set default '{}'::jsonb;

alter table public.race_events
  alter column loadin_plan set not null;
