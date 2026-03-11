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
