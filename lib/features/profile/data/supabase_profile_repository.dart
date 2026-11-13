import 'dart:typed_data';

import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/core/errors/failure_mapper.dart';
import 'package:evasion/core/photos/photo_file.dart';
import 'package:evasion/core/storage/avatar_upload.dart' as avatar_upload;
import 'package:evasion/core/supabase/supabase_client_provider.dart';
import 'package:evasion/core/utils/server_date.dart';
import 'package:evasion/features/profile/domain/page_draft.dart';
import 'package:evasion/features/profile/domain/page_positions.dart';
import 'package:evasion/features/profile/domain/profile.dart';
import 'package:evasion/features/profile/domain/profile_details.dart';
import 'package:evasion/features/profile/domain/profile_page.dart';
import 'package:evasion/features/profile/domain/profile_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'supabase_profile_repository.g.dart';

@Riverpod(keepAlive: true)
ProfileRepository profileRepository(Ref ref) =>
    SupabaseProfileRepository(ref.watch(supabaseClientProvider));

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  static const _columns =
      'id, display_name, birth_date, gender, avatar_path, '
      'occupation, university, bio, is_student_verified, is_complete, '
      'birth_date_corrected';

  StorageFileApi get _photos => _client.storage.from('profile-photos');

  @override
  Future<Profile> fetchOwnProfile(String userId) => guard(() async {
    final row = await _client
        .from('profiles')
        .select(_columns)
        .eq('id', userId)
        .single();
    return Profile.fromJson(row);
  });

  @override
  Future<void> updateDetails(String userId, ProfileDetails details) =>
      _updateProfile(userId, {
        'display_name': details.displayName,
        // Null clears a text the user emptied.
        'occupation': details.occupation,
        'university': details.university,
        'bio': details.bio,
      });

  @override
  Future<void> replaceAvatar(
    String userId,
    Uint8List bytes,
    PhotoFormat format,
  ) => guard(() => avatar_upload.replaceAvatar(_client, userId, bytes, format));

  @override
  Future<void> correctBirthDate(String userId, DateTime birthDate) =>
      // The server allows one correction only, and refuses the next ones.
      _updateProfile(userId, {'birth_date': toSqlDate(birthDate)});

  /// Selecting the row makes an update that matched nothing fail, instead of
  /// silently doing nothing.
  Future<void> _updateProfile(String userId, Map<String, Object?> changes) =>
      guard(
        () => _client
            .from('profiles')
            .update(changes)
            .eq('id', userId)
            .select('id')
            .single(),
      );

  @override
  Future<List<ProfilePage>> fetchOwnPages(String userId) => guard(() async {
    final rows = await _client
        .from('profile_pages')
        .select('id, position, type, content, image_path')
        .eq('profile_id', userId)
        // Unlike SQL, the client sorts in descending order by default.
        .order('position', ascending: true);
    return [for (final row in rows) ?profilePageFromRow(row)];
  });

  @override
  Future<List<PageSlot>> fetchOwnPageSlots(String userId) => guard(() async {
    final rows = await _client
        .from('profile_pages')
        .select('id, position')
        .eq('profile_id', userId);
    return [
      for (final row in rows)
        (id: row['id'] as String, position: row['position'] as int),
    ];
  });

  @override
  Future<void> addPage(
    String userId,
    PageDraft draft, {
    required int position,
  }) => guard(() async {
    final uploaded = await _uploadNewPhoto(userId, draft);
    try {
      await _client.from('profile_pages').insert({
        'position': position,
        'type': draft.type.code,
        'content': draft.content,
        'image_path': ?uploaded ?? _keptPhoto(draft),
      });
    } on Object {
      if (uploaded != null) await _removeQuietly(uploaded);
      rethrow;
    }
  });

  @override
  Future<void> updatePage(String userId, ProfilePage page, PageDraft draft) =>
      guard(() async {
        // A page keeps its template: only its content changes.
        if (draft.type != page.type) throw const InvalidInputFailure();
        final uploaded = await _uploadNewPhoto(userId, draft);
        try {
          // Selecting the row makes an update that matched nothing, such as a
          // page deleted from another phone, fail instead of doing nothing.
          await _client
              .from('profile_pages')
              .update({'content': draft.content, 'image_path': ?uploaded})
              .eq('id', page.id)
              .select('id')
              .single();
        } on Object {
          if (uploaded != null) await _removeQuietly(uploaded);
          rethrow;
        }
        // The previous photo is no longer used, so the server lets it go.
        if ((uploaded, page) case (_?, PhotoPage(:final imagePath))) {
          await _removeQuietly(imagePath);
        }
      });

  @override
  Future<void> deletePage(ProfilePage page) => guard(() async {
    await _client.from('profile_pages').delete().eq('id', page.id);
    // The photo can only be deleted once no page uses it.
    if (page case PhotoPage(:final imagePath)) await _removeQuietly(imagePath);
  });

  @override
  Future<void> reorderPages(List<String> pageIds) => guard(
    () => _client.rpc<void>(
      'reorder_profile_pages',
      params: {'page_ids': pageIds},
    ),
  );

  /// Uploads the photo of [draft] if it brings a new one, and returns its
  /// path.
  Future<String?> _uploadNewPhoto(String userId, PageDraft draft) async =>
      switch (draft) {
        PhotoPageDraft(:final bytes, :final format) => await _upload(
          userId,
          bytes,
          format,
        ),
        _ => null,
      };

  static String? _keptPhoto(PageDraft draft) => switch (draft) {
    KeptPhotoPageDraft(:final imagePath) => imagePath,
    _ => null,
  };

  Future<String> _upload(
    String userId,
    Uint8List bytes,
    PhotoFormat format,
  ) async {
    // A photo in use cannot be overwritten: always a new file name.
    final path = userPhotoPath(
      userId: userId,
      fileName: uniquePhotoFileName(),
      format: format,
    );
    await _photos.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: format.mimeType),
    );
    return path;
  }

  Future<void> _removeQuietly(String path) async {
    try {
      await _photos.remove([path]);
    } on Object {
      // A leftover file stays in the user's private folder, unseen by others,
      // until the account is deleted, which is harmless.
    }
  }
}
