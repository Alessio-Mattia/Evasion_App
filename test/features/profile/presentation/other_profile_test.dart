import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/core/models/location_mode.dart';
import 'package:evasion/features/encounters/presentation/crossing_tile.dart';
import 'package:evasion/features/profile/domain/profile_page.dart';
import 'package:evasion/features/profile/domain/public_profile.dart';
import 'package:evasion/features/profile/presentation/carousel/add_page_card.dart';
import 'package:evasion/features/profile/presentation/carousel/main_page_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/fake_encounters_repository.dart';
import '../../../helpers/fake_profile_repositories.dart';
import '../../../helpers/fake_settings_repository.dart';
import '../../../helpers/pump_evasion_app.dart';

void main() {
  late FakeEncountersRepository encounters;
  late FakeProfileStore profiles;

  // The person of testCrossing(id: 'c1').
  const noah = PublicProfile(
    id: 'user-c1',
    displayName: 'Noah',
    age: 23,
    isStudentVerified: true,
    occupation: 'Étudiant en biologie',
    bio: 'Toujours partant pour un café.',
  );

  setUp(() {
    final now = DateTime.now();
    encounters = FakeEncountersRepository()
      ..crossings = [
        testCrossing(
          id: 'c1',
          crossedAt: DateTime(now.year, now.month, now.day, 0, 30),
        ),
      ];
    profiles = FakeProfileStore(completeProfile(testUser.id))
      ..others[noah.id] = noah
      ..othersPages[noah.id] = [
        const ProfilePage.text(id: 'p1', position: 1, text: 'Salut !'),
      ];
  });

  Future<void> openCrossingProfile(WidgetTester tester) async {
    // A phone in portrait, so that what is under the carousel is built too.
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await pumpEvasionApp(
      tester,
      encounters: encounters,
      profiles: profiles,
      // Visible: no notice about being invisible.
      settings: FakeSettingsRepository(
        defaultSettings.copyWith(locationMode: LocationMode.foreground),
      ),
    );
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Croisements'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CrossingTile));
    await tester.pumpAndSettle();
  }

  testWidgets('a crossing opens the profile of the person, read only', (
    tester,
  ) async {
    await openCrossingProfile(tester);

    expect(find.byType(MainPageCard), findsOneWidget);
    expect(find.text('Noah, 23'), findsOneWidget);
    expect(find.text('Étudiant en biologie'), findsOneWidget);
    expect(find.text('Salut !'), findsOneWidget);
    expect(find.text('Toujours partant pour un café.'), findsOneWidget);
    expect(
      find.text("Vos chemins se sont croisés aujourd'hui, vers 0 h 30."),
      findsOneWidget,
    );
    // Still in the crossings tab.
    expect(find.byType(NavigationBar), findsOneWidget);

    // Nothing to add or edit on someone else's profile.
    expect(find.byType(AddPageCard), findsNothing);
    await tester.longPress(find.byType(MainPageCard));
    await tester.pumpAndSettle();
    expect(find.text('Terminé'), findsNothing);
  });

  testWidgets('going back shows the crossings again', (tester) async {
    await openCrossingProfile(tester);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(CrossingTile), findsOneWidget);
    expect(find.byType(MainPageCard), findsNothing);
  });

  testWidgets('an earlier crossing is recalled with its day', (tester) async {
    final now = DateTime.now();
    encounters.crossings = [
      testCrossing(
        id: 'c1',
        crossedAt: DateTime(now.year, now.month, now.day - 2, 18),
      ),
    ];

    await openCrossingProfile(tester);

    final note = find.textContaining('Vos chemins se sont croisés ');
    expect(note, findsOneWidget);
    final text = tester.widget<Text>(note).data!;
    expect(text, endsWith(', vers 18 h.'));
    expect(text, isNot(contains("aujourd'hui")));
  });

  testWidgets('a profile that cannot be seen says so, without a reason', (
    tester,
  ) async {
    profiles.others.clear();

    await openCrossingProfile(tester);

    expect(find.text("Ce profil n'est plus disponible."), findsOneWidget);
    expect(find.byType(MainPageCard), findsNothing);
    expect(find.text('Réessayer'), findsNothing);
  });

  testWidgets('a failure says why and can be retried', (tester) async {
    profiles.othersFailure = const NetworkFailure();

    await openCrossingProfile(tester);
    expect(find.byType(MainPageCard), findsNothing);
    expect(find.textContaining('connexion'), findsOneWidget);

    profiles.othersFailure = null;
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();

    expect(find.text('Noah, 23'), findsOneWidget);
  });
}
