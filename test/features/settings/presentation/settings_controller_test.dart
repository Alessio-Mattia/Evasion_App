import 'dart:async';

import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/features/settings/data/supabase_settings_repository.dart';
import 'package:evasion/features/settings/presentation/settings_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_settings_repository.dart';

void main() {
  late FakeSettingsRepository repository;
  late ProviderContainer container;
  late ProviderSubscription<AsyncValue<Object?>> subscription;

  setUp(() async {
    repository = FakeSettingsRepository();
    container = ProviderContainer.test(
      overrides: [settingsRepositoryProvider.overrideWithValue(repository)],
    );
    subscription = container.listen(settingsControllerProvider, (_, _) {});
    await container.read(settingsControllerProvider.future);
  });

  SettingsController controller() =>
      container.read(settingsControllerProvider.notifier);

  test('a change is shown and saved', () async {
    final failure = await controller().change(
      (s) => s.copyWith(detectionRadiusM: 500),
    );

    expect(failure, isNull);
    expect(repository.saved.single.detectionRadiusM, 500);
    expect(
      container.read(settingsControllerProvider).value?.detectionRadiusM,
      500,
    );
  });

  test('the change is shown before the server answers', () async {
    repository.pendingSave = Completer<void>();

    final saving = controller().change((s) => s.copyWith(prefAgeMin: 25));

    expect(container.read(settingsControllerProvider).value?.prefAgeMin, 25);
    repository.pendingSave!.complete();
    await saving;
  });

  test('a failed save goes back to the saved value', () async {
    repository.saveFailure = const NetworkFailure();

    final failure = await controller().change(
      (s) => s.copyWith(detectionRadiusM: 500),
    );

    expect(failure, isA<NetworkFailure>());
    expect(container.read(settingsControllerProvider).value, defaultSettings);
  });

  test('two quick changes that both fail go back to the saved value', () async {
    repository
      ..pendingSave = Completer<void>()
      ..saveFailure = const NetworkFailure();

    final first = controller().change((s) => s.copyWith(detectionRadiusM: 500));
    final second = controller().change((s) => s.copyWith(prefAgeMin: 25));
    repository.pendingSave!.complete();
    await first;
    await second;

    // Not to the state before the second change, which held the first one:
    // the server holds neither.
    expect(container.read(settingsControllerProvider).value, defaultSettings);
    expect(subscription.read().hasError, isFalse);
  });

  test('after a saved change, a failed one goes back to it', () async {
    await controller().change((s) => s.copyWith(detectionRadiusM: 500));
    repository.saveFailure = const NetworkFailure();

    await controller().change((s) => s.copyWith(prefAgeMin: 25));

    final shown = container.read(settingsControllerProvider).value;
    expect(shown?.detectionRadiusM, 500);
    expect(shown?.prefAgeMin, 18);
  });

  test('an unchanged value is not saved', () async {
    final failure = await controller().change((s) => s);

    expect(failure, isNull);
    expect(repository.saved, isEmpty);
  });
}
