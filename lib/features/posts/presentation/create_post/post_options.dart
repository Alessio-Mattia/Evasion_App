import 'package:evasion/core/config/business_rules.dart';
import 'package:evasion/features/posts/domain/post.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// A section of the post form: its title, then its content.
class PostFormSection extends StatelessWidget {
  const PostFormSection({
    required this.title,
    required this.children,
    super.key,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        Text(
          title.toUpperCase(),
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 1.2,
          ),
        ),
        ...children,
      ],
    );
  }
}

/// Where the post goes: the phone's position for now, blurred or exact.
class PostPlaceSection extends StatelessWidget {
  const PostPlaceSection({
    required this.precision,
    required this.placeChosen,
    required this.onPrecisionChanged,
    required this.onChoosePlace,
    required this.onBackToMyPosition,
    super.key,
  });

  final PostPrecision precision;

  /// Whether the place was picked on the map, rather than the phone's
  /// position.
  final bool placeChosen;
  final ValueChanged<PostPrecision>? onPrecisionChanged;
  final VoidCallback? onChoosePlace;
  final VoidCallback? onBackToMyPosition;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final onChanged = onPrecisionChanged;

    return PostFormSection(
      title: l10n.createPostPlaceTitle,
      children: [
        Row(
          spacing: 12,
          children: [
            Icon(Icons.place_outlined, color: theme.colorScheme.primary),
            Expanded(
              child: Text(
                placeChosen
                    ? l10n.createPostChosenPlace
                    : l10n.createPostCurrentPosition,
              ),
            ),
            TextButton(
              onPressed: onChoosePlace,
              child: Text(l10n.createPostChangePlace),
            ),
          ],
        ),
        if (placeChosen)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: onBackToMyPosition,
              icon: const Icon(Icons.my_location),
              label: Text(l10n.createPostBackToMyPosition),
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<PostPrecision>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: PostPrecision.fuzzy,
                label: Text(l10n.createPostPrecisionFuzzy),
              ),
              ButtonSegment(
                value: PostPrecision.exact,
                label: Text(l10n.createPostPrecisionExact),
              ),
            ],
            selected: {precision},
            onSelectionChanged: onChanged == null
                ? null
                : (selection) => onChanged(selection.single),
          ),
        ),
        Text(
          switch (precision) {
            PostPrecision.fuzzy => l10n.createPostFuzzyHint(
              BusinessRules.postFuzzyCellSizeMeters,
            ),
            PostPrecision.exact when placeChosen =>
              l10n.createPostExactHintChosen,
            PostPrecision.exact => l10n.createPostExactHint,
          },
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Who sees the post: everyone, until friends exist.
class PostAudienceSection extends StatelessWidget {
  const PostAudienceSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return PostFormSection(
      title: l10n.createPostAudienceTitle,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (audience, label) in [
              (PostAudience.everyone, l10n.postAudienceEveryone),
              (PostAudience.friends, l10n.postAudienceFriends),
              (PostAudience.selected, l10n.postAudienceSelected),
            ])
              ChoiceChip(
                label: Text(label),
                selected: audience == PostAudience.everyone,
                // Friends do not exist yet: a post for friends would be seen
                // by nobody.
                onSelected: audience == PostAudience.everyone ? (_) {} : null,
              ),
          ],
        ),
        Text(
          l10n.createPostFriendsSoon,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// How long the post stays on the map.
class PostLifetimeSection extends StatelessWidget {
  const PostLifetimeSection({
    required this.lifetime,
    required this.onChanged,
    super.key,
  });

  final Duration lifetime;
  final ValueChanged<Duration>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final onChanged = this.onChanged;
    return PostFormSection(
      title: l10n.createPostLifetimeTitle,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final choice in BusinessRules.postLifetimeChoices)
              ChoiceChip(
                label: Text(
                  choice.inHours < 24
                      ? l10n.postLifetimeHours(choice.inHours)
                      : l10n.postLifetimeDays(choice.inDays),
                ),
                selected: choice == lifetime,
                onSelected: onChanged == null ? null : (_) => onChanged(choice),
              ),
          ],
        ),
      ],
    );
  }
}

/// Warns before showing the exact place of the post. Returns whether the
/// user confirmed.
Future<bool> confirmExactPlace(
  BuildContext context, {
  required bool placeChosen,
}) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.createPostExactConfirmTitle),
      content: Text(
        placeChosen
            ? l10n.createPostExactConfirmBodyChosen
            : l10n.createPostExactConfirmBody,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.createPostExactConfirm),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
