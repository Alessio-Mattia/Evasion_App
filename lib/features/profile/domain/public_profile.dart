import 'package:evasion/core/utils/server_date.dart';
import 'package:evasion/features/profile/domain/profile.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'public_profile.freezed.dart';

/// A profile as other users see it: the age instead of the birth date, and
/// nothing private.
@freezed
abstract class PublicProfile with _$PublicProfile {
  const factory PublicProfile({
    required String id,
    required String displayName,
    required int age,
    required bool isStudentVerified,

    /// Path in the `avatars` bucket.
    String? avatarPath,
    String? occupation,
    String? university,
    String? bio,
  }) = _PublicProfile;
}

/// Reads a row of `get_public_profile`, or returns null for a row this
/// version of the app cannot show, such as one without a name.
PublicProfile? publicProfileFromRow(Map<String, dynamic> row) {
  final id = row['id'];
  final displayName = row['display_name'];
  final age = row['age'];
  if (id is! String || displayName is! String || age is! int) return null;
  return PublicProfile(
    id: id,
    displayName: displayName,
    age: age,
    isStudentVerified: row['is_student_verified'] as bool? ?? false,
    avatarPath: row['avatar_path'] as String?,
    occupation: row['occupation'] as String?,
    university: row['university'] as String?,
    bio: row['bio'] as String?,
  );
}

extension ProfileAsSeenByOthers on Profile {
  /// This profile as others see it on [today], or null while it has no name
  /// or birth date yet, that is before the end of onboarding.
  PublicProfile? asSeenByOthers(DateTime today) {
    final name = displayName;
    final birth = birthDate;
    if (name == null || birth == null) return null;
    return PublicProfile(
      id: id,
      displayName: name,
      age: ageOn(birth, today),
      isStudentVerified: isStudentVerified,
      avatarPath: avatarPath,
      occupation: occupation,
      university: university,
      bio: bio,
    );
  }
}
