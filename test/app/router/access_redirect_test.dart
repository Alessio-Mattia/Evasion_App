import 'package:evasion/app/router/access_redirect.dart';
import 'package:evasion/app/router/access_status.dart';
import 'package:evasion/app/router/app_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String? redirect(AccessStatus status, String location) =>
      accessRedirect(status: status, location: location);

  const appScreens = [AppRoutes.home, AppRoutes.profile];
  const otherAreas = [
    AppRoutes.signIn,
    AppRoutes.signInCode,
    AppRoutes.startup,
    AppRoutes.onboarding,
  ];

  test('signed out: everything leads to sign-in, which stays', () {
    for (final location in [...appScreens, AppRoutes.startup]) {
      expect(redirect(AccessStatus.signedOut, location), AppRoutes.signIn);
    }
    expect(redirect(AccessStatus.signedOut, AppRoutes.signInCode), isNull);
  });

  test('profile loading or failed: the startup screen', () {
    for (final status in [
      AccessStatus.loadingProfile,
      AccessStatus.profileError,
    ]) {
      expect(redirect(status, AppRoutes.home), AppRoutes.startup);
      expect(redirect(status, AppRoutes.signIn), AppRoutes.startup);
      expect(redirect(status, AppRoutes.startup), isNull);
    }
  });

  test('incomplete profile: the onboarding, even from the app', () {
    for (final location in [...appScreens, AppRoutes.signIn]) {
      expect(
        redirect(AccessStatus.needsOnboarding, location),
        AppRoutes.onboarding,
      );
    }
    expect(
      redirect(AccessStatus.needsOnboarding, AppRoutes.onboarding),
      isNull,
    );
  });

  test('ready: the app, never the other areas', () {
    for (final location in appScreens) {
      expect(redirect(AccessStatus.ready, location), isNull);
    }
    for (final location in otherAreas) {
      expect(redirect(AccessStatus.ready, location), AppRoutes.home);
    }
  });
}
