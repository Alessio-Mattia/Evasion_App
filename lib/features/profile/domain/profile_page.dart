import 'package:evasion/core/models/interest.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile_page.freezed.dart';

/// A free page of the profile carousel, after the page built from the profile
/// itself.
@freezed
sealed class ProfilePage with _$ProfilePage {
  const factory ProfilePage.text({
    required String id,
    required int position,
    required String text,
  }) = TextPage;

  const factory ProfilePage.photo({
    required String id,
    required int position,

    /// Path in the `profile-photos` bucket.
    required String imagePath,
    String? caption,
  }) = PhotoPage;

  const factory ProfilePage.interests({
    required String id,
    required int position,
    required List<Interest> interests,
  }) = InterestsPage;
}

/// Reads a `profile_pages` row, or returns null for a page this version of the
/// app cannot show: a type added later, or interests all unknown to it. An
/// older app then shows one page less instead of failing.
ProfilePage? profilePageFromRow(Map<String, dynamic> row) {
  final id = row['id'] as String;
  final position = row['position'] as int;
  final content = row['content'] as Map<String, dynamic>? ?? const {};
  return switch (row['type']) {
    'text' => switch (content['text']) {
      final String text => ProfilePage.text(
        id: id,
        position: position,
        text: text,
      ),
      _ => null,
    },
    'photo' => switch (row['image_path']) {
      final String imagePath => ProfilePage.photo(
        id: id,
        position: position,
        imagePath: imagePath,
        caption: content['caption'] as String?,
      ),
      _ => null,
    },
    'interests' => switch (Interest.fromCodes(
      (content['interests'] as List<dynamic>? ?? const []).whereType<String>(),
    )) {
      final interests when interests.isNotEmpty => ProfilePage.interests(
        id: id,
        position: position,
        interests: interests,
      ),
      _ => null,
    },
    _ => null,
  };
}
