import 'package:evasion/app/router/app_routes.dart';
import 'package:evasion/app/router/auth_redirect.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('signed out', () {
    test('any app screen leads to sign-in', () {
      for (final location in [AppRoutes.home, AppRoutes.profile]) {
        expect(
          authRedirect(isSignedIn: false, location: location),
          AppRoutes.signIn,
          reason: location,
        );
      }
    });

    test('the sign-in screens stay', () {
      for (final location in [AppRoutes.signIn, AppRoutes.signInCode]) {
        expect(authRedirect(isSignedIn: false, location: location), isNull);
      }
    });
  });

  group('signed in', () {
    test('the sign-in screens lead home', () {
      for (final location in [AppRoutes.signIn, AppRoutes.signInCode]) {
        expect(
          authRedirect(isSignedIn: true, location: location),
          AppRoutes.home,
        );
      }
    });

    test('app screens stay', () {
      expect(
        authRedirect(isSignedIn: true, location: AppRoutes.messages),
        isNull,
      );
    });
  });
}
