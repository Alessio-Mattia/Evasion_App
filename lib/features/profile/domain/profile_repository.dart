import 'package:evasion/features/profile/domain/profile.dart';

/// Reads profiles. Every method throws an `AppFailure` on error.
abstract interface class ProfileRepository {
  /// The profile of [userId], who must be the signed-in user.
  Future<Profile> fetchOwnProfile(String userId);
}
