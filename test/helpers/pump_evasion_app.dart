import 'package:evasion/app/app.dart';
import 'package:evasion/app/config/app_environment.dart';
import 'package:evasion/features/auth/data/supabase_auth_repository.dart';
import 'package:evasion/features/auth/domain/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_auth_repository.dart';

/// Starts the app without Supabase. By default a user is already signed in,
/// so the app opens on the tabs; pass [authRepository] to change that.
Future<void> pumpEvasionApp(
  WidgetTester tester, {
  AuthRepository? authRepository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appEnvironmentProvider.overrideWithValue(AppEnvironment.dev),
        authRepositoryProvider.overrideWithValue(
          authRepository ?? FakeAuthRepository(signedInUser: testUser),
        ),
      ],
      child: const EvasionApp(),
    ),
  );
  await tester.pumpAndSettle();
}
