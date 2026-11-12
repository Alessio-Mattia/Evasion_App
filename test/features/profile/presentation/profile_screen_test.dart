import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/core/models/interest.dart';
import 'package:evasion/core/storage/storage_images.dart';
import 'package:evasion/core/utils/server_date.dart';
import 'package:evasion/features/profile/domain/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/fake_profile_repositories.dart';
import '../../../helpers/fake_storage_images.dart';
import '../../../helpers/pump_evasion_app.dart';

void main() {
  late FakeProfileStore profiles;
  late FakeStorageImages images;

  setUp(() {
    profiles = FakeProfileStore(completeProfile(testUser.id));
    images = FakeStorageImages();
  });

  Future<void> openProfile(WidgetTester tester) async {
    await pumpEvasionApp(tester, profiles: profiles, storageImages: images);
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
  }

  /// The carousel is taller than the test window, and the list only builds
  /// what is near the screen.
  Future<void> showText(WidgetTester tester, String text) async {
    await tester.scrollUntilVisible(
      find.text(text),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> swipeToNextPage(WidgetTester tester) async {
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
  }

  testWidgets('shows the page built from the profile', (tester) async {
    profiles.profile = completeProfile(testUser.id).copyWith(
      occupation: 'Étudiante en biologie',
      university: 'Université de Genève',
      isStudentVerified: true,
    );
    final age = ageOn(profiles.profile.birthDate!, serverToday());

    await openProfile(tester);

    expect(find.text('Alex, $age'), findsOneWidget);
    expect(find.text('Étudiante en biologie'), findsOneWidget);
    expect(find.text('Université de Genève'), findsOneWidget);
    expect(find.text('Étudiant·e'), findsOneWidget);
    expect(images.requested, [
      (StorageBucket.avatars, '${testUser.id}/avatar.jpg'),
    ]);
  });

  testWidgets('hides what the profile does not have', (tester) async {
    await openProfile(tester);

    expect(find.text('Étudiant·e'), findsNothing);
    expect(find.text('À propos'), findsNothing);
    // Without free pages, there is nothing to edit yet.
    expect(find.textContaining('Appuie longuement'), findsNothing);
  });

  testWidgets('shows the bio below the carousel', (tester) async {
    profiles.profile = completeProfile(testUser.id)
        .copyWith(bio: 'Toujours partant pour un café.');

    await openProfile(tester);
    await showText(tester, 'Toujours partant pour un café.');

    expect(find.text('À propos'), findsOneWidget);
    expect(find.text('Toujours partant pour un café.'), findsOneWidget);
  });

  testWidgets('swipes through the pages in their order', (tester) async {
    profiles.pages = [
      const ProfilePage.text(id: 'p1', position: 1, text: 'Fan de jazz'),
      const ProfilePage.photo(
        id: 'p2',
        position: 2,
        imagePath: 'user-1/lake.jpg',
        caption: 'Au bord du lac',
      ),
      const ProfilePage.interests(
        id: 'p3',
        position: 3,
        interests: [Interest.music, Interest.travel],
      ),
    ];

    await openProfile(tester);
    expect(find.bySemanticsLabel('Page 1 sur 5'), findsOneWidget);

    await swipeToNextPage(tester);
    expect(find.text('Fan de jazz'), findsOneWidget);
    expect(find.bySemanticsLabel('Page 2 sur 5'), findsOneWidget);

    await swipeToNextPage(tester);
    expect(find.text('Au bord du lac'), findsOneWidget);
    expect(images.requested.last, (
      StorageBucket.profilePhotos,
      'user-1/lake.jpg',
    ));

    await swipeToNextPage(tester);
    expect(find.text('Musique'), findsOneWidget);
    expect(find.text('Voyages'), findsOneWidget);
    expect(find.bySemanticsLabel('Page 4 sur 5'), findsOneWidget);

    // Then the card to add a page, the last one: the carousel does not loop.
    await swipeToNextPage(tester);
    expect(find.text('Ajouter une page'), findsOneWidget);
    await swipeToNextPage(tester);
    expect(find.bySemanticsLabel('Page 5 sur 5'), findsOneWidget);
  });

  testWidgets('still shows the profile when the pages fail to load', (
    tester,
  ) async {
    profiles.pagesFailure = const NetworkFailure();

    await openProfile(tester);

    expect(find.textContaining('Alex'), findsOneWidget);
  });

  testWidgets('a photo that cannot be loaded leaves the text readable', (
    tester,
  ) async {
    images.failure = const NetworkFailure();

    await openProfile(tester);

    expect(find.textContaining('Alex'), findsOneWidget);
    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
  });

  testWidgets('pulling down reloads the profile and the pages', (tester) async {
    await openProfile(tester);
    profiles
      ..profile = completeProfile(testUser.id).copyWith(bio: 'Nouvelle bio')
      ..pages = [const ProfilePage.text(id: 'p1', position: 1, text: 'Salut')];

    await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    await showText(tester, 'Nouvelle bio');

    expect(find.text('Nouvelle bio'), findsOneWidget);
    expect(find.bySemanticsLabel('Page 1 sur 3'), findsOneWidget);
  });

  testWidgets('keeps the settings button', (tester) async {
    await openProfile(tester);

    expect(find.byTooltip('Paramètres'), findsOneWidget);
  });
}
