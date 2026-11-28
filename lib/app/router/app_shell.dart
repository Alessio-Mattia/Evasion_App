import 'package:evasion/app/router/app_routes.dart';
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
class AppShell extends ConsumerStatefulWidget {
  const AppShell({
    required this.navigationShell,
    required this.currentPath,
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  /// The page shown, such as `/messages`.
  final String currentPath;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  /// Tabs left on a page the user only passes through: they open on their
  /// root next time.
  final Set<int> _tabsToReset = {};

  void _selectTab(int index) {
    final shell = widget.navigationShell;
    final current = shell.currentIndex;
    if (index != current && AppRoutes.isPassingPage(widget.currentPath)) {
      _tabsToReset.add(current);
    }
    shell.goBranch(
      index,
      // Tapping the active tab also returns to its root.
      initialLocation: index == current || _tabsToReset.remove(index),
    );
  }

  @override
  Widget build(BuildContext context) {
    final navigationShell = widget.navigationShell;
    final l10n = AppLocalizations.of(context);
    final mode = ref.watch(settingsControllerProvider).value?.locationMode;
    return Scaffold(
      body: LocationReporter(
        isSharing: mode == LocationMode.foreground,
        child: navigationShell,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _selectTab,
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
