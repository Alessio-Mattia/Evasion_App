import 'package:evasion/features/auth/presentation/current_user.dart';
import 'package:evasion/features/profile/presentation/own_profile.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'access_status.g.dart';

/// What the signed-in user can access, which decides the screens shown.
enum AccessStatus {
  signedOut,
  loadingProfile,
  profileError,

  /// Signed in, but the required profile fields are not all filled.
  needsOnboarding,
  ready,
}

/// Combines the session and the profile. Lives in `app/` because it joins two
/// features that must not import each other.
@Riverpod(keepAlive: true)
AccessStatus accessStatus(Ref ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return AccessStatus.signedOut;
  // While the profile reloads, its previous value is kept: the app does not
  // flash the loading screen after each change.
  return switch (ref.watch(ownProfileProvider(user.id))) {
    AsyncValue(:final value?) =>
      value.isComplete ? AccessStatus.ready : AccessStatus.needsOnboarding,
    AsyncValue(hasError: true) => AccessStatus.profileError,
    _ => AccessStatus.loadingProfile,
  };
}
