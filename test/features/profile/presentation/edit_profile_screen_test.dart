import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/core/services/photo_picker.dart';
import 'package:evasion/features/profile/presentation/carousel/main_page_card.dart';
import 'package:evasion/features/profile/presentation/edit/page_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/fake_photo_picker.dart';
import '../../../helpers/fake_profile_repositories.dart';
import '../../../helpers/pump_evasion_app.dart';

void main() {
  late FakeProfileStore profiles;
  late FakePhotoPicker picker;

  setUp(() {
    profiles = FakeProfileStore(
      completeProfile(testUser.id).copyWith(occupation: 'Biologie'),
    );
    picker = FakePhotoPicker();
  });

  /// Long press on the carousel, then a tap on the first page. The pages
  /// shake in the edit mode, which never settles: reduced motion is asked.
  Future<void> openEditScreen(WidgetTester tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpEvasionApp(tester, profiles: profiles, photoPicker: picker);
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    await tester.longPress(find.byType(MainPageCard));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PageThumbnail).first);
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextField, label);

  Finder saveButton() => find.widgetWithText(FilledButton, 'Enregistrer');

  bool canSave(WidgetTester tester) =>
      tester.widget<FilledButton>(saveButton()).onPressed != null;

  Future<void> show(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('opens with the current texts, nothing to save yet', (
    tester,
  ) async {
    await openEditScreen(tester);

    expect(find.text('Modifier le profil'), findsOneWidget);
    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('Biologie'), findsOneWidget);
    expect(canSave(tester), isFalse);
  });

  testWidgets('saves the texts and goes back to the profile', (tester) async {
    await openEditScreen(tester);

    await tester.enterText(field('Prénom'), ' Sam ');
    await tester.enterText(field('Activité (facultatif)'), '');
    await tester.pump();
    await tester.tap(saveButton());
    await tester.pumpAndSettle();

    expect(profiles.profileCalls, ['details']);
    expect(profiles.profile.displayName, 'Sam');
    expect(profiles.profile.occupation, isNull);
    // Back to the edit mode, as after editing a page.
    expect(find.text('Modifier le profil'), findsNothing);
    await tester.tap(find.text('Terminé'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sam,'), findsOneWidget);
  });

  testWidgets('a blank name cannot be saved', (tester) async {
    await openEditScreen(tester);

    await tester.enterText(field('Prénom'), '   ');
    await tester.pump();

    expect(find.text('Saisis ton prénom.'), findsOneWidget);
    expect(canSave(tester), isFalse);
  });

  testWidgets('a text over its limit cannot be saved', (tester) async {
    await openEditScreen(tester);

    await tester.enterText(field('Activité (facultatif)'), 'a' * 101);
    await tester.pump();

    expect(find.text('100 caractères maximum.'), findsOneWidget);
    expect(canSave(tester), isFalse);
  });

  testWidgets('a failed save stays on the screen and says why', (tester) async {
    await openEditScreen(tester);
    profiles.saveFailure = const NetworkFailure();

    await tester.enterText(field('Prénom'), 'Sam');
    await tester.pump();
    await tester.tap(saveButton());
    await tester.pumpAndSettle();

    expect(find.text('Modifier le profil'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  group('leaving with unsaved texts', () {
    Future<void> editThenGoBack(WidgetTester tester) async {
      await openEditScreen(tester);
      await tester.enterText(field('Prénom'), 'Sam');
      await tester.pump();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
    }

    testWidgets('asks first, and can stay', (tester) async {
      await editThenGoBack(tester);

      expect(find.text('Abandonner tes modifications ?'), findsOneWidget);
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      expect(find.text('Modifier le profil'), findsOneWidget);
      expect(find.text('Sam'), findsOneWidget);
    });

    testWidgets('leaves without saving once confirmed', (tester) async {
      await editThenGoBack(tester);

      await tester.tap(find.text('Abandonner'));
      await tester.pumpAndSettle();

      expect(find.text('Modifier le profil'), findsNothing);
      expect(profiles.profileCalls, isEmpty);
    });
  });

  testWidgets('the system back gesture also asks first', (tester) async {
    await openEditScreen(tester);
    await tester.enterText(field('Prénom'), 'Sam');
    await tester.pump();

    // What Android sends on a back gesture.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Abandonner tes modifications ?'), findsOneWidget);
  });

  testWidgets('without changes, going back asks nothing', (tester) async {
    await openEditScreen(tester);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Modifier le profil'), findsNothing);
  });

  testWidgets('changes the photo at once, cropped round', (tester) async {
    await openEditScreen(tester);

    await tester.tap(find.text('Changer de photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choisir dans ma galerie'));
    await tester.pumpAndSettle();

    expect(picker.requestedSources, [PhotoSource.gallery]);
    expect(picker.requestedShapes, [PhotoShape.round]);
    expect(profiles.profileCalls, ['avatar']);
    // Saved apart from the texts: nothing left to save.
    expect(canSave(tester), isFalse);
  });

  group('birth date', () {
    Finder correctButton() => find.widgetWithText(TextButton, 'Corriger');

    Future<void> pickThe15th(WidgetTester tester) async {
      await show(tester, correctButton());
      await tester.tap(correctButton());
      await tester.pumpAndSettle();
      // The calendar opens on the current birth date, January 2000.
      await tester.tap(find.text('15'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    }

    testWidgets('is corrected once, after a confirmation', (tester) async {
      await openEditScreen(tester);

      await pickThe15th(tester);
      expect(find.text('Corriger ta date de naissance ?'), findsOneWidget);
      await tester.tap(correctButton().last);
      await tester.pumpAndSettle();

      expect(profiles.profileCalls, ['birth date 2000-01-15']);
      expect(find.textContaining('Déjà corrigée une fois'), findsOneWidget);
      expect(correctButton(), findsNothing);
    });

    testWidgets('cancelling the confirmation changes nothing', (tester) async {
      await openEditScreen(tester);

      await pickThe15th(tester);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(profiles.profileCalls, isEmpty);
      expect(correctButton(), findsOneWidget);
    });

    testWidgets('cannot be corrected a second time', (tester) async {
      profiles.profile = profiles.profile.copyWith(birthDateCorrected: true);

      await openEditScreen(tester);
      await show(tester, find.textContaining('Déjà corrigée une fois'));

      expect(correctButton(), findsNothing);
    });
  });
}
