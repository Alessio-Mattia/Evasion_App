-- Private bucket for profile photos.
--
-- Each user owns the folder named after their id: avatars/<user id>/<file>.
-- Photos are shown through signed URLs, so the server decides who sees them.
-- For now users only access their own folder; reading other users' photos
-- comes with the public profiles and the block filter.

-- Keep the limits in sync with BusinessRules.avatarMaxBytes and
-- BusinessRules.avatarMimeTypes (business_rules.dart).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars',
  'avatars',
  false,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
);

-- True when the file extension matches the declared format: a .jpg file must
-- be declared as image/jpeg. Storage checks the declared format against the
-- bucket, but neither the extension nor the actual content of the file.
create function public.avatar_format_matches(name text, metadata jsonb)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select coalesce(
    case lower(storage.extension(name))
      when 'jpg' then metadata ->> 'mimetype' = 'image/jpeg'
      when 'jpeg' then metadata ->> 'mimetype' = 'image/jpeg'
      when 'png' then metadata ->> 'mimetype' = 'image/png'
      when 'webp' then metadata ->> 'mimetype' = 'image/webp'
      else false
    end,
    false
  );
$$;

create policy "Users can read their own avatars"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );

create policy "Users can upload their own avatars"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
    and public.avatar_format_matches(name, metadata)
  );

create policy "Users can replace their own avatars"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
    and public.avatar_format_matches(name, metadata)
  );

create policy "Users can delete their own avatars"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );

-- The photo of a profile must be an image of its own folder, so that nobody
-- can show someone else's photo as their own. The path excludes the bucket
-- name: <user id>/<file>.jpg, .jpeg, .png or .webp.
alter table public.profiles
  add constraint profiles_avatar_path_own_folder
    check (avatar_path ~* ('^' || id::text || '/[^/]+\.(jpe?g|png|webp)$'));
