import 'package:evasion/app/router/access_status.dart';
import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/features/auth/data/supabase_auth_repository.dart';
import 'package:evasion/features/profile/data/supabase_profile_repository.dart';
import 'package:evasion/features/profile/presentation/own_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/fake_profile_repositories.dart';

void main() {
  late FakeProfileStore profiles;

  ProviderContainer containerFor({required bool signedIn}) =>
      ProviderContainer.test(
        // No automatic retry, so that a failed load stays failed.
        retry: (_, _) => null,
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(signedInUser: signedIn ? testUser : null),
          ),
          profileRepositoryProvider.overrideWithValue(profiles),
        ],
      );

  Future<AccessStatus> settledStatus(ProviderContainer container) async {
    final subscription = container.listen(accessStatusProvider, (_, _) {});
    await container
        .read(ownProfileProvider(testUser.id).future)
        .catchError((_) => emptyProfile(testUser.id));
    return subscription.read();
  }

  setUp(() => profiles = FakeProfileStore(emptyProfile(testUser.id)));

  test('signed out', () {
    final container = containerFor(signedIn: false);

    expect(container.read(accessStatusProvider), AccessStatus.signedOut);
  });

  test('signed in, while the profile loads', () {
    final container = containerFor(signedIn: true);

    expect(container.read(accessStatusProvider), AccessStatus.loadingProfile);
  });

  test('incomplete profile needs onboarding', () async {
    final container = containerFor(signedIn: true);

    expect(await settledStatus(container), AccessStatus.needsOnboarding);
  });

  test('complete profile is ready', () async {
    profiles.profile = completeProfile(testUser.id);
    final container = containerFor(signedIn: true);

    expect(await settledStatus(container), AccessStatus.ready);
  });

  test('a failed profile load is reported', () async {
    profiles.fetchFailure = const NetworkFailure();
    final container = containerFor(signedIn: true);

    expect(await settledStatus(container), AccessStatus.profileError);
  });
}
