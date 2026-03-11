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
