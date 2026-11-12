import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/core/photos/photo_file.dart';
import 'package:evasion/core/services/photo_picker.dart';
import 'package:evasion/features/map/presentation/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/fake_photo_picker.dart';
import '../../../helpers/fake_profile_repositories.dart';
import '../../../helpers/pump_evasion_app.dart';

void main() {
  late FakeProfileStore store;
  late FakePhotoPicker picker;

  setUp(() {
    // Every answer saved, only the photo is missing.
    store = FakeProfileStore(
      completeProfile(testUser.id)
          .copyWith(avatarPath: null, isComplete: false),
    );
    picker = FakePhotoPicker();
  });

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.pumpAndSettle();
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  Future<void> start(WidgetTester tester) =>
      pumpEvasionApp(tester, profiles: store, photoPicker: picker);

  testWidgets('only the photo step remains, with both sources', (tester) async {
    await start(tester);

    expect(find.text("Plus qu'une étape : ta photo"), findsOneWidget);
    expect(find.text('Choisir dans ma galerie'), findsOneWidget);
    expect(find.text('Prendre une photo'), findsOneWidget);
  });

  testWidgets('a chosen photo is previewed, then saved, and the app opens', (
    tester,
  ) async {
    await start(tester);

    await tapText(tester, 'Choisir dans ma galerie');
    expect(picker.requestedSources, [PhotoSource.gallery]);
    expect(find.byType(CircleAvatar), findsOneWidget);
    expect(store.savedPhotoFormats, isEmpty);

    await tapText(tester, 'Valider cette photo');

    expect(store.savedPhotoFormats, [PhotoFormat.png]);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('the camera is offered too', (tester) async {
    await start(tester);

    await tapText(tester, 'Prendre une photo');

    expect(picker.requestedSources, [PhotoSource.camera]);
    expect(find.byType(CircleAvatar), findsOneWidget);
  });

  testWidgets('another photo can be chosen before confirming', (tester) async {
    await start(tester);
    await tapText(tester, 'Choisir dans ma galerie');

    await tapText(tester, 'Choisir une autre photo');

    expect(find.byType(CircleAvatar), findsNothing);
    expect(find.text('Choisir dans ma galerie'), findsOneWidget);
  });

  testWidgets('cancelling the picker changes nothing', (tester) async {
    picker.result = null;
    await start(tester);

    await tapText(tester, 'Choisir dans ma galerie');

    expect(find.byType(CircleAvatar), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('an unsupported format is refused with its message', (
    tester,
  ) async {
    picker.result = heicBytes;
    await start(tester);

    await tapText(tester, 'Choisir dans ma galerie');

    expect(
      find.text(
        "Ce format de photo n'est pas pris en charge. Choisis-en une autre.",
      ),
      findsOneWidget,
    );
    expect(find.byType(CircleAvatar), findsNothing);
  });

  testWidgets('refused access explains where to allow it', (tester) async {
    picker.error = const PhotoAccessDenied();
    await start(tester);

    await tapText(tester, 'Prendre une photo');

    expect(find.textContaining('réglages du téléphone'), findsOneWidget);
  });

  testWidgets('a failed upload shows its message and keeps the photo', (
    tester,
  ) async {
    store.saveFailure = const NetworkFailure();
    await start(tester);
    await tapText(tester, 'Choisir dans ma galerie');

    await tapText(tester, 'Valider cette photo');

    expect(
      find.text('Pas de connexion internet. Réessaie dans un instant.'),
      findsOneWidget,
    );
    expect(find.byType(CircleAvatar), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });
}
