import 'package:evasion/core/config/business_rules.dart';
import 'package:evasion/core/validation/profile_validators.dart';
import 'package:evasion/features/profile/domain/profile.dart';
import 'package:flutter/foundation.dart';

/// The texts of a profile that its owner can edit at any time.
///
/// Always normalized: trimmed, and a blank optional text is null, as it is
/// stored. Two details are thus equal when saving would change nothing.
@immutable
class ProfileDetails {
  /// From what the user typed.
  ProfileDetails({
    required String displayName,
    required String occupation,
    required String university,
    required String bio,
  }) : this._(
         displayName: displayName.trim(),
         occupation: _blankToNull(occupation),
         university: _blankToNull(university),
         bio: _blankToNull(bio),
       );

  /// The details as stored in [profile].
  factory ProfileDetails.of(Profile profile) => ProfileDetails(
    displayName: profile.displayName ?? '',
    occupation: profile.occupation ?? '',
    university: profile.university ?? '',
    bio: profile.bio ?? '',
  );

  const ProfileDetails._({
    required this.displayName,
    required this.occupation,
    required this.university,
    required this.bio,
  });

  final String displayName;
  final String? occupation;
  final String? university;
  final String? bio;

  /// Whether the server will accept these details.
  bool get isValid =>
      validateDisplayName(displayName) == null &&
      fitsLength(occupation ?? '', BusinessRules.occupationMaxLength) &&
      fitsLength(university ?? '', BusinessRules.universityMaxLength) &&
      fitsLength(bio ?? '', BusinessRules.bioMaxLength);

  static String? _blankToNull(String text) {
    final trimmed = text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  bool operator ==(Object other) =>
      other is ProfileDetails &&
      other.displayName == displayName &&
      other.occupation == occupation &&
      other.university == university &&
      other.bio == bio;

  @override
  int get hashCode => Object.hash(displayName, occupation, university, bio);

  @override
  String toString() =>
      'ProfileDetails($displayName, $occupation, $university, $bio)';
}
