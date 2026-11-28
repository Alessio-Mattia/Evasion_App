import 'package:evasion/core/storage/storage_images.dart';
import 'package:evasion/core/widgets/storage_image.dart';
import 'package:evasion/features/encounters/domain/crossing.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// "14 h 30", or "14 h" on the hour: the time of a crossing, already rounded
/// by the server. Its spaces are non-breaking, so that it is never split
/// across two lines.
String crossingTime(DateTime crossedAt) {
  const space = ' ';
  final local = crossedAt.toLocal();
  final minutes = local.minute.toString().padLeft(2, '0');
  final hour = '${local.hour}${space}h';
  return local.minute == 0 ? hour : '$hour$space$minutes';
}

/// "lundi" in French: the day of a crossing, in the phone's time zone.
String crossingDay(BuildContext context, DateTime crossedAt) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  return DateFormat.EEEE(locale).format(crossedAt.toLocal());
}

/// Someone crossed: photo, name and age, student badge, and when. Today's
/// crossings show the time only, earlier ones the day too. A tap calls
/// [onTap], to open their profile.
class CrossingTile extends StatelessWidget {
  const CrossingTile({
    required this.crossing,
    required this.showDay,
    required this.onTap,
    super.key,
  });

  final Crossing crossing;
  final bool showDay;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final avatar = crossing.avatarPath;
    final time = crossingTime(crossing.crossedAt);

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: ClipOval(
        child: SizedBox.square(
          dimension: 52,
          child: avatar == null
              ? ColoredBox(color: colors.surfaceContainerHighest)
              : StorageImage(bucket: StorageBucket.avatars, path: avatar),
        ),
      ),
      title: Row(
        spacing: 8,
        children: [
          Flexible(
            child: Text(
              l10n.profileNameAndAge(crossing.displayName, crossing.age),
              style: theme.textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (crossing.isStudentVerified)
            Icon(Icons.school_outlined, size: 18, color: colors.secondary),
        ],
      ),
      subtitle: Text(
        showDay
            ? l10n.crossingDayAndTime(
                _capitalized(crossingDay(context, crossing.crossedAt)),
                time,
              )
            : l10n.crossingTime(time),
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colors.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// "lundi" becomes "Lundi": the day starts the line.
String _capitalized(String text) =>
    text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
