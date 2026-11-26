-- Phase 1: বাংলাদেশি ওষুধের তালিকা
-- এটা সবার জন্য উন্মুক্ত তথ্য (রোগীর তথ্য নয়), তাই সবাই পড়তে পারবে, কিন্তু অ্যাপ থেকে কেউ লিখতে পারবে না।

create extension if not exists pg_trgm with schema extensions;

create table public.drugs (
    id            bigint generated always as identity primary key,
    brand         text not null check (length(trim(brand)) > 0),
    strength      text not null default '',
    generic       text not null check (length(trim(generic)) > 0),
    form          text not null check (length(trim(form)) > 0),
    manufacturer  text,
    -- খোঁজার জন্য স্বাভাবিক করা brand নাম (ছোট হাতের, যতিচিহ্ন ছাড়া), importer তৈরি করে
    brand_normalized text not null,
    source        text not null,
    verified      boolean not null default false,
    created_at    timestamptz not null default now(),
    unique (brand, strength, form)
);

comment on table public.drugs is 'বাংলাদেশে নিবন্ধিত ওষুধ (brand → generic → strength → form)';
comment on column public.drugs.verified is 'false = উন্নয়নের নমুনা; অফিসিয়াল উৎস থেকে যাচাই করা হলে true';

-- ভুল বানানেও খোঁজার জন্য trigram index
create index drugs_brand_trgm_idx on public.drugs
    using gin (brand_normalized extensions.gin_trgm_ops);
create index drugs_generic_trgm_idx on public.drugs
    using gin (lower(generic) extensions.gin_trgm_ops);

alter table public.drugs enable row level security;

create policy "drugs are readable by everyone"
    on public.drugs for select
    to anon, authenticated
    using (true);

-- insert/update/delete-এর কোনো policy নেই, তাই শুধু service role (backend/importer) লিখতে পারবে।
