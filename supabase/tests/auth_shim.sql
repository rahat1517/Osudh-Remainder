-- Minimal stand-in for the parts of Supabase that migrations depend on, so migrations and
-- row-level security can be tested on plain PostgreSQL (locally and in CI).
-- Never run this against a real Supabase project.
create schema if not exists auth;
create schema if not exists extensions;

do $$ begin
    if not exists (select from pg_roles where rolname = 'anon') then create role anon nologin; end if;
    if not exists (select from pg_roles where rolname = 'authenticated') then create role authenticated nologin; end if;
    if not exists (select from pg_roles where rolname = 'service_role') then create role service_role nologin bypassrls; end if;
end $$;

create table if not exists auth.users (
    id uuid primary key default gen_random_uuid(),
    phone text unique,
    created_at timestamptz not null default now()
);

-- Supabase reads the user id from the request JWT; tests set it with set_config.
create or replace function auth.uid() returns uuid language sql stable as $$
    select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;

grant usage on schema auth, public, extensions to anon, authenticated, service_role;
grant execute on function auth.uid() to anon, authenticated;
grant select on auth.users to service_role;
grant all on all tables in schema public to service_role;
alter default privileges in schema public grant all on tables to service_role;
