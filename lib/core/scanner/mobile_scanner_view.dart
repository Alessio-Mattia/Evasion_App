import 'dart:async';

import 'package:evasion/core/scanner/scanner_view.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// The phone's back camera, reading QR codes only.
class MobileScannerView extends StatefulWidget {
  const MobileScannerView({required this.props, super.key});

  final ScannerViewProps props;

  @override
  State<MobileScannerView> createState() => _MobileScannerViewState();
}

class _MobileScannerViewState extends State<MobileScannerView> {
  // Other barcodes, such as those of products, are not even looked for.
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MobileScanner(
      controller: _controller,
      onDetect: (capture) {
        for (final barcode in capture.barcodes) {
          if (barcode.rawValue case final text?) widget.props.onCode(text);
        }
      },
      // Shown by the scanner only while the camera works.
      overlayBuilder: (context, constraints) => SizedBox.fromSize(
        size: constraints.biggest,
        child: widget.props.overlay,
      ),
      errorBuilder: (context, error) => widget.props.problemBuilder(
        error.errorCode == MobileScannerErrorCode.permissionDenied
            ? ScannerProblem.permissionDenied
            : ScannerProblem.unavailable,
      ),
    );
  }
}
