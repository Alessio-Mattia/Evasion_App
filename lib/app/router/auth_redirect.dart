import 'package:evasion/app/router/app_routes.dart';

/// Where to send the user before showing [location], or null to stay.
///
/// Signed-out users only see the sign-in screens; signed-in users never do.
String? authRedirect({required bool isSignedIn, required String location}) {
  final isOnSignIn = location.startsWith(AppRoutes.signIn);
  if (!isSignedIn) return isOnSignIn ? null : AppRoutes.signIn;
  if (isOnSignIn) return AppRoutes.home;
  return null;
}
