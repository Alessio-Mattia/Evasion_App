import 'package:evasion/features/connections/presentation/connect/my_qr_view.dart';
import 'package:evasion/features/connections/presentation/connect/scan_view.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

enum _Mode { myCode, scan }

/// Connecting with someone met in person: one shows their QR code, the other
/// scans it, and the two are friends. Only the chosen side is built, so the
/// camera is on only while scanning.
class ConnectScreen extends StatefulWidget {
  const ConnectScreen({required this.onOpenProfile, super.key});

  /// Provided by the router: opens the profile of the new friend.
  final ValueChanged<String> onOpenProfile;

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  _Mode _mode = _Mode.myCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.connectTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SegmentedButton<_Mode>(
              segments: [
                ButtonSegment(
                  value: _Mode.myCode,
                  icon: const Icon(Icons.qr_code_2),
                  label: Text(l10n.connectMyCode),
                ),
                ButtonSegment(
                  value: _Mode.scan,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: Text(l10n.connectScan),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (selection) =>
                  setState(() => _mode = selection.single),
            ),
          ),
          Expanded(
            child: switch (_mode) {
              _Mode.myCode => MyQrView(onOpenProfile: widget.onOpenProfile),
              _Mode.scan => ScanView(onOpenProfile: widget.onOpenProfile),
            },
          ),
        ],
      ),
    );
  }
}
