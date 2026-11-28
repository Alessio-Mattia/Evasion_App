import 'package:evasion/core/scanner/mobile_scanner_view.dart';
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'scanner_view.g.dart';

/// Why the camera cannot scan.
enum ScannerProblem {
  /// The user refused the camera: only the phone's settings can allow it.
  permissionDenied,

  /// No camera, or it failed to start.
  unavailable,
}

/// What a QR code scanner reports, and what it shows when it cannot scan.
class ScannerViewProps {
  const ScannerViewProps({
    required this.onCode,
    required this.overlay,
    required this.problemBuilder,
  });

  /// The text of each QR code seen. The same code is reported again while it
  /// stays in view: the screen decides what to do with repeats.
  final ValueChanged<String> onCode;

  /// Shown over the camera, filling it, only while the camera works.
  final Widget overlay;

  /// Shown instead of the camera, and of [overlay], when it cannot scan.
  final Widget Function(ScannerProblem problem) problemBuilder;
}

/// Builds the camera view that scans QR codes. The camera is native, so
/// widget tests replace it with a fake that reports codes on demand.
typedef ScannerViewBuilder = Widget Function(ScannerViewProps props);

@Riverpod(keepAlive: true)
ScannerViewBuilder scannerViewBuilder(Ref ref) =>
    (props) => MobileScannerView(props: props);
