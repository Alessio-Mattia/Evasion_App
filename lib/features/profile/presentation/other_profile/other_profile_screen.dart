import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/features/profile/domain/profile_page.dart';
import 'package:evasion/features/profile/presentation/carousel/profile_carousel.dart';
import 'package:evasion/features/profile/presentation/other_profile/other_profile_providers.dart';
import 'package:evasion/features/profile/presentation/profile_sections.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The profile of someone else, read only: the carousel, how the user met
/// them, then the bio.
class OtherProfileScreen extends ConsumerWidget {
  const OtherProfileScreen({
    required this.userId,
    this.meetingNote,
    this.showBackButton = true,
    super.key,
  });

  final String userId;

  /// Provided by the router, so that this feature does not depend on the
  /// one the profile was opened from: for example when the two crossed.
  final Widget? meetingNote;

  /// False when the screen it was opened from is gone, such as the connect
  /// screen after a new connection.
  final bool showBackButton;

  Future<void> _reload(WidgetRef ref) async {
    ref
      ..invalidate(publicProfileProvider(userId))
      ..invalidate(otherPagesProvider(userId));
    await ref.read(publicProfileProvider(userId).future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Always watched, so that the pages load with the profile.
    final pages =
        ref.watch(otherPagesProvider(userId)).value ?? const <ProfilePage>[];

    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: showBackButton),
      body: switch (ref.watch(publicProfileProvider(userId))) {
        AsyncValue(:final value?) => RefreshIndicator(
          onRefresh: () => _reload(ref),
          child: ListView(
            padding: const EdgeInsets.only(left: 16, top: 8, bottom: 24),
            children: [
              // Pages that fail to load leave the page built from the profile.
              ProfileCarousel(profile: value, pages: pages),
              ?meetingNote,
              AboutSection(profile: value),
            ],
          ),
        ),
        // Deleted, not complete, or blocked: the user never learns which.
        AsyncValue(error: NotFoundFailure()) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              AppLocalizations.of(context).otherProfileUnavailable,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        AsyncValue(:final error?) => ProfileFailureView(
          error: error,
          onRetry: () => _reload(ref),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
