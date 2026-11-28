import 'package:evasion/core/widgets/failure_snack_bar.dart';
import 'package:evasion/features/profile/domain/public_profile.dart';
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

  final PublicProfile profile;

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

/// Why a profile could not be loaded, with a button to try again.
class ProfileFailureView extends StatelessWidget {
  const ProfileFailureView({
    required this.error,
    required this.onRetry,
    super.key,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            Text(failureMessage(context, error), textAlign: TextAlign.center),
            FilledButton(
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context).retry),
            ),
          ],
        ),
      ),
    );
  }
}
