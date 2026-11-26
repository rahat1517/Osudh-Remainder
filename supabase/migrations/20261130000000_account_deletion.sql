-- Phase 7: users can delete their account and all their data from inside the app
-- (required by Google Play for apps with account creation).
-- Deleting the auth user cascades to profiles, prescriptions, medicines, dose logs, caregiver links,
-- invites, push tokens and missed-dose alerts.

create function public.delete_my_account() returns void
    language plpgsql security definer set search_path = '' as $$
begin
    if auth.uid() is null then
        raise exception 'not_signed_in' using errcode = '42501';
    end if;
    delete from auth.users where id = auth.uid();
end;
$$;

revoke execute on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
