-- Public bucket for pilot APKs and latest.json (in-app update notice). Anyone can download; only the
-- service role (the Pilot APK workflow) can upload. 50 MB is the free plan's file limit, hence one
-- APK per processor type instead of a universal one.
-- Guarded: plain-Postgres test databases have no storage schema.
do $$
begin
  if exists (select 1 from information_schema.schemata where schema_name = 'storage') then
    insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
    values ('app-releases', 'app-releases', true, 52428800,
            array['application/vnd.android.package-archive', 'application/json'])
    on conflict (id) do update
      set public = true,
          file_size_limit = excluded.file_size_limit,
          allowed_mime_types = excluded.allowed_mime_types;
  end if;
end
$$;
