import 'package:evasion/features/profile/domain/profile.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// A short explanation under the carousel.
class ProfileHint extends StatelessWidget {
  const ProfileHint(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 20, 0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// The bio, under the carousel; nothing when it is empty.
class AboutSection extends StatelessWidget {
  const AboutSection({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final bio = profile.bio?.trim() ?? '';
    if (bio.isEmpty) return const SizedBox.shrink();
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text(
            AppLocalizations.of(context).profileAboutTitle,
            style: textTheme.titleMedium,
          ),
          Text(bio, style: textTheme.bodyLarge),
        ],
      ),
    );
  }
}
