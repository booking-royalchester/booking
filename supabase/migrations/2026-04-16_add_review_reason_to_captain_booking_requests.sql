begin;

alter table public.captain_booking_requests
  add column if not exists review_reason text;

commit;
