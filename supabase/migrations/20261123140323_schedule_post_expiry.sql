-- Cleanup of expired posts and of their photos.
--
-- An expired post is hidden at once by the policies of posts: this job only
-- deletes it for good, with its photo. Files can only be removed through the
-- Storage API, not in SQL, so pg_cron calls the Edge Function
-- purge-expired-posts every 5 minutes, which calls the two functions below.
--
-- The job needs two Vault secrets, created by hand on each project and never
-- stored in Git:
--   select vault.create_secret('https://<ref>.supabase.co', 'project_url');
--   select vault.create_secret('<secret key, sb_secret_...>', 'secret_key');
-- Without them, the job does nothing.

create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;

-- Cleanup functions ----------------------------------------------------------

-- Deletes up to batch_size expired posts, with their audience lists and pins,
-- and returns the paths of their photos, to be removed from post-photos.
create function public.purge_expired_posts(batch_size integer default 500)
returns setof text
language sql
volatile
set search_path = ''
as $$
  delete from public.posts
  where id in (
    select id from public.posts
    where expires_at <= now()
    order by expires_at
    limit batch_size
    for update skip locked
  )
  returning image_path;
$$;

-- Up to batch_size post-photos files that no post uses and that were uploaded
-- more than an hour ago: an upload whose post was never created, or the photo
-- of a post deleted while its file could not be removed. The hour leaves time
-- to create the post after uploading its photo.
create function public.list_orphan_post_photos(batch_size integer default 500)
returns setof text
language sql
stable
set search_path = ''
as $$
  select object.name
  from storage.objects as object
  where object.bucket_id = 'post-photos'
    and object.created_at < now() - interval '1 hour'
    and not exists (
      select 1 from public.posts as post where post.image_path = object.name
    )
  order by object.created_at
  limit batch_size;
$$;

-- Only the Edge Function calls them, with the secret key.
revoke all on function public.purge_expired_posts(integer)
  from public, anon, authenticated;
revoke all on function public.list_orphan_post_photos(integer)
  from public, anon, authenticated;
grant execute on function public.purge_expired_posts(integer) to service_role;
grant execute on function public.list_orphan_post_photos(integer)
  to service_role;

-- Schedule -------------------------------------------------------------------

-- Asks the Edge Function to clean up. The request leaves when the transaction
-- ends; its answer is kept a few hours in net._http_response.
create function private.request_post_purge()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  project_url text;
  secret_key text;
begin
  select decrypted_secret into project_url
  from vault.decrypted_secrets where name = 'project_url';
  select decrypted_secret into secret_key
  from vault.decrypted_secrets where name = 'secret_key';

  if project_url is null or secret_key is null then
    raise notice 'post purge skipped: project_url or secret_key missing from Vault';
    return;
  end if;

  perform net.http_post(
    url := project_url || '/functions/v1/purge-expired-posts',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'apikey', secret_key
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 30000
  );
end;
$$;

revoke all on function private.request_post_purge() from public;

select cron.schedule(
  'purge-expired-posts',
  '*/5 * * * *',
  'select private.request_post_purge()'
);
