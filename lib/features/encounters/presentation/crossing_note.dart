import 'package:evasion/features/encounters/domain/crossing.dart';
import 'package:evasion/features/encounters/domain/crossing_groups.dart';
import 'package:evasion/features/encounters/presentation/crossing_tile.dart';
import 'package:evasion/features/encounters/presentation/crossings_provider.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Recalls, on a profile, when the user crossed its owner: "Vos chemins se
/// sont croisés aujourd'hui, vers 14 h". Nothing once the crossing is no
/// longer in the list, for example a week later.
class CrossingNote extends ConsumerWidget {
  const CrossingNote({required this.crossingId, super.key});

  final String crossingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crossings = ref.watch(crossingsProvider).value ?? const <Crossing>[];
    final crossing = crossings.where((c) => c.id == crossingId).firstOrNull;
    if (crossing == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final time = crossingTime(crossing.crossedAt);
    final text = isSameLocalDay(crossing.crossedAt, DateTime.now())
        ? l10n.crossingNoteToday(time)
        : l10n.crossingNoteDay(crossingDay(context, crossing.crossedAt), time);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 20, 0),
      child: Row(
        spacing: 10,
        children: [
          Icon(
            Icons.near_me_outlined,
            size: 20,
            color: theme.colorScheme.secondary,
          ),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
