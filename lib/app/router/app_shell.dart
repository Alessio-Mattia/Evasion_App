import 'package:evasion/core/models/location_mode.dart';
import 'package:evasion/features/encounters/presentation/location_reporting.dart';
import 'package:evasion/features/settings/presentation/settings_controller.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The tabs. While they show, the position is sent for crossings if the user
/// is visible: this joins the settings and the encounters, which do not know
/// each other.
class AppShell extends ConsumerWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final mode = ref.watch(settingsControllerProvider).value?.locationMode;
    return Scaffold(
      body: LocationReporter(
        isSharing: mode == LocationMode.foreground,
        child: navigationShell,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        // Tapping the active tab returns to the root of that tab.
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.map_outlined),
            selectedIcon: const Icon(Icons.map),
            label: l10n.tabMap,
          ),
          NavigationDestination(
            // Two circles that cross, like the logo.
            icon: const Icon(Icons.join_inner_outlined),
            selectedIcon: const Icon(Icons.join_inner),
            label: l10n.tabCrossings,
          ),
          NavigationDestination(
            icon: const Icon(Icons.chat_bubble_outline),
            selectedIcon: const Icon(Icons.chat_bubble),
            label: l10n.tabMessages,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: l10n.tabProfile,
          ),
        ],
      ),
    );
  }
}
