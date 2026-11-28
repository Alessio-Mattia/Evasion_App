import 'package:evasion/core/config/business_rules.dart';
import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/core/models/location_mode.dart';
import 'package:evasion/features/encounters/presentation/crossing_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_encounters_repository.dart';
import '../../../helpers/fake_settings_repository.dart';
import '../../../helpers/pump_evasion_app.dart';

void main() {
  late FakeEncountersRepository encounters;
  late FakeSettingsRepository settings;

  setUp(() {
    encounters = FakeEncountersRepository();
    // Visible: no notice about being invisible.
    settings = FakeSettingsRepository(
      defaultSettings.copyWith(locationMode: LocationMode.foreground),
    );
  });

  Future<void> openCrossings(WidgetTester tester) async {
    await pumpEvasionApp(tester, encounters: encounters, settings: settings);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Croisements'),
      ),
    );
    await tester.pumpAndSettle();
  }

  test('times are shown in hours and half hours', () {
    expect(crossingTime(DateTime(2026, 11, 28, 14)), '14 h');
    expect(crossingTime(DateTime(2026, 11, 28, 14, 30)), '14 h 30');
    expect(crossingTime(DateTime(2026, 11, 28, 9, 30)), '9 h 30');
  });

  testWidgets('shows today, then this week, with rounded times', (
    tester,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 0, 30);
    final earlier = today.subtract(const Duration(days: 2));
    encounters.crossings = [
      testCrossing(id: 'today', name: 'Léa', crossedAt: today),
      testCrossing(id: 'earlier', name: 'Sam', crossedAt: earlier),
    ];

    await openCrossings(tester);

    expect(find.text('AUJOURD’HUI'.replaceAll('’', "'")), findsOneWidget);
    expect(find.text('CETTE SEMAINE'), findsOneWidget);
    expect(find.text('Léa, 23'), findsOneWidget);
    expect(find.text('Vers 0 h 30'), findsOneWidget);
    expect(find.textContaining(', vers 0 h 30'), findsOneWidget);
    // The student badge of the test crossings.
    expect(find.byIcon(Icons.school_outlined), findsNWidgets(2));
  });

  testWidgets('a new crossing shows up after the next report', (
    tester,
  ) async {
    await openCrossings(tester);
    expect(find.byType(CrossingTile), findsNothing);

    // The server makes a crossing with the next position sent.
    encounters.crossings = [testCrossing(name: 'Léa')];
    await tester.pump(BusinessRules.locationReportInterval);
    await tester.pumpAndSettle();

    expect(find.text('Léa, 23'), findsOneWidget);
  });

  testWidgets('says when there is nobody yet', (tester) async {
    await openCrossings(tester);

    expect(find.textContaining('Aucun croisement cette semaine'), findsOne);
    expect(find.textContaining('Tu es invisible'), findsNothing);
  });

  testWidgets('an invisible user is told why, with a way to change it', (
    tester,
  ) async {
    settings = FakeSettingsRepository();

    await openCrossings(tester);
    expect(find.textContaining('Tu es invisible'), findsOneWidget);

    await tester.tap(find.text('Devenir visible'));
    await tester.pumpAndSettle();
    expect(find.text('Paramètres'), findsOneWidget);
  });

  testWidgets('a failure says why', (tester) async {
    encounters.failure = const NetworkFailure();

    await openCrossings(tester);

    expect(find.byType(CrossingTile), findsNothing);
    expect(find.textContaining('connexion'), findsOneWidget);
  });
}
