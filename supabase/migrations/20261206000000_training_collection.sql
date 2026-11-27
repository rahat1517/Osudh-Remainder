-- Training-example collection on the server (see backend/app/training).
--
-- 1. Private bucket for redacted prescription images. No public access and no storage policies:
--    only the service role (the backend) can read or write it. Reviewers use the dashboard.
-- 2. oshudh_backend: the backend's own database login, limited to what collection needs (check a
--    user's consent, add an example). Created without a password; one is set outside migrations,
--    never in this repository.

do $$
begin
  if exists (select 1 from information_schema.schemata where schema_name = 'storage') then
    insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
    values ('training-examples', 'training-examples', false, 5242880, array['image/jpeg'])
    on conflict (id) do update
      set public = false,
          file_size_limit = excluded.file_size_limit,
          allowed_mime_types = excluded.allowed_mime_types;
  end if;
end
$$;

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'oshudh_backend') then
    create role oshudh_backend nologin;
  end if;
end
$$;

grant usage on schema public to oshudh_backend;
grant select (user_id, version, revoked_at) on public.training_consents to oshudh_backend;
-- select on id only: needed for "insert ... returning id"
grant insert (user_id, consent_version, image_path, label, group_key, redacted_lines),
      select (id)
  on public.training_examples to oshudh_backend;

create policy "backend reads consents" on public.training_consents
  for select to oshudh_backend using (true);
create policy "backend adds examples" on public.training_examples
  for insert to oshudh_backend with check (review_status = 'pending');
create policy "backend sees example ids" on public.training_examples
  for select to oshudh_backend using (true);
