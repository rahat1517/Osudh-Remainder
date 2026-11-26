-- Phase 4: user profiles, prescriptions and medicines.
--
-- Dose times are NOT stored: they are derived deterministically from each medicine by the schedule
-- engine (docs/SCHEDULE_SPEC.md), on the phone and on the server. Storing them would create a second
-- source of truth that could drift.
--
-- Safety rule: only medicines of a CONFIRMED prescription are active (see view active_medicines).

-- ---------------------------------------------------------------------------
-- Profiles: one per auth user, created automatically on sign-up
-- ---------------------------------------------------------------------------
create table public.profiles (
    id            uuid primary key references auth.users (id) on delete cascade,
    display_name  text check (length(display_name) <= 100),
    locale        text not null default 'bn' check (locale in ('bn', 'en')),
    timezone      text not null default 'Asia/Dhaka',
    breakfast     time not null default '08:00',
    lunch         time not null default '13:30',
    evening       time not null default '17:30',
    dinner        time not null default '21:30',
    bedtime       time not null default '22:30',
    created_at    timestamptz not null default now(),
    updated_at    timestamptz not null default now(),
    constraint meal_order check (breakfast < lunch and lunch < evening and evening < dinner)
);

create function public.handle_new_user() returns trigger
    language plpgsql security definer set search_path = '' as $$
begin
    insert into public.profiles (id) values (new.id);
    return new;
end;
$$;

create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- Prescriptions: a scan or a manual entry; draft until the user confirms it
-- ---------------------------------------------------------------------------
create table public.prescriptions (
    id             uuid primary key default gen_random_uuid(),
    user_id        uuid not null default auth.uid() references auth.users (id) on delete cascade,
    source         text not null check (source in ('scan', 'manual')),
    status         text not null default 'draft' check (status in ('draft', 'confirmed', 'archived')),
    image_quality  text check (image_quality in ('good', 'readable_with_effort', 'poor')),
    confirmed_at   timestamptz,
    created_at     timestamptz not null default now(),
    constraint confirmed_has_timestamp check ((status = 'confirmed') = (confirmed_at is not null)
                                              or status = 'archived')
);

create index prescriptions_user_idx on public.prescriptions (user_id, created_at desc);

-- ---------------------------------------------------------------------------
-- Medicines: the confirmed values the schedule engine works from
-- ---------------------------------------------------------------------------
create table public.medicines (
    id               uuid primary key default gen_random_uuid(),
    user_id          uuid not null default auth.uid() references auth.users (id) on delete cascade,
    prescription_id  uuid not null references public.prescriptions (id) on delete cascade,
    drug_id          bigint references public.drugs (id) on delete set null,
    name             text not null check (length(trim(name)) between 1 and 100),
    strength         text check (length(strength) <= 50),
    form             text check (length(form) <= 50),
    dose_pattern     text check (length(dose_pattern) <= 40),
    interval_hours   int check (interval_hours in (1, 2, 3, 4, 6, 8, 12, 24)),
    interval_amount  text not null default '1',
    timing           text not null default 'not_specified' check (timing in
                         ('before_meal', 'after_meal', 'with_meal', 'empty_stomach', 'bedtime',
                          'not_specified')),
    duration_days    int check (duration_days between 1 and 365),
    weekdays         int[] check (weekdays <@ array[1, 2, 3, 4, 5, 6, 7] and cardinality(weekdays) > 0),
    as_needed        boolean not null default false,
    raw_text         text check (length(raw_text) <= 500),
    start_at         timestamptz not null default now(),
    stopped_at       timestamptz,
    created_at       timestamptz not null default now(),
    constraint has_dose check (as_needed or dose_pattern is not null or interval_hours is not null),
    constraint single_dose_kind check (dose_pattern is null or interval_hours is null)
);

create index medicines_user_idx on public.medicines (user_id) where stopped_at is null;

-- A medicine must belong to a prescription of the same user
create function public.check_medicine_owner() returns trigger
    language plpgsql set search_path = '' as $$
begin
    if not exists (select 1 from public.prescriptions p
                   where p.id = new.prescription_id and p.user_id = new.user_id) then
        raise exception 'prescription does not belong to user' using errcode = '42501';
    end if;
    return new;
end;
$$;

create trigger medicines_owner_check
    before insert or update of prescription_id, user_id on public.medicines
    for each row execute function public.check_medicine_owner();

-- Medicines that should produce reminders: confirmed, not stopped
create view public.active_medicines with (security_invoker = true) as
    select m.*
    from public.medicines m
    join public.prescriptions p on p.id = m.prescription_id
    where p.status = 'confirmed' and m.stopped_at is null;

-- Confirming is an explicit, auditable action
create function public.confirm_prescription(prescription uuid) returns void
    language sql security invoker set search_path = '' as $$
    update public.prescriptions
       set status = 'confirmed', confirmed_at = now()
     where id = prescription and user_id = auth.uid() and status = 'draft';
$$;

-- ---------------------------------------------------------------------------
-- Row-level security: every row belongs to exactly one user
-- ---------------------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.prescriptions enable row level security;
alter table public.medicines enable row level security;

create policy "own profile" on public.profiles for all to authenticated
    using (id = auth.uid()) with check (id = auth.uid());
create policy "own prescriptions" on public.prescriptions for all to authenticated
    using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own medicines" on public.medicines for all to authenticated
    using (user_id = auth.uid()) with check (user_id = auth.uid());

grant select, insert, update, delete on public.profiles, public.prescriptions, public.medicines
    to authenticated;
grant select on public.active_medicines to authenticated;
grant execute on function public.confirm_prescription(uuid) to authenticated;
