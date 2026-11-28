import 'package:evasion/core/config/business_rules.dart';
import 'package:evasion/core/services/location_service.dart';
import 'package:evasion/features/encounters/data/supabase_encounters_repository.dart';
import 'package:evasion/features/encounters/presentation/location_reporting.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_encounters_repository.dart';
import '../../../helpers/fake_location_service.dart';

void main() {
  late FakeLocationService location;
  late FakeEncountersRepository encounters;
  late ProviderContainer container;

  setUp(() {
    location = FakeLocationService();
    encounters = FakeEncountersRepository();
    container = ProviderContainer(
      overrides: [
        locationServiceProvider.overrideWithValue(location),
        encountersRepositoryProvider.overrideWithValue(encounters),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<void> pumpReporter(WidgetTester tester, {required bool sharing}) =>
      tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: LocationReporter(isSharing: sharing, child: const SizedBox()),
        ),
      );

  /// Lets the reports in flight finish.
  Future<void> settle(WidgetTester tester) => tester.pump(Duration.zero);

  testWidgets('a visible user sends at once, then every interval', (
    tester,
  ) async {
    await pumpReporter(tester, sharing: true);
    await settle(tester);
    expect(encounters.reports, hasLength(1));

    await tester.pump(BusinessRules.locationReportInterval);
    await settle(tester);
    expect(encounters.reports, hasLength(2));
    expect(encounters.reports.last.position, testPosition);

    // Ends the timer with the widget.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an invisible user sends nothing', (tester) async {
    await pumpReporter(tester, sharing: false);
    await tester.pump(BusinessRules.locationReportInterval * 3);

    expect(location.reads, 0);
    expect(encounters.reports, isEmpty);
  });

  testWidgets('turning invisible stops the reports', (tester) async {
    await pumpReporter(tester, sharing: true);
    await settle(tester);

    await pumpReporter(tester, sharing: false);
    await tester.pump(BusinessRules.locationReportInterval * 3);

    expect(encounters.reports, hasLength(1));
  });

  testWidgets('nothing leaves the phone in the background', (tester) async {
    await pumpReporter(tester, sharing: true);
    await settle(tester);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(BusinessRules.locationReportInterval * 3);
    expect(encounters.reports, hasLength(1));

    // Back on screen: a report at once.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);
    expect(encounters.reports, hasLength(2));

    await tester.pumpWidget(const SizedBox());
  });

  group('approximate location', () {
    Future<void> report() =>
        container.read(locationReportingControllerProvider.notifier).report();

    test(
      'a few imprecise positions in a row ask for the precise one',
      () async {
        location.accuracyMeters = BusinessRules.locationMaxAccuracyMeters + 1;

        for (var i = 1; i < BusinessRules.impreciseReportsBeforeNotice; i++) {
          await report();
        }
        expect(container.read(locationReportingControllerProvider), isFalse);

        await report();
        expect(container.read(locationReportingControllerProvider), isTrue);
        expect(encounters.reports, isEmpty);

        location.accuracyMeters = 10;
        await report();
        expect(container.read(locationReportingControllerProvider), isFalse);
        expect(encounters.reports, hasLength(1));
      },
    );

    test('a refused location sends nothing and fails silently', () async {
      location.error = const LocationAccessDenied(permanently: false);

      await report();

      expect(encounters.reports, isEmpty);
    });
  });
}
