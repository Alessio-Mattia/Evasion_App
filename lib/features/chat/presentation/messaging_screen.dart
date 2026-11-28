import 'package:evasion/app/router/app_routes.dart';
import 'package:evasion/core/widgets/tab_placeholder.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The messages between friends. For now, the way to make friends: the QR
/// code button.
class MessagingScreen extends StatelessWidget {
  const MessagingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_2),
            tooltip: l10n.connectOpen,
            onPressed: () => context.push(AppRoutes.connect),
          ),
        ],
      ),
      body: TabPlaceholder(title: l10n.tabMessages),
    );
  }
}
