-- Phase 5: what the user did when a dose was due. Written by the phone (offline-first, synced
-- later), read by the caregiver features in Phase 6.

create table public.dose_logs (
    id            uuid primary key default gen_random_uuid(),
    user_id       uuid not null default auth.uid() references auth.users (id) on delete cascade,
    medicine_id   uuid not null references public.medicines (id) on delete cascade,
    scheduled_at  timestamptz not null,
    status        text not null check (status in ('taken', 'skipped')),
    acted_at      timestamptz not null,
    created_at    timestamptz not null default now(),
    unique (medicine_id, scheduled_at)
);

create index dose_logs_user_time_idx on public.dose_logs (user_id, scheduled_at desc);

create function public.check_dose_log_owner() returns trigger
    language plpgsql set search_path = '' as $$
begin
    if not exists (select 1 from public.medicines m
                   where m.id = new.medicine_id and m.user_id = new.user_id) then
        raise exception 'medicine does not belong to user' using errcode = '42501';
    end if;
    return new;
end;
$$;

create trigger dose_logs_owner_check
    before insert or update of medicine_id, user_id on public.dose_logs
    for each row execute function public.check_dose_log_owner();

alter table public.dose_logs enable row level security;

create policy "own dose logs" on public.dose_logs for all to authenticated
    using (user_id = auth.uid()) with check (user_id = auth.uid());

grant select, insert, update, delete on public.dose_logs to authenticated;
