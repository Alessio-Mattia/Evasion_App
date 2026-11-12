import 'package:evasion/features/profile/presentation/carousel/carousel_card.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// Last card of the own carousel, while pages can still be added.
class AddPageCard extends StatelessWidget {
  const AddPageCard({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return CarouselCard(
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 12,
              children: [
                Icon(
                  Icons.add_circle_outline,
                  size: 56,
                  color: theme.colorScheme.primary,
                ),
                Text(l10n.profileAddPage, style: theme.textTheme.titleLarge),
                Text(
                  l10n.profileAddPageHint,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
