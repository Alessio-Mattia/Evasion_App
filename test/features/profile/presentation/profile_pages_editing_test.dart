import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/core/services/photo_picker.dart';
import 'package:evasion/features/profile/domain/profile_page.dart';
import 'package:evasion/features/profile/presentation/editor/edit_page_screen.dart';
import 'package:evasion/features/profile/presentation/editor/new_page_screen.dart';
import 'package:flutter/gestures.dart';
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

  group('editing and moving pages', () {
    /// Opens the edit mode on the text page.
    Future<void> startEditing(WidgetTester tester) async {
      await openProfile(tester);
      await swipe(tester);
      await tester.longPress(find.text('Fan de jazz'));
      await tester.pumpAndSettle();
    }

    testWidgets('a tap opens the editor filled with the page', (tester) async {
      store.pages = [jazz, lake];
      await startEditing(tester);

      await tester.tap(find.text('Fan de jazz'));
      await tester.pumpAndSettle();

      expect(find.byType(EditPageScreen), findsOneWidget);
      expect(find.text('Modifier la page'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Fan de jazz'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Fan de blues');
      await tester.pump();
      await tapText(tester, 'Enregistrer');

      expect(find.byType(EditPageScreen), findsNothing);
      expect(store.pageCalls, ['update p1']);
      expect(find.text('Fan de blues'), findsOneWidget);
    });

    testWidgets('a photo page keeps its photo when only the caption changes', (
      tester,
    ) async {
      store.pages = [jazz, lake];
      await startEditing(tester);

      await tester.tap(find.bySemanticsLabel('Modifier cette page').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byType(TextField), 100);
      await tester.enterText(find.byType(TextField), 'Au lac');
      await tester.pump();
      await tapText(tester, 'Enregistrer');

      expect(store.lastAddedContent, {'caption': 'Au lac'});
      expect(
        store.pages.last,
        isA<PhotoPage>().having(
          (page) => page.imagePath,
          'imagePath',
          'user-1/lake.jpg',
        ),
      );
      expect(store.deletedPhotos, isEmpty);
      expect(picker.requestedSources, isEmpty);
    });

    testWidgets('holding a page and moving it changes the order', (
      tester,
    ) async {
      store.pages = [jazz, lake];
      await startEditing(tester);

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Fan de jazz')),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
      for (var i = 0; i < 4; i++) {
        await gesture.moveBy(const Offset(40, 0));
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(store.pageCalls, ['reorder p2,p1']);
      expect(
        {for (final page in store.pages) page.id: page.position},
        {'p2': 1, 'p1': 2},
      );
      // Still in the edit mode, ready for another change.
      expect(find.text('Terminé'), findsOneWidget);
    });

    testWidgets('a failed move shows why and puts the pages back', (
      tester,
    ) async {
      store
        ..pages = [jazz, lake]
        ..reorderFailure = const NetworkFailure();
      await startEditing(tester);

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Fan de jazz')),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
      for (var i = 0; i < 4; i++) {
        await gesture.moveBy(const Offset(40, 0));
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.textContaining('Pas de connexion'), findsOneWidget);
      final textLeft = tester.getCenter(find.text('Fan de jazz')).dx;
      final photoLeft = tester
          .getCenter(find.bySemanticsLabel('Modifier cette page').last)
          .dx;
      expect(textLeft, lessThan(photoLeft));
    });
  });

  testWidgets('a move never flashes the carousel nor the previous order', (
    tester,
  ) async {
    // As slow as a real server, so that every step shows on screen.
    store = _SlowStore(completeProfile(testUser.id))..pages = [jazz, lake];
    await openProfile(tester);
    await swipe(tester);
    await tester.longPress(find.text('Fan de jazz'));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Fan de jazz')),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    for (var i = 0; i < 4; i++) {
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
    }
    await gesture.up();

    // Every frame until everything is saved and reloaded.
    for (var frame = 0; frame < 40; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byType(PageView), findsNothing, reason: 'frame $frame');
      expect(
        tester.getCenter(find.text('Fan de jazz')).dx,
        greaterThan(
          tester
              .getCenter(find.bySemanticsLabel('Modifier cette page').first)
              .dx,
        ),
        reason: 'frame $frame',
      );
    }
    await tester.pumpAndSettle();
    expect(store.pageCalls, ['reorder p2,p1']);
  });
}

/// Answers after a delay, like a real server.
class _SlowStore extends FakeProfileStore {
  _SlowStore(super.profile);

  static const _delay = Duration(milliseconds: 200);

  @override
  Future<List<ProfilePage>> fetchOwnPages(String userId) async {
    await Future<void>.delayed(_delay);
    return super.fetchOwnPages(userId);
  }

  @override
  Future<void> reorderPages(List<String> pageIds) async {
    await Future<void>.delayed(_delay);
    return super.reorderPages(pageIds);
  }
}
