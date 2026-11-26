import 'package:evasion/app/theme/app_colors.dart';
import 'package:evasion/core/storage/storage_images.dart';
import 'package:evasion/core/widgets/storage_image.dart';
import 'package:evasion/features/posts/domain/post.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// How long [expiresAt] is from [now], in the largest whole unit: "encore
/// 5 h". Never below a minute.
String timeLeft(AppLocalizations l10n, DateTime expiresAt, DateTime now) {
  final left = expiresAt.difference(now);
  if (left.inDays >= 1) return l10n.postTimeLeftDays(left.inDays);
  if (left.inHours >= 1) return l10n.postTimeLeftHours(left.inHours);
  return l10n.postTimeLeftMinutes(left.inMinutes < 1 ? 1 : left.inMinutes);
}

/// The post tapped on the map: its photo, author, caption, time left, and
/// the pin button.
class PostCard extends StatelessWidget {
  const PostCard({
    required this.post,
    required this.onTogglePin,
    required this.now,
    super.key,
  });

  final Post post;
  final VoidCallback onTogglePin;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final avatar = post.authorAvatarPath;
    final caption = post.caption;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 14,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.thumbnail),
              child: SizedBox(
                width: 72,
                height: 90,
                child: StorageImage(
                  bucket: StorageBucket.postPhotos,
                  path: post.imagePath,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 6,
                children: [
                  Row(
                    spacing: 8,
                    children: [
                      if (avatar != null)
                        ClipOval(
                          child: SizedBox.square(
                            dimension: 24,
                            child: StorageImage(
                              bucket: StorageBucket.avatars,
                              path: avatar,
                            ),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          post.authorName ?? '',
                          style: theme.textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (caption != null)
                    Text(caption, maxLines: 3, overflow: TextOverflow.ellipsis),
                  Text(
                    timeLeft(l10n, post.expiresAt, now),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onTogglePin,
              tooltip: post.isPinned ? l10n.postUnpin : l10n.postPin,
              isSelected: post.isPinned,
              color: colors.onSurfaceVariant,
              selectedIcon: Icon(Icons.push_pin, color: colors.primary),
              icon: const Icon(Icons.push_pin_outlined),
            ),
          ],
        ),
      ),
    );
  }
}
