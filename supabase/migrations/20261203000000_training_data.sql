-- Phase 11: consented, de-identified training data for a self-hosted prescription reader.
--
-- Nothing is collected without an explicit, versioned, revocable opt-in. Examples pass automatic
-- redaction AND human review before they can be exported for training. Revoking consent deletes the
-- user's examples that have not been exported yet.

create table public.training_consents (
    user_id      uuid primary key references auth.users (id) on delete cascade,
    version      int not null check (version >= 1),
    granted_at   timestamptz not null default now(),
    revoked_at   timestamptz
);

create table public.training_examples (
    id              uuid primary key default gen_random_uuid(),
    user_id         uuid not null references auth.users (id) on delete cascade,
    consent_version int not null,
    image_path      text not null,              -- private storage object, redacted image
    label           jsonb not null,             -- confirmed medicines (no personal data)
    group_key       text not null,              -- hashed, for leakage-free dataset splits
    redacted_lines  int not null default 0,
    review_status   text not null default 'pending'
                    check (review_status in ('pending', 'approved', 'rejected')),
    reviewed_by     text,
    reviewed_at     timestamptz,
    exported_at     timestamptz,
    created_at      timestamptz not null default now()
);

create index training_examples_review_idx on public.training_examples (review_status, created_at);

alter table public.training_consents enable row level security;
alter table public.training_examples enable row level security;

-- Users see and manage their own consent; examples are written and reviewed by the server only
create policy "own consent" on public.training_consents for select to authenticated
    using (user_id = auth.uid());
create policy "own examples visible" on public.training_examples for select to authenticated
    using (user_id = auth.uid());

grant select on public.training_consents, public.training_examples to authenticated;

create function public.set_training_consent(granted boolean, consent_version int default 1) returns void
    language plpgsql security definer set search_path = '' as $$
begin
    if auth.uid() is null then
        raise exception 'not_signed_in' using errcode = '42501';
    end if;
    if granted then
        insert into public.training_consents (user_id, version)
        values (auth.uid(), consent_version)
        on conflict (user_id) do update
            set version = excluded.version, granted_at = now(), revoked_at = null;
    else
        update public.training_consents set revoked_at = now() where user_id = auth.uid();
        -- Withdrawal removes everything not yet used for training
        delete from public.training_examples where user_id = auth.uid() and exported_at is null;
    end if;
end;
$$;

revoke execute on function public.set_training_consent(boolean, int) from public, anon;
grant execute on function public.set_training_consent(boolean, int) to authenticated;
