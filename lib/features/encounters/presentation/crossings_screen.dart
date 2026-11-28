import 'package:evasion/core/services/location_service.dart';
import 'package:evasion/core/widgets/failure_snack_bar.dart';
import 'package:evasion/features/encounters/domain/crossing.dart';
import 'package:evasion/features/encounters/domain/crossing_groups.dart';
import 'package:evasion/features/encounters/presentation/crossing_tile.dart';
import 'package:evasion/features/encounters/presentation/crossings_provider.dart';
import 'package:evasion/features/encounters/presentation/location_reporting.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The people whose paths crossed the user's, today then this week. Places
/// and times are rounded by the server.
class CrossingsScreen extends ConsumerWidget {
  const CrossingsScreen({this.visibilityNotice, super.key});

  /// Provided by the app, from the settings: says when the user is invisible,
  /// so that nobody crosses them.
  final Widget? visibilityNotice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final needsPrecise = ref.watch(locationReportingControllerProvider);
    final crossings = ref.watch(crossingsProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(crossingsProvider.future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Text(l10n.tabCrossings, style: theme.textTheme.headlineMedium),
              const SizedBox(height: 6),
              Text(
                l10n.crossingsSubtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              ?visibilityNotice,
              if (needsPrecise)
                _Notice(
                  text: l10n.crossingsNeedPreciseLocation,
                  action: l10n.crossingsAllowPreciseLocation,
                  onPressed: () =>
                      ref.read(locationServiceProvider).askForPreciseLocation(),
                ),
              ...switch (crossings) {
                AsyncValue(:final value?) => _sections(context, value),
                AsyncValue(:final error?) => [
                  _Message(failureMessage(context, error)),
                ],
                _ => [
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
              },
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _sections(BuildContext context, List<Crossing> crossings) {
    final l10n = AppLocalizations.of(context);
    if (crossings.isEmpty) return [_Message(l10n.crossingsEmpty)];
    final (:today, :earlier) = groupCrossingsByDay(crossings, DateTime.now());
    return [
      for (final (title, group, showDay) in [
        (l10n.crossingsToday, today, false),
        (l10n.crossingsThisWeek, earlier, true),
      ])
        if (group.isNotEmpty) ...[
          _SectionTitle(title),
          for (final crossing in group)
            CrossingTile(crossing: crossing, showDay: showDay),
        ],
    ];
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Text(text, textAlign: TextAlign.center),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.text,
    required this.action,
    required this.onPressed,
  });

  final String text;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(onPressed: onPressed, child: Text(action)),
            ),
          ],
        ),
      ),
    );
  }
}
