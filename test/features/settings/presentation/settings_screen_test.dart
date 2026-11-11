import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/core/models/gender.dart';
import 'package:evasion/core/models/location_mode.dart';
import 'package:evasion/features/settings/presentation/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_settings_repository.dart';
import '../../../helpers/pump_evasion_app.dart';

void main() {
  late FakeSettingsRepository settings;

  setUp(() => settings = FakeSettingsRepository());

  Future<void> openSettings(WidgetTester tester) async {
    await pumpEvasionApp(tester, settings: settings);
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Paramètres'));
    await tester.pumpAndSettle();
  }

  /// Scrolls until [text] is fully on screen: the list is longer than the
  /// test window, and lazily builds what is not visible.
  Future<void> showText(WidgetTester tester, String text) async {
    await tester.scrollUntilVisible(find.text(text), 200);
    await tester.ensureVisible(find.text(text));
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await showText(tester, text);
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  testWidgets('opens from the profile tab and shows the saved settings', (
    tester,
  ) async {
    await openSettings(tester);

    expect(find.byType(SettingsScreen), findsOneWidget);
    await showText(tester, '100 m');
    await showText(tester, '18 ans et plus');

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsNothing);
  });

  testWidgets('choosing to be visible saves it', (tester) async {
    await openSettings(tester);

    await tapText(tester, "Visible quand l'app est ouverte");

    expect(settings.saved.single.locationMode, LocationMode.foreground);
  });

  testWidgets('background sharing cannot be chosen yet', (tester) async {
    await openSettings(tester);

    await tapText(tester, 'Visible en arrière-plan');

    expect(settings.saved, isEmpty);
  });

  testWidgets('unselecting a gender saves the others', (tester) async {
    await openSettings(tester);

    await tapText(tester, 'Homme');

    expect(settings.saved.single.prefGenders, [Gender.woman, Gender.other]);
  });

  testWidgets('the last gender cannot be unselected', (tester) async {
    settings.settings = defaultSettings.copyWith(prefGenders: [Gender.woman]);
    await openSettings(tester);

    await tapText(tester, 'Femme');

    expect(settings.saved, isEmpty);
    expect(find.text('Choisis au moins un genre.'), findsOneWidget);
  });

  testWidgets('a failed save shows its message and the saved value', (
    tester,
  ) async {
    settings.saveFailure = const NetworkFailure();
    await openSettings(tester);

    await tapText(tester, "Visible quand l'app est ouverte");

    expect(
      find.text('Pas de connexion internet. Réessaie dans un instant.'),
      findsOneWidget,
    );
    final invisible = tester.widget<RadioListTile<LocationMode>>(
      find.widgetWithText(RadioListTile<LocationMode>, 'Invisible'),
    );
    expect(
      RadioGroup.maybeOf<LocationMode>(tester.element(find.byWidget(invisible)))
          ?.groupValue,
      LocationMode.invisible,
    );
  });

  testWidgets('radii from one kilometer are shown in km, with a comma', (
    tester,
  ) async {
    settings.settings = defaultSettings.copyWith(detectionRadiusM: 1500);
    await openSettings(tester);

    await showText(tester, '1,5 km');
  });
}
