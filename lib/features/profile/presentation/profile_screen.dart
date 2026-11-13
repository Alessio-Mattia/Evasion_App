import 'dart:async';

import 'package:evasion/app/router/app_routes.dart';
import 'package:evasion/core/config/business_rules.dart';
import 'package:evasion/core/widgets/failure_snack_bar.dart';
import 'package:evasion/features/profile/domain/profile_page.dart';
import 'package:evasion/features/profile/presentation/carousel/profile_carousel.dart';
import 'package:evasion/features/profile/presentation/edit/confirm_page_deletion.dart';
import 'package:evasion/features/profile/presentation/edit/pages_edit_strip.dart';
import 'package:evasion/features/profile/presentation/editor/page_type_sheet.dart';
import 'package:evasion/features/profile/presentation/own_profile.dart';
import 'package:evasion/features/profile/presentation/page_editing_controllers.dart';
import 'package:evasion/features/profile/presentation/profile_sections.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The signed-in user's profile, as others will see it: the carousel, then the
/// bio. A long press on any page opens the edit mode, where the first page
/// leads to the profile edit screen.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({required this.userId, this.settingsButton, super.key});

  /// Provided by the router, so that this feature does not depend on auth.
  final String userId;

  /// Provided by the router, so that this feature does not depend on
  /// settings.
  final Widget? settingsButton;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _editing = false;
  String? _deletingId;

  /// The order just chosen by the user, shown while it is being saved.
  List<ProfilePage>? _pendingOrder;

  String get _userId => widget.userId;

  Future<void> _reload() async {
    ref
      ..invalidate(ownProfileProvider(_userId))
      ..invalidate(ownPagesProvider(_userId));
    await ref.read(ownProfileProvider(_userId).future);
  }

  void _startEditing() {
    unawaited(HapticFeedback.mediumImpact());
    setState(() => _editing = true);
  }

  Future<void> _addPage() async {
    final type = await choosePageType(context);
    if (type == null || !mounted) return;
    await context.push(AppRoutes.newProfilePage(type.code));
  }

  Future<void> _editProfile() => context.push(AppRoutes.editProfile);

  Future<void> _edit(ProfilePage page) =>
      context.push(AppRoutes.editProfilePage(page.id));

  Future<void> _reorder(List<ProfilePage> pages) async {
    setState(() => _pendingOrder = pages);
    await ref
        .read(reorderPagesControllerProvider(_userId).notifier)
        .reorder(pages);
    if (!mounted) return;
    // Keeps the chosen order until the pages are reloaded, so that the
    // previous one does not show in between.
    try {
      await ref.read(ownPagesProvider(_userId).future);
    } on Object {
      // Shown by the profile itself; the pages loaded before stay.
    }
    // The reloaded pages show the saved order, or the previous one if saving
    // failed.
    if (mounted) setState(() => _pendingOrder = null);
  }

  Future<void> _delete(ProfilePage page) async {
    if (!await confirmPageDeletion(context) || !mounted) return;
    setState(() => _deletingId = page.id);
    await ref.read(deletePageControllerProvider(_userId).notifier).delete(page);
    if (mounted) setState(() => _deletingId = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    void showFailure(AsyncValue<void>? _, AsyncValue<void> next) {
      if (next case AsyncError(:final error)) {
        showFailureSnackBar(context, error);
      }
    }

    ref
      ..listen(deletePageControllerProvider(_userId), showFailure)
      ..listen(reorderPagesControllerProvider(_userId), showFailure);
    final isReordering = ref
        .watch(reorderPagesControllerProvider(_userId))
        .isLoading;
    // Always watched, even while a new order is shown: a provider nobody
    // watches is disposed, and would reload from nothing.
    final loadedPages = ref.watch(ownPagesProvider(_userId)).value;
    // Pages that fail to load leave the page built from the profile.
    final pages = _pendingOrder ?? loadedPages ?? const <ProfilePage>[];

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (_editing)
            TextButton(
              onPressed: () => setState(() => _editing = false),
              child: Text(l10n.profileEditDone),
            )
          else
            ?widget.settingsButton,
        ],
      ),
      body: switch (ref.watch(ownProfileProvider(_userId))) {
        AsyncValue(:final value?) => RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            padding: const EdgeInsets.only(left: 16, top: 8, bottom: 24),
            children: [
              if (_editing) ...[
                PagesEditStrip(
                  avatarPath: value.avatarPath,
                  pages: pages,
                  deletingId: _deletingId,
                  isBusy: _deletingId != null || isReordering,
                  onEditProfile: _editProfile,
                  onEdit: _edit,
                  onDelete: _delete,
                  onReorder: _reorder,
                ),
                ProfileHint(l10n.profileEditHint),
              ] else ...[
                ProfileCarousel(
                  profile: value,
                  pages: pages,
                  onAddPage: pages.length < BusinessRules.profilePagesMax
                      ? _addPage
                      : null,
                  onLongPressPage: _startEditing,
                ),
                ProfileHint(l10n.profileEditTip),
              ],
              AboutSection(profile: value),
            ],
          ),
        ),
        AsyncValue(:final error?) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 16,
            children: [
              Text(failureMessage(context, error), textAlign: TextAlign.center),
              FilledButton(onPressed: _reload, child: Text(l10n.retry)),
            ],
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
