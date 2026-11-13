import 'package:evasion/core/models/gender.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile.freezed.dart';
part 'profile.g.dart';

/// The signed-in user's own profile, as stored in `profiles`.
///
/// Required fields stay empty until onboarding; [isComplete] is computed by the
/// server and says whether they are all filled.
@freezed
abstract class Profile with _$Profile {
  const factory Profile({
    required String id,
    required bool isComplete,
    required bool isStudentVerified,
    String? displayName,
    DateTime? birthDate,
    Gender? gender,
    String? avatarPath,
    String? occupation,
    String? university,
    String? bio,

    /// Whether the only birth date correction allowed has been used.
    @Default(false) bool birthDateCorrected,
  }) = _Profile;

  factory Profile.fromJson(Map<String, dynamic> json) =>
      _$ProfileFromJson(json);
}
