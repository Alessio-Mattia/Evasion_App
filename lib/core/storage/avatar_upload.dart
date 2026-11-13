import 'dart:typed_data';

import 'package:evasion/core/photos/photo_file.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Makes the photo [bytes] the profile photo of [userId], the signed-in user.
///
/// The current photo cannot be overwritten nor deleted while the profile uses
/// it (avatars bucket policies), so the order matters: upload a new file,
/// point `avatar_path` to it, then delete the previous one. If the profile
/// cannot be updated, the new file is deleted and the previous photo stays.
///
/// Shared by onboarding and profile editing; callers wrap it with `guard`.
Future<void> replaceAvatar(
  SupabaseClient client,
  String userId,
  Uint8List bytes,
  PhotoFormat format,
) async {
  final avatars = client.storage.from('avatars');
  final row = await client
      .from('profiles')
      .select('avatar_path')
      .eq('id', userId)
      .single();
  final previousPath = row['avatar_path'] as String?;

  final path = userPhotoPath(
    userId: userId,
    fileName: uniquePhotoFileName(),
    format: format,
  );
  await avatars.uploadBinary(
    path,
    bytes,
    fileOptions: FileOptions(contentType: format.mimeType),
  );
  try {
    // Selecting the row makes an update that matched nothing fail, instead
    // of silently doing nothing.
    await client
        .from('profiles')
        .update({'avatar_path': path})
        .eq('id', userId)
        .select('id')
        .single();
  } on Object {
    await _removeQuietly(avatars, path);
    rethrow;
  }
  if (previousPath != null) await _removeQuietly(avatars, previousPath);
}

Future<void> _removeQuietly(StorageFileApi avatars, String path) async {
  try {
    await avatars.remove([path]);
  } on Object {
    // A leftover file stays in the user's private folder, unseen by others,
    // until the account is deleted, which is harmless.
  }
}
