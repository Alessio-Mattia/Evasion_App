import 'package:evasion/core/errors/app_failure.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/pump_evasion_app.dart';

void main() {
  late FakeAuthRepository auth;

  setUp(() => auth = FakeAuthRepository(signedInUser: testUser));

  /// Profile tab, settings, then the deletion screen at the bottom.
  Future<void> openDeletion(WidgetTester tester) async {
    await pumpEvasionApp(tester, authRepository: auth);
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Paramètres'));
    await tester.pumpAndSettle();
    final button = find.text('Supprimer mon compte');
    await tester.scrollUntilVisible(button, 200);
    // Fully on screen, not under the tab bar.
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Finder deleteButton() =>
      find.widgetWithText(FilledButton, 'Supprimer définitivement');

  /// The test window is smaller than a phone: the form scrolls.
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> sendCode(WidgetTester tester) async {
    await tapVisible(tester, find.text('Recevoir un code'));
  }

  testWidgets('explains what is deleted before sending any code', (
    tester,
  ) async {
    await openDeletion(tester);

    expect(find.text('Supprimer ton compte'), findsOneWidget);
    expect(find.textContaining('supprimés définitivement'), findsOneWidget);
    expect(auth.reauthenticationCodesSent, 0);
    expect(deleteButton(), findsNothing);
  });

  testWidgets('deletes the account with the code, then shows sign-in', (
    tester,
  ) async {
    await openDeletion(tester);
    await sendCode(tester);

    expect(auth.reauthenticationCodesSent, 1);
    expect(find.textContaining(testUser.email!), findsOneWidget);
    // Disabled until the code has all its digits.
    expect(tester.widget<FilledButton>(deleteButton()).onPressed, isNull);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    // No deletion on the last digit: it needs a tap.
    expect(auth.deleteAccountCalls, 0);
    await tapVisible(tester, deleteButton());

    expect(auth.isDeleted, isTrue);
    expect(find.text('Ton compte a été supprimé.'), findsOneWidget);
    expect(find.text('Supprimer ton compte'), findsNothing);
  });

  testWidgets('a wrong code says why and deletes nothing', (tester) async {
    await openDeletion(tester);
    await sendCode(tester);

    await tester.enterText(find.byType(TextField), '000000');
    await tester.pump();
    await tapVisible(tester, deleteButton());

    expect(auth.isDeleted, isFalse);
    expect(find.text('Ce code est incorrect ou a expiré.'), findsOneWidget);
    expect(find.text('Supprimer ton compte'), findsOneWidget);
  });

  testWidgets('a code too old asks for a new one, which can be sent', (
    tester,
  ) async {
    auth.deleteAccountFailure = const ReauthenticationRequiredFailure();
    await openDeletion(tester);
    await sendCode(tester);
    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    await tapVisible(tester, deleteButton());

    expect(
      find.text('Ton code date de plus de 5 minutes : demande-en un nouveau.'),
      findsOneWidget,
    );

    // The message covers the bottom of the small test window until it goes.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Renvoyer le code'));
    expect(auth.reauthenticationCodesSent, 2);
  });
}
