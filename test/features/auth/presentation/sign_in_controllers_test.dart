import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/features/auth/data/supabase_auth_repository.dart';
import 'package:evasion/features/auth/presentation/current_user.dart';
import 'package:evasion/features/auth/presentation/sign_in_controllers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = FakeAuthRepository();
    container = ProviderContainer.test(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
  });

  group('SendCodeController', () {
    test('sends the code to the normalized email', () async {
      final subscription = container.listen(
        sendCodeControllerProvider,
        (_, _) {},
      );

      final sent = await container
          .read(sendCodeControllerProvider.notifier)
          .sendCode('  Alex@EPFL.ch ');

      expect(sent, isTrue);
      expect(repository.sentCodesTo, ['alex@epfl.ch']);
      expect(subscription.read(), isA<AsyncData<void>>());
    });

    test('keeps the failure in its state', () async {
      repository.sendCodeFailure = const NetworkFailure();
      final subscription = container.listen(
        sendCodeControllerProvider,
        (_, _) {},
      );

      final sent = await container
          .read(sendCodeControllerProvider.notifier)
          .sendCode('alex@epfl.ch');

      expect(sent, isFalse);
      expect(subscription.read().error, isA<NetworkFailure>());
    });
  });

  group('VerifyCodeController', () {
    test('a valid code signs the user in', () async {
      container.listen(verifyCodeControllerProvider, (_, _) {});
      final user = container.listen(currentUserProvider, (_, _) {});
      expect(user.read(), isNull);

      await container
          .read(verifyCodeControllerProvider.notifier)
          .verifyCode(email: 'alex@epfl.ch', code: '123456');
      await Future<void>.delayed(Duration.zero);

      expect(user.read()?.email, 'alex@epfl.ch');
    });

    test('a wrong code leaves an InvalidCodeFailure', () async {
      final subscription = container.listen(
        verifyCodeControllerProvider,
        (_, _) {},
      );

      await container
          .read(verifyCodeControllerProvider.notifier)
          .verifyCode(email: 'alex@epfl.ch', code: '000000');

      expect(subscription.read().error, isA<InvalidCodeFailure>());
    });
  });
}
