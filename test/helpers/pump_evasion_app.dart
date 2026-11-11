import 'package:evasion/app/app.dart';
import 'package:evasion/app/config/app_environment.dart';
import 'package:evasion/features/auth/data/supabase_auth_repository.dart';
import 'package:evasion/features/auth/domain/auth_repository.dart';
import 'package:evasion/features/onboarding/data/supabase_onboarding_repository.dart';
import 'package:evasion/features/profile/data/supabase_profile_repository.dart';
import 'package:evasion/features/settings/data/supabase_settings_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_auth_repository.dart';
import 'fake_profile_repositories.dart';
import 'fake_settings_repository.dart';

/// Starts the app without Supabase. By default a user with a complete profile
/// is already signed in, so the app opens on the tabs; pass [authRepository]
/// or [profiles] to change that, and [settings] to control the settings.
Future<void> pumpEvasionApp(
  WidgetTester tester, {
  AuthRepository? authRepository,
  FakeProfileStore? profiles,
  FakeSettingsRepository? settings,
}) async {
  final store = profiles ?? FakeProfileStore(completeProfile(testUser.id));
  await tester.pumpWidget(
    ProviderScope(
      // The app retries failed loads after a delay; tests check each failure
      // as it is, without timers left running.
      retry: (_, _) => null,
      overrides: [
        appEnvironmentProvider.overrideWithValue(AppEnvironment.dev),
        authRepositoryProvider.overrideWithValue(
          authRepository ?? FakeAuthRepository(signedInUser: testUser),
        ),
        profileRepositoryProvider.overrideWithValue(store),
        onboardingRepositoryProvider.overrideWithValue(store),
        settingsRepositoryProvider.overrideWithValue(
          settings ?? FakeSettingsRepository(),
        ),
      ],
      child: const EvasionApp(),
    ),
  );
  await tester.pumpAndSettle();
}
