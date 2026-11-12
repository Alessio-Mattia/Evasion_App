import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/core/services/photo_picker.dart';
import 'package:evasion/features/profile/domain/profile_page.dart';
import 'package:evasion/features/profile/presentation/editor/new_page_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/fake_photo_picker.dart';
import '../../../helpers/fake_profile_repositories.dart';
import '../../../helpers/pump_evasion_app.dart';

const jazz = ProfilePage.text(id: 'p1', position: 1, text: 'Fan de jazz');
const lake = ProfilePage.photo(
  id: 'p2',
  position: 2,
  imagePath: 'user-1/lake.jpg',
);

void main() {
  late FakeProfileStore store;
  late FakePhotoPicker picker;

  setUp(() {
    store = FakeProfileStore(completeProfile(testUser.id));
    picker = FakePhotoPicker();
  });

  /// Opens the profile tab. The pages shake in the edit mode, which never
  /// settles: tests ask for reduced motion unless [motion] is true.
  Future<void> openProfile(WidgetTester tester, {bool motion = false}) async {
    if (!motion) {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
    }
    await pumpEvasionApp(tester, profiles: store, photoPicker: picker);
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
  }

  Future<void> swipe(WidgetTester tester, {int times = 1}) async {
    for (var i = 0; i < times; i++) {
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();
    }
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.pumpAndSettle();
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  /// From an empty carousel, opens the editor of [template].
  Future<void> openEditor(WidgetTester tester, String template) async {
    await openProfile(tester);
    await swipe(tester);
    await tapText(tester, 'Ajouter une page');
    await tapText(tester, template);
  }

  FilledButton addButton(WidgetTester tester) =>
      tester.widget(find.widgetWithText(FilledButton, 'Ajouter la page'));

  group('adding a page', () {
    testWidgets('a text page, saved without surrounding spaces', (
      tester,
    ) async {
      await openEditor(tester, 'Texte');
      expect(addButton(tester).onPressed, isNull);

      await tester.enterText(find.byType(TextField), '  Fan de jazz  ');
      await tester.pump();
      await tapText(tester, 'Ajouter la page');

      expect(find.byType(NewPageScreen), findsNothing);
      expect(store.lastAddedContent, {'text': 'Fan de jazz'});
      expect(store.pageCalls, ['add 1']);
      expect(find.text('Fan de jazz'), findsOneWidget);
    });

    testWidgets('a text too long cannot be saved', (tester) async {
      await openEditor(tester, 'Texte');

      await tester.enterText(find.byType(TextField), 'a' * 301);
      await tester.pump();

      expect(find.text('300 caractères maximum.'), findsOneWidget);
      expect(addButton(tester).onPressed, isNull);
    });

    testWidgets('a portrait photo, without a caption key when empty', (
      tester,
    ) async {
      await openEditor(tester, 'Photo');
      await tapText(tester, 'Choisir dans ma galerie');

      expect(picker.requestedShapes, [PhotoShape.portrait]);
      await tapText(tester, 'Ajouter la page');

      expect(store.lastAddedContent, isEmpty);
      expect(store.pages.single, isA<PhotoPage>());
    });

    testWidgets('a photo with its caption', (tester) async {
      await openEditor(tester, 'Photo');
      await tapText(tester, 'Choisir dans ma galerie');

      // Below the photo: the list builds it once scrolled into view.
      await tester.scrollUntilVisible(find.byType(TextField), 100);
      await tester.enterText(find.byType(TextField), '  Au lac ');
      await tapText(tester, 'Ajouter la page');

      expect(store.lastAddedContent, {'caption': 'Au lac'});
    });

    testWidgets('interests, in the order chosen', (tester) async {
      await openEditor(tester, "Centres d'intérêt");
      expect(addButton(tester).onPressed, isNull);

      await tapText(tester, 'Voyages');
      await tapText(tester, 'Musique');
      await tapText(tester, 'Ajouter la page');

      expect(store.lastAddedContent, {
        'interests': ['travel', 'music'],
      });
    });

    testWidgets('a failed save shows why and stays on the editor', (
      tester,
    ) async {
      store.addFailure = const NetworkFailure();
      await openEditor(tester, 'Texte');

      await tester.enterText(find.byType(TextField), 'Fan de jazz');
      await tester.pump();
      await tapText(tester, 'Ajouter la page');

      expect(find.byType(NewPageScreen), findsOneWidget);
      expect(find.textContaining('Pas de connexion'), findsOneWidget);
    });

    testWidgets('no add card once the maximum is reached', (tester) async {
      store.pages = [
        for (var i = 1; i <= 5; i++)
          ProfilePage.text(id: 'p$i', position: i, text: 'Page $i'),
      ];

      await openProfile(tester);

      expect(find.bySemanticsLabel('Page 1 sur 6'), findsOneWidget);
      await swipe(tester, times: 6);
      expect(find.text('Ajouter une page'), findsNothing);
    });
  });

  group('edit mode', () {
    Future<void> startEditing(
      WidgetTester tester, {
      bool motion = false,
    }) async {
      await openProfile(tester, motion: motion);
      await swipe(tester);
      await tester.longPress(find.text('Fan de jazz'));
      await tester.pump();
    }

    testWidgets('opens with a long press on a page', (tester) async {
      store.pages = [jazz, lake];

      await startEditing(tester);
      await tester.pumpAndSettle();

      expect(find.text('Terminé'), findsOneWidget);
      expect(find.byTooltip('Paramètres'), findsNothing);
      expect(find.byTooltip('Supprimer cette page'), findsNWidgets(2));

      await tester.tap(find.text('Terminé'));
      await tester.pumpAndSettle();
      expect(find.byType(PageView), findsOneWidget);
      expect(find.byTooltip('Paramètres'), findsOneWidget);
    });

    testWidgets('not on the page built from the profile', (tester) async {
      store.pages = [jazz];
      await openProfile(tester);

      await tester.longPress(find.textContaining('Alex'));
      await tester.pumpAndSettle();

      expect(find.text('Terminé'), findsNothing);
    });

    testWidgets('pages shake, unless the phone reduces motion', (tester) async {
      store.pages = [jazz];

      await startEditing(tester, motion: true);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.hasScheduledFrame, isTrue);

      // Leaves the edit mode so that the test can end.
      await tester.tap(find.text('Terminé'));
      await tester.pumpAndSettle();
    });

    testWidgets('a page is deleted only once confirmed', (tester) async {
      store.pages = [jazz, lake];
      await startEditing(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Supprimer cette page').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(store.pageCalls, isEmpty);

      await tester.tap(find.byTooltip('Supprimer cette page').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();

      // The photo page moves up to close the gap.
      expect(store.pageCalls, ['delete p1', 'reorder p2']);
      expect(find.text('Fan de jazz'), findsNothing);
      expect(find.byTooltip('Supprimer cette page'), findsOneWidget);
    });

    testWidgets('deleting a photo page deletes its photo too', (tester) async {
      store.pages = [jazz, lake];
      await startEditing(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Supprimer cette page').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();

      expect(store.deletedPhotos, ['user-1/lake.jpg']);
    });

    testWidgets('closes once the last page is deleted', (tester) async {
      store.pages = [jazz];
      await startEditing(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Supprimer cette page'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();

      expect(find.text('Terminé'), findsNothing);
      expect(find.byTooltip('Paramètres'), findsOneWidget);
    });

    testWidgets('a failed deletion shows why and keeps the page', (
      tester,
    ) async {
      store
        ..pages = [jazz]
        ..deleteFailure = const NetworkFailure();
      await startEditing(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Supprimer cette page'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Pas de connexion'), findsOneWidget);
      expect(find.text('Fan de jazz'), findsOneWidget);
    });
  });
}
