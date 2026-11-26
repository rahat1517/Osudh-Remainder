-- Phase 1: Bangladeshi drug catalogue
-- Public reference data (not patient data): readable by everyone, writable by no app client.

create extension if not exists pg_trgm with schema extensions;

create table public.drugs (
    id            bigint generated always as identity primary key,
    brand         text not null check (length(trim(brand)) > 0),
    strength      text not null default '',
    generic       text not null check (length(trim(generic)) > 0),
    form          text not null check (length(trim(form)) > 0),
    manufacturer  text,
    -- Brand normalised for matching (lower case, no punctuation); set by the importer
    brand_normalized text not null,
    source        text not null,
    verified      boolean not null default false,
    created_at    timestamptz not null default now(),
    unique (brand, strength, form)
);

comment on table public.drugs is 'Drugs registered in Bangladesh (brand → generic → strength → form)';
comment on column public.drugs.verified is 'false = development sample; true = verified against an official source';

-- Trigram indexes for misspelling-tolerant search
create index drugs_brand_trgm_idx on public.drugs
    using gin (brand_normalized extensions.gin_trgm_ops);
create index drugs_generic_trgm_idx on public.drugs
    using gin (lower(generic) extensions.gin_trgm_ops);

alter table public.drugs enable row level security;

create policy "drugs are readable by everyone"
    on public.drugs for select
    to anon, authenticated
    using (true);

-- No insert/update/delete policies: only the service role (backend, importer) can write.
-- Explicit grant, so access does not depend on the project's default-privilege settings.
grant select on public.drugs to anon, authenticated;
