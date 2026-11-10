import 'package:evasion/app/router/access_status.dart';
import 'package:evasion/app/router/app_routes.dart';

/// Where to send the user before showing [location], or null to stay.
///
/// Each status has its own area: the sign-in screens, the startup screen, the
/// onboarding, or the app itself. Only a ready user reaches the app.
String? accessRedirect({
  required AccessStatus status,
  required String location,
}) {
  final target = switch (status) {
    AccessStatus.signedOut => AppRoutes.signIn,
    AccessStatus.loadingProfile ||
    AccessStatus.profileError => AppRoutes.startup,
    AccessStatus.needsOnboarding => AppRoutes.onboarding,
    AccessStatus.ready => null,
  };
  if (target != null) return location.startsWith(target) ? null : target;

  final isOutsideApp = [
    AppRoutes.signIn,
    AppRoutes.startup,
    AppRoutes.onboarding,
  ].any(location.startsWith);
  return isOutsideApp ? AppRoutes.home : null;
}
