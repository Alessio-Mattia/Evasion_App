import 'package:evasion/app/config/app_environment.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final environment in AppEnvironment.values) {
    test('provider exposes the injected environment: ${environment.name}', () {
      final container = ProviderContainer.test(
        overrides: [appEnvironmentProvider.overrideWithValue(environment)],
      );

      expect(container.read(appEnvironmentProvider), environment);
    });
  }
}
