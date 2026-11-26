import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/core/services/location_service.dart';
import 'package:evasion/core/services/photo_picker.dart';
import 'package:evasion/features/posts/domain/post.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_location_service.dart';
import '../../../helpers/fake_photo_picker.dart';
import '../../../helpers/fake_posts_repository.dart';
import '../../../helpers/pump_evasion_app.dart';

void main() {
  late FakePostsRepository posts;
  late FakeLocationService location;
  late FakePhotoPicker picker;

  setUp(() {
    posts = FakePostsRepository();
    location = FakeLocationService();
    picker = FakePhotoPicker();
  });

  Future<void> openForm(WidgetTester tester) async {
    await pumpEvasionApp(
      tester,
      posts: posts,
      location: location,
      photoPicker: picker,
    );
    await tester.tap(find.byTooltip('Créer un post'));
    await tester.pumpAndSettle();
  }

  /// The test window is smaller than a phone: the form scrolls, and only
  /// builds what is near the screen.
  Future<void> show(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) await show(tester, finder);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> choosePhoto(WidgetTester tester) async {
    await tapVisible(tester, find.text('Ajouter une photo'));
    await tapVisible(tester, find.text('Choisir dans ma galerie'));
  }

  Finder publishButton() => find.widgetWithText(FilledButton, 'Publier');

  bool canPublish(WidgetTester tester) =>
      tester.widget<FilledButton>(publishButton()).onPressed != null;

  testWidgets('needs a photo, then publishes and goes home', (tester) async {
    await openForm(tester);
    expect(canPublish(tester), isFalse);

    await choosePhoto(tester);
    // Portrait 4:5, like the carousel pages.
    expect(picker.requestedShapes, [PhotoShape.portrait]);
    expect(canPublish(tester), isTrue);

    await tester.enterText(find.byType(TextField), 'Soleil sur les quais');
    await tapVisible(tester, publishButton());

    final (draft, position) = posts.createdDrafts.single;
    expect(position, testPosition);
    expect(draft.trimmedCaption, 'Soleil sur les quais');
    expect(draft.precision, PostPrecision.fuzzy);
    expect(draft.lifetime, const Duration(hours: 24));
    expect(find.text('Ton post est publié.'), findsOneWidget);
    expect(find.text('Nouveau post'), findsNothing);
  });

  testWidgets('the exact point asks first', (tester) async {
    await openForm(tester);
    await choosePhoto(tester);

    await tapVisible(tester, find.text('Point exact'));
    expect(find.text("Montrer l'endroit exact ?"), findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(find.textContaining('une zone d'), findsOneWidget);

    await tapVisible(tester, find.text('Point exact'));
    await tester.tap(find.text("Montrer l'endroit exact"));
    await tester.pumpAndSettle();
    expect(
      find.text("Les autres voient l'endroit exact de ton post."),
      findsOne,
    );

    await tapVisible(tester, publishButton());
    expect(posts.createdDrafts.single.$1.precision, PostPrecision.exact);
  });

  testWidgets('the lifetime can be chosen', (tester) async {
    await openForm(tester);
    await choosePhoto(tester);

    await tapVisible(tester, find.text('6 h'));
    await tapVisible(tester, publishButton());

    expect(posts.createdDrafts.single.$1.lifetime, const Duration(hours: 6));
  });

  testWidgets('friends cannot be chosen yet', (tester) async {
    await openForm(tester);
    await show(tester, find.text("Liste d'amis"));

    for (final label in ['Amis', "Liste d'amis"]) {
      final chip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, label),
      );
      expect(chip.onSelected, isNull, reason: label);
    }
  });

  testWidgets('a location refused for good leads to the settings', (
    tester,
  ) async {
    location.error = const LocationAccessDenied(permanently: true);
    await openForm(tester);
    await choosePhoto(tester);

    await tapVisible(tester, publishButton());

    expect(posts.createdDrafts, isEmpty);
    expect(find.textContaining('Autorise la localisation'), findsOneWidget);
    await tester.tap(find.text('Réglages'));
    await tester.pumpAndSettle();
    expect(location.settingsOpened, 1);
    // The form is kept, to publish once allowed.
    expect(find.text('Nouveau post'), findsOneWidget);
  });

  testWidgets('a full quota says why and keeps the form', (tester) async {
    posts.failure = const LimitReachedFailure();
    await openForm(tester);
    await choosePhoto(tester);

    await tapVisible(tester, publishButton());

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Nouveau post'), findsOneWidget);
    expect(canPublish(tester), isTrue);
  });
}
