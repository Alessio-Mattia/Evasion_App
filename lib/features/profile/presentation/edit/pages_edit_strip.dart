import 'dart:math';

import 'package:evasion/features/profile/domain/profile_page.dart';
import 'package:evasion/features/profile/presentation/edit/page_thumbnail.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// The edit mode of the own carousel: every page side by side, gently
/// shaking, each with a button to delete it. The page built from the profile
/// comes first and cannot be deleted.
class PagesEditStrip extends StatefulWidget {
  const PagesEditStrip({
    required this.avatarPath,
    required this.pages,
    required this.onDelete,
    this.deletingId,
    super.key,
  });

  final String? avatarPath;
  final List<ProfilePage> pages;
  final ValueChanged<ProfilePage> onDelete;

  /// The page being deleted, shown with a spinner.
  final String? deletingId;

  @override
  State<PagesEditStrip> createState() => _PagesEditStripState();
}

class _PagesEditStripState extends State<PagesEditStrip>
    with SingleTickerProviderStateMixin {
  late final _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // No shaking for those who asked the phone to reduce motion.
    if (MediaQuery.disableAnimationsOf(context)) {
      _shake.stop();
    } else if (!_shake.isAnimating) {
      _shake.repeat();
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDeleting = widget.deletingId != null;
    return SizedBox(
      height: thumbnailSize.height + 24,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(4, 12, 20, 12),
        children: [
          PageThumbnail(avatarPath: widget.avatarPath),
          for (final (index, page) in widget.pages.indexed)
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: AnimatedBuilder(
                animation: _shake,
                // Neighbours move in opposite directions, like on a phone's
                // home screen.
                builder: (context, child) => Transform.rotate(
                  angle: sin(_shake.value * 2 * pi + index * pi) * 0.025,
                  child: child,
                ),
                child: _DeletableThumbnail(
                  page: page,
                  isDeleting: widget.deletingId == page.id,
                  onDelete: isDeleting ? null : () => widget.onDelete(page),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DeletableThumbnail extends StatelessWidget {
  const _DeletableThumbnail({
    required this.page,
    required this.isDeleting,
    required this.onDelete,
  });

  final ProfilePage page;
  final bool isDeleting;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        PageThumbnail(page: page),
        if (isDeleting)
          const Positioned.fill(
            child: Center(child: CircularProgressIndicator()),
          ),
        Positioned(
          top: -10,
          right: -10,
          child: IconButton.filled(
            onPressed: onDelete,
            tooltip: AppLocalizations.of(context).pageDeleteTooltip,
            visualDensity: VisualDensity.compact,
            iconSize: 16,
            icon: const Icon(Icons.close),
          ),
        ),
      ],
    );
  }
}
