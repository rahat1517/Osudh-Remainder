-- Phase 10: SMS and voice-call reminders.
--
-- Opt-in only (off by default). Two uses:
--   * escalation: a dose still not taken 30 min after it was due → SMS; after 45 min → voice call
--   * feature-phone mode: the patient has no smartphone; reminders go out by SMS/call at dose time
--     while a caregiver manages the medicines in the app

alter table public.profiles
    add column sms_reminders boolean not null default false,
    add column call_reminders boolean not null default false,
    add column feature_phone_mode boolean not null default false;

-- Every SMS/call attempt, for de-duplication (the job runs every few minutes) and cost tracking
create table public.escalation_events (
    id            uuid primary key default gen_random_uuid(),
    patient_id    uuid not null references auth.users (id) on delete cascade,
    medicine_id   uuid not null references public.medicines (id) on delete cascade,
    scheduled_at  timestamptz not null,
    channel       text not null check (channel in ('sms', 'call')),
    reason        text not null check (reason in ('reminder', 'missed')),
    status        text not null check (status in ('sent', 'failed', 'skipped_limit')),
    provider_id   text,
    cost_bdt      numeric(10, 4) not null default 0,
    created_at    timestamptz not null default now(),
    unique (medicine_id, scheduled_at, channel, reason)
);

create index escalation_events_patient_day_idx on public.escalation_events (patient_id, created_at);

alter table public.escalation_events enable row level security;

create policy "patients and caregivers see escalations" on public.escalation_events
    for select to authenticated
    using (patient_id = auth.uid() or public.is_caregiver_of(patient_id));
-- Written only by the server job (service role)

grant select on public.escalation_events to authenticated;

-- Patients change their own reminder channels; edit caregivers may change them for the patient
-- (e.g. switch on feature-phone mode for a parent without a smartphone).
create function public.set_reminder_channels(
    patient uuid, sms boolean, call boolean, feature_phone boolean
) returns void
    language plpgsql security definer set search_path = '' as $$
begin
    if patient <> auth.uid() and not public.is_caregiver_of(patient, true) then
        raise exception 'not allowed' using errcode = '42501';
    end if;
    update public.profiles
       set sms_reminders = sms, call_reminders = call, feature_phone_mode = feature_phone,
           updated_at = now()
     where id = patient;
end;
$$;

revoke execute on function public.set_reminder_channels(uuid, boolean, boolean, boolean) from public, anon;
grant execute on function public.set_reminder_channels(uuid, boolean, boolean, boolean) to authenticated;
