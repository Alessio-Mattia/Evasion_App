import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/core/photos/photo_file.dart';
import 'package:evasion/features/profile/data/supabase_profile_repository.dart';
import 'package:evasion/features/profile/domain/profile_details.dart';
import 'package:evasion/features/profile/presentation/own_profile.dart';
import 'package:evasion/features/profile/presentation/profile_edit/profile_edit_controllers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_photo_picker.dart';
import '../../../helpers/fake_profile_repositories.dart';

const userId = 'user-1';

void main() {
  late FakeProfileStore store;
  late ProviderContainer container;

  setUp(() {
    store = FakeProfileStore(completeProfile(userId));
    container = ProviderContainer(
      overrides: [profileRepositoryProvider.overrideWithValue(store)],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    // Watched as the app does, through the access status.
    container.listen(ownProfileProvider(userId), (_, _) {});
  });

  Future<void> loadProfile() =>
      container.read(ownProfileProvider(userId).future);

  void keepAlive(ProviderListenable<Object?> provider) {
    // Keeps the auto-dispose controller alive during the test.
    container.listen(provider, (_, _) {});
  }

  final details = ProfileDetails(
    displayName: 'Sam',
    occupation: 'Biologie',
    university: '',
    bio: 'Salut !',
  );

  group('SaveDetailsController', () {
    test('saves, then the profile shows the new texts', () async {
      await loadProfile();
      keepAlive(saveDetailsControllerProvider(userId));

      final saved = await container
          .read(saveDetailsControllerProvider(userId).notifier)
          .save(details);

      expect(saved, isTrue);
      expect(store.profileCalls, ['details']);
      final profile = container.read(ownProfileProvider(userId)).value!;
      expect(profile.displayName, 'Sam');
      expect(profile.occupation, 'Biologie');
    });

    test('a failure is kept in the state, typed', () async {
      await loadProfile();
      keepAlive(saveDetailsControllerProvider(userId));
      store.saveFailure = const NetworkFailure();

      final saved = await container
          .read(saveDetailsControllerProvider(userId).notifier)
          .save(details);

      expect(saved, isFalse);
      expect(
        container.read(saveDetailsControllerProvider(userId)).error,
        isA<NetworkFailure>(),
      );
    });

    test('a second save while the first runs is ignored', () async {
      await loadProfile();
      keepAlive(saveDetailsControllerProvider(userId));
      final notifier = container.read(
        saveDetailsControllerProvider(userId).notifier,
      );

      final results = await Future.wait([
        notifier.save(details),
        notifier.save(details),
      ]);

      expect(results, [isTrue, isFalse]);
      expect(store.profileCalls, ['details']);
    });
  });

  test('ReplaceAvatarController shows the new photo once saved', () async {
    await loadProfile();
    keepAlive(replaceAvatarControllerProvider(userId));

    final replaced = await container
        .read(replaceAvatarControllerProvider(userId).notifier)
        .replace(pngBytes, PhotoFormat.png);

    expect(replaced, isTrue);
    expect(
      container.read(ownProfileProvider(userId)).value!.avatarPath,
      '$userId/avatar-1.png',
    );
  });

  group('CorrectBirthDateController', () {
    test('corrects once, then the profile says so', () async {
      await loadProfile();
      keepAlive(correctBirthDateControllerProvider(userId));

      final corrected = await container
          .read(correctBirthDateControllerProvider(userId).notifier)
          .correct(DateTime(2001, 2, 3));

      expect(corrected, isTrue);
      final profile = container.read(ownProfileProvider(userId)).value!;
      expect(profile.birthDate, DateTime(2001, 2, 3));
      expect(profile.birthDateCorrected, isTrue);
    });

    test('a refused correction reloads the profile anyway', () async {
      // Corrected meanwhile, for example from another phone.
      store.profile = store.profile.copyWith(birthDateCorrected: true);
      keepAlive(correctBirthDateControllerProvider(userId));
      final fetchesBefore = store.fetchCount;

      final corrected = await container
          .read(correctBirthDateControllerProvider(userId).notifier)
          .correct(DateTime(2001, 2, 3));

      expect(corrected, isFalse);
      expect(
        container.read(correctBirthDateControllerProvider(userId)).error,
        isA<InvalidInputFailure>(),
      );
      expect(store.fetchCount, greaterThan(fetchesBefore));
    });
  });
}
