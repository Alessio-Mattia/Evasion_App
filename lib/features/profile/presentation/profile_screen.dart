import 'package:evasion/core/widgets/failure_snack_bar.dart';
import 'package:evasion/features/profile/presentation/carousel/profile_carousel.dart';
import 'package:evasion/features/profile/presentation/own_profile.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The signed-in user's profile, as others will see it: the carousel, then the
/// bio.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({required this.userId, this.settingsButton, super.key});

  /// Provided by the router, so that this feature does not depend on auth.
  final String userId;

  /// Provided by the router, so that this feature does not depend on
  /// settings.
  final Widget? settingsButton;

  Future<void> _reload(WidgetRef ref) async {
    ref
      ..invalidate(ownProfileProvider(userId))
      ..invalidate(ownPagesProvider(userId));
    await ref.read(ownProfileProvider(userId).future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    // Pages that fail to load leave the page built from the profile.
    final pages = ref.watch(ownPagesProvider(userId)).value ?? const [];

    return Scaffold(
      appBar: AppBar(actions: [?settingsButton]),
      body: switch (ref.watch(ownProfileProvider(userId))) {
        AsyncValue(:final value?) => RefreshIndicator(
          onRefresh: () => _reload(ref),
          child: ListView(
            padding: const EdgeInsets.only(left: 16, top: 8, bottom: 24),
            children: [
              ProfileCarousel(profile: value, pages: pages),
              if (value.bio case final bio? when bio.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 24, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 8,
                    children: [
                      Text(l10n.profileAboutTitle, style: textTheme.titleMedium),
                      Text(bio, style: textTheme.bodyLarge),
                    ],
                  ),
                ),
            ],
          ),
        ),
        AsyncValue(:final error?) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 16,
            children: [
              Text(failureMessage(context, error), textAlign: TextAlign.center),
              FilledButton(
                onPressed: () => _reload(ref),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
