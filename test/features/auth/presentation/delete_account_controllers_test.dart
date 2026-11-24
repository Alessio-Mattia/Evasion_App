import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/features/auth/data/supabase_auth_repository.dart';
import 'package:evasion/features/auth/presentation/delete_account/delete_account_controllers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository auth;
  late ProviderContainer container;

  setUp(() {
    auth = FakeAuthRepository(signedInUser: testUser);
    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(auth)],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    // Keeps the auto-dispose controllers alive during the test.
    container
      ..listen(sendDeletionCodeControllerProvider, (_, _) {})
      ..listen(deleteAccountControllerProvider, (_, _) {});
  });

  Future<bool> delete(String code) =>
      container.read(deleteAccountControllerProvider.notifier).delete(code);

  test('sends a code to confirm the deletion', () async {
    final sent = await container
        .read(sendDeletionCodeControllerProvider.notifier)
        .send();

    expect(sent, isTrue);
    expect(auth.reauthenticationCodesSent, 1);
  });

  test('checks the code, deletes the account and signs out', () async {
    expect(await delete(' 123456 '), isTrue);

    expect(auth.verifyCodeCalls, 1);
    expect(auth.deleteAccountCalls, 1);
    expect(auth.isDeleted, isTrue);
    expect(auth.currentUser, isNull);
  });

  test('a wrong code deletes nothing', () async {
    expect(await delete('000000'), isFalse);

    expect(auth.deleteAccountCalls, 0);
    expect(
      container.read(deleteAccountControllerProvider).error,
      isA<InvalidCodeFailure>(),
    );
  });

  test(
    'after a failed deletion, retrying does not check the code again',
    () async {
      auth.deleteAccountFailure = const NetworkFailure();
      expect(await delete('123456'), isFalse);

      auth.deleteAccountFailure = null;
      expect(await delete('123456'), isTrue);

      // A code works only once: checking it again would fail.
      expect(auth.verifyCodeCalls, 1);
      expect(auth.deleteAccountCalls, 2);
    },
  );

  test('a code too old for the server needs a new one', () async {
    auth.deleteAccountFailure = const ReauthenticationRequiredFailure();
    expect(await delete('123456'), isFalse);
    expect(
      container.read(deleteAccountControllerProvider).error,
      isA<ReauthenticationRequiredFailure>(),
    );

    auth.deleteAccountFailure = null;
    expect(await delete('123456'), isTrue);

    expect(auth.verifyCodeCalls, 2);
  });
}
