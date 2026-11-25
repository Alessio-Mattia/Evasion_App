import 'package:evasion/app/app.dart';
import 'package:evasion/app/config/app_environment.dart';
import 'package:evasion/core/services/location_service.dart';
import 'package:evasion/core/services/photo_picker.dart';
import 'package:evasion/core/storage/storage_images.dart';
import 'package:evasion/features/auth/data/supabase_auth_repository.dart';
import 'package:evasion/features/auth/domain/auth_repository.dart';
import 'package:evasion/features/onboarding/data/supabase_onboarding_repository.dart';
import 'package:evasion/features/posts/data/supabase_posts_repository.dart';
import 'package:evasion/features/profile/data/supabase_profile_repository.dart';
import 'package:evasion/features/settings/data/supabase_settings_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_auth_repository.dart';
import 'fake_location_service.dart';
import 'fake_photo_picker.dart';
import 'fake_posts_repository.dart';
import 'fake_profile_repositories.dart';
import 'fake_settings_repository.dart';
import 'fake_storage_images.dart';

/// Starts the app without Supabase. By default a user with a complete profile
/// is already signed in, so the app opens on the tabs; pass [authRepository]
/// or [profiles] to change that, and [settings] to control the settings.
/// [photoPicker] replaces the phone's gallery and camera, [storageImages]
/// the links to private photos, [location] the phone's position and [posts]
/// the posts.
Future<void> pumpEvasionApp(
  WidgetTester tester, {
  AuthRepository? authRepository,
  FakeProfileStore? profiles,
  FakeSettingsRepository? settings,
  FakePhotoPicker? photoPicker,
  FakeStorageImages? storageImages,
  FakeLocationService? location,
  FakePostsRepository? posts,
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
        photoPickerProvider.overrideWithValue(photoPicker ?? FakePhotoPicker()),
        storageImagesProvider.overrideWithValue(
          storageImages ?? FakeStorageImages(),
        ),
        locationServiceProvider.overrideWithValue(
          location ?? FakeLocationService(),
        ),
        postsRepositoryProvider.overrideWithValue(
          posts ?? FakePostsRepository(),
        ),
      ],
      child: const EvasionApp(),
    ),
  );
  await tester.pumpAndSettle();
}
