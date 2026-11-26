import 'package:evasion/app/startup/startup_screen.dart';
import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/core/models/gender.dart';
import 'package:evasion/features/onboarding/presentation/onboarding_screen.dart';
import 'package:evasion/features/posts/presentation/map/posts_map_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/fake_profile_repositories.dart';
import '../../../helpers/pump_evasion_app.dart';

void main() {
  late FakeProfileStore store;

  setUp(() => store = FakeProfileStore(emptyProfile(testUser.id)));

  Future<void> tapText(WidgetTester tester, String text) async {
    // Scrolls first: on a small screen, the button can be below the content.
    await tester.ensureVisible(find.text(text));
    await tester.pumpAndSettle();
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  Future<void> answerUpToGender(WidgetTester tester) async {
    await tapText(tester, 'Commencer');
    await tester.enterText(find.byType(TextFormField), '  Alex ');
    await tapText(tester, 'Continuer');
    // The date picker opens on the latest allowed date: exactly 18 years old.
    await tapText(tester, 'Choisir la date');
    await tapText(tester, 'OK');
    await tapText(tester, 'Continuer');
    await tapText(tester, 'Femme');
  }

  testWidgets('a new user goes through every step and saves once', (
    tester,
  ) async {
    await pumpEvasionApp(tester, profiles: store);
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('Bienvenue !'), findsOneWidget);

    await answerUpToGender(tester);
    expect(store.savedChanges, isEmpty);
    await tapText(tester, 'Continuer');

    expect(store.savedChanges, hasLength(1));
    expect(store.savedChanges.single['display_name'], 'Alex');
    expect(store.savedChanges.single['gender'], Gender.woman);
    expect(store.savedChanges.single['birth_date'], isA<DateTime>());
    // Still no photo: the user stays in the onboarding, on the last step.
    expect(find.text("Plus qu'une étape : ta photo"), findsOneWidget);
    expect(find.byType(PostsMapScreen), findsNothing);
    // The saved answers cannot be reached again: changing the birth date
    // would silently use its only correction.
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('going back keeps the answers', (tester) async {
    await pumpEvasionApp(tester, profiles: store);
    await tapText(tester, 'Commencer');
    await tester.enterText(find.byType(TextFormField), 'Alex');
    await tapText(tester, 'Continuer');

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, 'Alex'), findsOneWidget);
  });

  testWidgets('a malformed name is refused before going on', (tester) async {
    await pumpEvasionApp(tester, profiles: store);
    await tapText(tester, 'Commencer');

    await tester.enterText(find.byType(TextFormField), '   ');
    await tapText(tester, 'Continuer');

    expect(find.text('Saisis ton prénom.'), findsOneWidget);
  });

  testWidgets('tapping the chosen gender again keeps it selected', (
    tester,
  ) async {
    await pumpEvasionApp(tester, profiles: store);
    await answerUpToGender(tester);

    // A second tap on a segmented button asks to deselect it.
    await tapText(tester, 'Femme');

    expect(tester.takeException(), isNull);
    await tapText(tester, 'Continuer');
    expect(store.savedChanges.single['gender'], Gender.woman);
  });

  testWidgets('once the profile is complete, the app opens', (tester) async {
    // A photo is already there, as after the photo step: saving the answers
    // completes the profile.
    store.profile = emptyProfile(testUser.id)
        .copyWith(avatarPath: '${testUser.id}/avatar.jpg');
    await pumpEvasionApp(tester, profiles: store);

    await answerUpToGender(tester);
    await tapText(tester, 'Continuer');

    expect(find.byType(PostsMapScreen), findsOneWidget);
  });

  testWidgets('a failed save shows its message and stays', (tester) async {
    store.saveFailure = const NetworkFailure();
    await pumpEvasionApp(tester, profiles: store);

    await answerUpToGender(tester);
    await tapText(tester, 'Continuer');

    expect(
      find.text('Pas de connexion internet. Réessaie dans un instant.'),
      findsOneWidget,
    );
    expect(find.text('Tu es…'), findsOneWidget);
  });

  testWidgets('a failed onboarding load shows its message in the page, once, '
      'and can be retried', (tester) async {
    store.progressFailure = const NetworkFailure();
    await pumpEvasionApp(tester, profiles: store);

    const message = 'Pas de connexion internet. Réessaie dans un instant.';
    expect(find.text(message), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    store.progressFailure = null;
    await tapText(tester, 'Réessayer');

    expect(find.text(message), findsNothing);
    expect(find.text('Bienvenue !'), findsOneWidget);
  });

  testWidgets('a failed profile load can be retried', (tester) async {
    store
      ..profile = completeProfile(testUser.id)
      ..fetchFailure = const NetworkFailure();
    await pumpEvasionApp(tester, profiles: store);
    expect(find.byType(StartupScreen), findsOneWidget);

    store.fetchFailure = null;
    await tapText(tester, 'Réessayer');

    expect(find.byType(PostsMapScreen), findsOneWidget);
  });
}
