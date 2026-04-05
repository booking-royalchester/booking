begin;

alter table public.allowed_member
  add column if not exists force_password_reset boolean not null default false;

commit;
