import 'dart:math';

import 'package:evasion/features/profile/domain/profile_page.dart';
import 'package:evasion/features/profile/presentation/edit/page_thumbnail.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// The edit mode of the own carousel: every page side by side, gently
/// shaking. A tap edits a page, holding it lets the user move it, and its
/// button deletes it. The page built from the profile comes first and stays
/// there.
class PagesEditStrip extends StatefulWidget {
  const PagesEditStrip({
    required this.avatarPath,
    required this.pages,
    required this.onEdit,
    required this.onDelete,
    required this.onReorder,
    this.isBusy = false,
    this.deletingId,
    super.key,
  });

  final String? avatarPath;
  final List<ProfilePage> pages;
  final ValueChanged<ProfilePage> onEdit;
  final ValueChanged<ProfilePage> onDelete;

  /// Called with the pages in their new order.
  final ValueChanged<List<ProfilePage>> onReorder;

  /// While a change is being saved, the pages cannot be edited, moved or
  /// deleted.
  final bool isBusy;

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

  void _move(int from, int to) {
    if (from == to) return;
    final pages = [...widget.pages];
    pages.insert(to, pages.removeAt(from));
    widget.onReorder(pages);
  }

  @override
  Widget build(BuildContext context) {
    final busy = widget.isBusy;
    return SizedBox(
      height: thumbnailSize.height + 24,
      child: ReorderableListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(4, 12, 20, 12),
        // Holding a page picks it up, on every platform.
        buildDefaultDragHandles: false,
        header: PageThumbnail(avatarPath: widget.avatarPath),
        itemCount: widget.pages.length,
        onReorderItem: _move,
        // The page being moved keeps its shape, slightly raised.
        proxyDecorator: (child, _, _) => Material(
          type: MaterialType.transparency,
          elevation: 6,
          child: child,
        ),
        itemBuilder: (context, index) {
          final page = widget.pages[index];
          final thumbnail = Padding(
            padding: const EdgeInsets.only(left: 16),
            child: AnimatedBuilder(
              animation: _shake,
              // Neighbours move in opposite directions, like on a phone's
              // home screen.
              builder: (context, child) => Transform.rotate(
                angle: sin(_shake.value * 2 * pi + index * pi) * 0.025,
                child: child,
              ),
              child: _EditableThumbnail(
                page: page,
                isDeleting: widget.deletingId == page.id,
                onEdit: busy ? null : () => widget.onEdit(page),
                onDelete: busy ? null : () => widget.onDelete(page),
              ),
            ),
          );
          return busy
              ? KeyedSubtree(key: ValueKey(page.id), child: thumbnail)
              : ReorderableDelayedDragStartListener(
                  key: ValueKey(page.id),
                  index: index,
                  child: thumbnail,
                );
        },
      ),
    );
  }
}

class _EditableThumbnail extends StatelessWidget {
  const _EditableThumbnail({
    required this.page,
    required this.isDeleting,
    required this.onEdit,
    required this.onDelete,
  });

  final ProfilePage page;
  final bool isDeleting;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Semantics(
          button: true,
          label: l10n.pageEditTooltip,
          child: GestureDetector(
            onTap: onEdit,
            child: PageThumbnail(page: page),
          ),
        ),
        if (isDeleting)
          const Positioned.fill(
            child: Center(child: CircularProgressIndicator()),
          ),
        Positioned(
          top: -10,
          right: -10,
          child: IconButton.filled(
            onPressed: onDelete,
            tooltip: l10n.pageDeleteTooltip,
            visualDensity: VisualDensity.compact,
            iconSize: 16,
            icon: const Icon(Icons.close),
          ),
        ),
      ],
    );
  }
}
