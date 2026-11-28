import 'package:evasion/app/router/app_routes.dart';
import 'package:evasion/core/models/location_mode.dart';
import 'package:evasion/features/settings/presentation/settings_controller.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Tells an invisible user that nobody crosses them, with a way to the
/// settings. Shows nothing otherwise, or while the settings load.
class InvisibleNotice extends ConsumerWidget {
  const InvisibleNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(settingsControllerProvider).value?.locationMode;
    if (mode != LocationMode.invisible) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.crossingsInvisible),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: () => context.push(AppRoutes.settings),
                child: Text(l10n.crossingsOpenSettings),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
