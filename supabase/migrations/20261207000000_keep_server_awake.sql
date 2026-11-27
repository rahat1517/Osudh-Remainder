-- Keeps the backend awake: Render's free plan puts it to sleep after 15 idle minutes, and the
-- next scan then waits about a minute for it to start. A ping every 10 minutes (pg_cron + pg_net,
-- both free on Supabase) keeps it running; one always-on free service uses ~744 of the 750 free
-- instance hours a month. To stop: select cron.unschedule('keep-backend-awake');
-- Guarded: plain-Postgres test databases have neither extension.
do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron')
     and exists (select 1 from pg_available_extensions where name = 'pg_net') then
    create extension if not exists pg_cron;
    create extension if not exists pg_net;
    perform cron.schedule(
      'keep-backend-awake',
      '*/10 * * * *',
      $job$select net.http_get('https://oshudh-api.onrender.com/health', timeout_milliseconds := 60000)$job$
    );
  end if;
end
$$;
