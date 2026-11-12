import 'package:evasion/features/profile/domain/profile.dart';
import 'package:evasion/features/profile/domain/profile_page.dart';

/// Reads profiles. Every method throws an `AppFailure` on error.
abstract interface class ProfileRepository {
  /// The profile of [userId], who must be the signed-in user.
  Future<Profile> fetchOwnProfile(String userId);

  /// The carousel pages of [userId], in their order. Pages this version of the
  /// app cannot show are left out.
  Future<List<ProfilePage>> fetchOwnPages(String userId);
}
