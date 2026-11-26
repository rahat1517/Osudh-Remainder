-- Phase 9: data for refill reminders, duplicate-therapy warnings and Ramadan mode.

alter table public.medicines
    add column generic text check (length(generic) <= 200),
    add column pills_on_hand numeric check (pills_on_hand >= 0 and pills_on_hand <= 10000),
    add column pills_counted_at timestamptz;

alter table public.profiles
    add column district text not null default 'dhaka',
    add column ramadan_mode boolean not null default false;

-- Views capture the column list at creation time; recreate so the new columns are included.
create or replace view public.active_medicines with (security_invoker = true) as
    select m.*
    from public.medicines m
    join public.prescriptions p on p.id = m.prescription_id
    where p.status = 'confirmed' and m.stopped_at is null;
