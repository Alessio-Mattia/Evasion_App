import 'dart:async';

import 'package:evasion/core/config/business_rules.dart';
import 'package:evasion/core/services/location_service.dart';
import 'package:evasion/features/encounters/data/supabase_encounters_repository.dart';
import 'package:evasion/features/encounters/presentation/crossings_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'location_reporting.g.dart';

/// Sends the phone's position for crossings, one report at a time. The state
/// says whether the user should allow the precise location: several
/// imprecise positions in a row mean they chose the approximate one, which
/// creates no crossing.
@Riverpod(keepAlive: true)
class LocationReportingController extends _$LocationReportingController {
  int _impreciseInARow = 0;
  bool _reporting = false;

  @override
  bool build() => false;

  /// Reads the position and sends it. Failures are silent: the next report
  /// tries again, and the crossings screen tells what the user can fix.
  Future<void> report() async {
    if (_reporting) return;
    _reporting = true;
    try {
      final fix = await ref.read(locationServiceProvider).currentFix();
      if (fix.accuracyMeters > BusinessRules.locationMaxAccuracyMeters) {
        _impreciseInARow++;
        if (_impreciseInARow >= BusinessRules.impreciseReportsBeforeNotice) {
          state = true;
        }
        // The server would ignore it.
        return;
      }
      _impreciseInARow = 0;
      state = false;
      final kept = await ref
          .read(encountersRepositoryProvider)
          .reportLocation(fix);
      // A kept position may have made a crossing: the list shows it at once.
      if (kept) ref.invalidate(crossingsProvider);
    } on Exception {
      // Permission refused, location off, no fix in time, or the server
      // refusing an invisible user (AppFailure): nothing to send now.
    } finally {
      _reporting = false;
    }
  }
}

/// Sends the position every `BusinessRules.locationReportInterval` while the
/// app is on screen and [isSharing] (the user is visible), and at once when
/// either becomes true. Stops as soon as the app leaves the screen: a
/// position never leaves the phone in the background.
class LocationReporter extends ConsumerStatefulWidget {
  const LocationReporter({
    required this.isSharing,
    required this.child,
    super.key,
  });

  /// Provided by the app, from the settings: this feature does not depend on
  /// them.
  final bool isSharing;
  final Widget child;

  @override
  ConsumerState<LocationReporter> createState() => _LocationReporterState();
}

class _LocationReporterState extends ConsumerState<LocationReporter> {
  late final AppLifecycleListener _lifecycle;
  Timer? _timer;
  bool _onScreen = true;

  @override
  void initState() {
    super.initState();
    final state = WidgetsBinding.instance.lifecycleState;
    _onScreen = state == null || state == AppLifecycleState.resumed;
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        _onScreen = state == AppLifecycleState.resumed;
        _sync();
      },
    );
    _sync();
  }

  @override
  void didUpdateWidget(LocationReporter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isSharing != widget.isSharing) _sync();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  void _sync() {
    final shouldReport = widget.isSharing && _onScreen;
    if (!shouldReport) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    if (_timer != null) return;
    _report();
    _timer = Timer.periodic(
      BusinessRules.locationReportInterval,
      (_) => _report(),
    );
  }

  void _report() => unawaited(
    ref.read(locationReportingControllerProvider.notifier).report(),
  );

  @override
  Widget build(BuildContext context) => widget.child;
}
