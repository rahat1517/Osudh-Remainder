-- Hardening (Supabase security advisor): Postgres grants EXECUTE to PUBLIC by default, so signed-out
-- clients (anon) could call these security-definer functions through /rest/v1/rpc. Each one already
-- checks auth.uid(), but none of them is meant for signed-out use.

revoke execute on function public.accept_caregiver_invite(text) from public, anon;
revoke execute on function public.revoke_caregiver_link(uuid) from public, anon;
revoke execute on function public.confirm_prescription(uuid) from public, anon;
revoke execute on function public.is_caregiver_of(uuid, boolean) from public, anon;
revoke execute on function public.create_caregiver_invite(text) from public, anon;

-- Trigger function only; no client should call it directly.
revoke execute on function public.handle_new_user() from public, anon, authenticated;

grant execute on function public.accept_caregiver_invite(text) to authenticated;
grant execute on function public.revoke_caregiver_link(uuid) to authenticated;
grant execute on function public.confirm_prescription(uuid) to authenticated;
grant execute on function public.is_caregiver_of(uuid, boolean) to authenticated;
grant execute on function public.create_caregiver_invite(text) to authenticated;
