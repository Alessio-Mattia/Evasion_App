import 'dart:async';

import 'package:evasion/features/auth/presentation/sign_in_code_screen.dart';
import 'package:evasion/features/auth/presentation/sign_in_email_screen.dart';
import 'package:evasion/features/map/presentation/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/pump_evasion_app.dart';

void main() {
  late FakeAuthRepository repository;

  setUp(() => repository = FakeAuthRepository());

  Future<void> enterEmail(WidgetTester tester, String email) async {
    await tester.enterText(find.byType(TextFormField), email);
    await tester.tap(find.text('Recevoir un code'));
    await tester.pumpAndSettle();
  }

  testWidgets('a signed-out user lands on the email screen', (tester) async {
    await pumpEvasionApp(tester, authRepository: repository);

    expect(find.byType(SignInEmailScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('a malformed email is refused before calling the server', (
    tester,
  ) async {
    await pumpEvasionApp(tester, authRepository: repository);

    await enterEmail(tester, 'alex@');

    expect(find.text('Saisis une adresse e-mail valide.'), findsOneWidget);
    expect(repository.sentCodesTo, isEmpty);
  });

  testWidgets('a valid email leads to the code screen', (tester) async {
    await pumpEvasionApp(tester, authRepository: repository);

    await enterEmail(tester, ' Alex@EPFL.ch ');

    expect(repository.sentCodesTo, ['alex@epfl.ch']);
    expect(find.byType(SignInCodeScreen), findsOneWidget);
    expect(find.textContaining('alex@epfl.ch'), findsOneWidget);
  });

  testWidgets('the keyboard done key does not send a second code request', (
    tester,
  ) async {
    await pumpEvasionApp(tester, authRepository: repository);
    repository.pendingCall = Completer<void>();

    await tester.enterText(find.byType(TextFormField), 'alex@epfl.ch');
    await tester.tap(find.text('Recevoir un code'));
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(repository.sentCodesTo, hasLength(1));
    repository.pendingCall!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('the code is checked once, even if done follows the last digit', (
    tester,
  ) async {
    await pumpEvasionApp(tester, authRepository: repository);
    await enterEmail(tester, 'alex@epfl.ch');
    repository.pendingCall = Completer<void>();

    // The last digit submits, then the done key is pressed during the check.
    await tester.enterText(find.byType(TextFormField), '123456');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(repository.verifyCodeCalls, 1);
    repository.pendingCall!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('a wrong code shows its message and stays', (tester) async {
    await pumpEvasionApp(tester, authRepository: repository);
    await enterEmail(tester, 'alex@epfl.ch');

    await tester.enterText(find.byType(TextFormField), '000000');
    await tester.pumpAndSettle();

    expect(find.text('Ce code est incorrect ou a expiré.'), findsOneWidget);
    expect(find.byType(SignInCodeScreen), findsOneWidget);
  });

  testWidgets('the right code opens the app, signing out comes back', (
    tester,
  ) async {
    await pumpEvasionApp(tester, authRepository: repository);
    await enterEmail(tester, 'alex@epfl.ch');

    // Typing the last digit submits the code.
    await tester.enterText(find.byType(TextFormField), '123456');
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Se déconnecter'));
    await tester.pumpAndSettle();
    expect(find.byType(SignInEmailScreen), findsOneWidget);
  });
}
