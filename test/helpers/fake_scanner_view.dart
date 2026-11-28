import 'package:evasion/core/scanner/scanner_view.dart';
import 'package:flutter/material.dart';

/// Stands in for the camera in widget tests: tests make it see QR codes, or
/// fail to start.
class FakeScannerView {
  /// Finds the fake camera in the widget tree.
  static const key = Key('fake-scanner');

  /// Set before the camera is shown to make it fail to start.
  ScannerProblem? problem;

  ScannerViewProps? _props;

  ScannerViewBuilder get builder => (props) {
    _props = props;
    if (problem case final problem?) return props.problemBuilder(problem);
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(key: key, color: Colors.transparent),
        props.overlay,
      ],
    );
  };

  /// As if the camera saw a QR code holding [text].
  void see(String text) =>
      (_props ?? (throw StateError('No camera shown yet'))).onCode(text);
}
