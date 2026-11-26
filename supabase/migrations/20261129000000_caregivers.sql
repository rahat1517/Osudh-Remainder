-- Phase 6: caregivers.
--
-- Consent model: a patient creates a single-use invite code and shares it; whoever redeems it becomes
-- that patient's caregiver with the permission chosen by the patient ('view' or 'edit'). Either side
-- can revoke the link at any time. No caregiver access exists without a patient-created invite.

create table public.caregiver_links (
    id            uuid primary key default gen_random_uuid(),
    patient_id    uuid not null references auth.users (id) on delete cascade,
    caregiver_id  uuid not null references auth.users (id) on delete cascade,
    permission    text not null check (permission in ('view', 'edit')),
    status        text not null default 'active' check (status in ('active', 'revoked')),
    created_at    timestamptz not null default now(),
    revoked_at    timestamptz,
    constraint not_self check (patient_id <> caregiver_id)
);

create unique index caregiver_links_active_pair on public.caregiver_links (patient_id, caregiver_id)
    where status = 'active';

create table public.caregiver_invites (
    code        text primary key check (code ~ '^[A-HJ-NP-Z2-9]{8}$'),
    patient_id  uuid not null default auth.uid() references auth.users (id) on delete cascade,
    permission  text not null check (permission in ('view', 'edit')),
    expires_at  timestamptz not null default now() + interval '24 hours',
    used_at     timestamptz,
    used_by     uuid references auth.users (id) on delete set null,
    created_at  timestamptz not null default now()
);

-- Device tokens for push notifications (FCM)
create table public.push_tokens (
    token       text primary key,
    user_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
    platform    text not null default 'android' check (platform in ('android', 'ios')),
    updated_at  timestamptz not null default now()
);

-- Missed doses already reported, so caregivers are alerted once per dose (written by the server job)
create table public.missed_dose_alerts (
    medicine_id   uuid not null references public.medicines (id) on delete cascade,
    scheduled_at  timestamptz not null,
    patient_id    uuid not null references auth.users (id) on delete cascade,
    notified_at   timestamptz not null default now(),
    primary key (medicine_id, scheduled_at)
);

-- ---------------------------------------------------------------------------
-- Access helper
-- ---------------------------------------------------------------------------
create function public.is_caregiver_of(patient uuid, need_edit boolean default false) returns boolean
    language sql stable security definer set search_path = '' as $$
    select exists (
        select 1 from public.caregiver_links l
        where l.patient_id = patient and l.caregiver_id = auth.uid() and l.status = 'active'
          and (not need_edit or l.permission = 'edit')
    );
$$;

-- ---------------------------------------------------------------------------
-- Invites
-- ---------------------------------------------------------------------------
create function public.create_caregiver_invite(permission text default 'view') returns text
    language plpgsql security invoker set search_path = '' as $$
declare
    alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; -- no 0/O, 1/I: easy to read aloud
    new_code text;
begin
    loop
        select string_agg(substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1), '')
          into new_code from generate_series(1, 8);
        begin
            insert into public.caregiver_invites (code, permission) values (new_code, permission);
            return new_code;
        exception when unique_violation then
            -- extremely unlikely collision; try another code
        end;
    end loop;
end;
$$;

-- Redeems an invite for the calling user. Errors: invite_invalid, invite_own.
create function public.accept_caregiver_invite(invite_code text) returns uuid
    language plpgsql security definer set search_path = '' as $$
declare
    inv public.caregiver_invites;
    link_id uuid;
begin
    select * into inv from public.caregiver_invites
     where code = upper(trim(invite_code)) and used_at is null and expires_at > now()
     for update;
    if not found then
        raise exception 'invite_invalid' using errcode = 'P0001';
    end if;
    if inv.patient_id = auth.uid() then
        raise exception 'invite_own' using errcode = 'P0001';
    end if;
    update public.caregiver_invites set used_at = now(), used_by = auth.uid() where code = inv.code;
    update public.caregiver_links set status = 'revoked', revoked_at = now()
     where patient_id = inv.patient_id and caregiver_id = auth.uid() and status = 'active';
    insert into public.caregiver_links (patient_id, caregiver_id, permission)
    values (inv.patient_id, auth.uid(), inv.permission)
    returning id into link_id;
    return link_id;
end;
$$;

-- Security definer: nobody may update links directly; this function checks the caller is a party.
create function public.revoke_caregiver_link(link uuid) returns void
    language sql security definer set search_path = '' as $$
    update public.caregiver_links set status = 'revoked', revoked_at = now()
     where id = link and status = 'active'
       and (patient_id = auth.uid() or caregiver_id = auth.uid());
$$;

-- Patients, and caregivers with edit permission, may confirm a draft. Security definer so that the
-- only change a caregiver can make to a prescription row is this status transition.
create or replace function public.confirm_prescription(prescription uuid) returns void
    language sql security definer set search_path = '' as $$
    update public.prescriptions
       set status = 'confirmed', confirmed_at = now()
     where id = prescription and status = 'draft'
       and (user_id = auth.uid() or public.is_caregiver_of(user_id, true));
$$;

-- ---------------------------------------------------------------------------
-- Row-level security
-- ---------------------------------------------------------------------------
alter table public.caregiver_links enable row level security;
alter table public.caregiver_invites enable row level security;
alter table public.push_tokens enable row level security;
alter table public.missed_dose_alerts enable row level security;

create policy "parties see their links" on public.caregiver_links for select to authenticated
    using (patient_id = auth.uid() or caregiver_id = auth.uid());
-- Links are created only through accept_caregiver_invite and changed through revoke_caregiver_link

create policy "patients manage their invites" on public.caregiver_invites for all to authenticated
    using (patient_id = auth.uid()) with check (patient_id = auth.uid());

create policy "own push tokens" on public.push_tokens for all to authenticated
    using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "patients see their alerts" on public.missed_dose_alerts for select to authenticated
    using (patient_id = auth.uid() or public.is_caregiver_of(patient_id));

-- Caregiver read access to the patient's data
create policy "caregivers read profiles" on public.profiles for select to authenticated
    using (public.is_caregiver_of(id));
create policy "caregivers read prescriptions" on public.prescriptions for select to authenticated
    using (public.is_caregiver_of(user_id));
create policy "caregivers read medicines" on public.medicines for select to authenticated
    using (public.is_caregiver_of(user_id));
create policy "caregivers read dose logs" on public.dose_logs for select to authenticated
    using (public.is_caregiver_of(user_id));

-- Edit caregivers may add prescriptions and medicines for the patient, and stop medicines
create policy "edit caregivers add prescriptions" on public.prescriptions for insert to authenticated
    with check (public.is_caregiver_of(user_id, true));
create policy "edit caregivers add medicines" on public.medicines for insert to authenticated
    with check (public.is_caregiver_of(user_id, true));
create policy "edit caregivers update medicines" on public.medicines for update to authenticated
    using (public.is_caregiver_of(user_id, true)) with check (public.is_caregiver_of(user_id, true));

grant select on public.caregiver_links to authenticated;
grant select, insert, delete on public.caregiver_invites to authenticated;
grant select, insert, update, delete on public.push_tokens to authenticated;
grant select on public.missed_dose_alerts to authenticated;
grant execute on function public.is_caregiver_of(uuid, boolean) to authenticated;
grant execute on function public.create_caregiver_invite(text) to authenticated;
grant execute on function public.accept_caregiver_invite(text) to authenticated;
grant execute on function public.revoke_caregiver_link(uuid) to authenticated;
