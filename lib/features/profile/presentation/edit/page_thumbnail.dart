import 'package:evasion/core/storage/storage_images.dart';
import 'package:evasion/core/widgets/storage_image.dart';
import 'package:evasion/features/profile/domain/profile_page.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// Size of a page in the edit mode, 4:5 like the carousel cards.
const thumbnailSize = Size(96, 120);

/// A small preview of a page, in the edit mode. [page] null shows the page
/// built from the profile, with its [avatarPath].
class PageThumbnail extends StatelessWidget {
  const PageThumbnail({this.page, this.avatarPath, super.key});

  final ProfilePage? page;
  final String? avatarPath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall;
    final avatarPath = this.avatarPath;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox.fromSize(
        size: thumbnailSize,
        child: ColoredBox(
          color: theme.colorScheme.surfaceContainerHigh,
          child: switch (page) {
            null when avatarPath != null => StorageImage(
              bucket: StorageBucket.avatars,
              path: avatarPath,
            ),
            null => const SizedBox.shrink(),
            TextPage(:final text) => Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                text,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: small,
              ),
            ),
            PhotoPage(:final imagePath) => StorageImage(
              bucket: StorageBucket.profilePhotos,
              path: imagePath,
            ),
            InterestsPage(:final interests) => Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                spacing: 4,
                children: [
                  Icon(
                    Icons.interests_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  Text(
                    [
                      for (final interest in interests)
                        interest.label(AppLocalizations.of(context)),
                    ].join(', '),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: small,
                  ),
                ],
              ),
            ),
          },
        ),
      ),
    );
  }
}
