import 'package:evasion/core/photos/photo_file.dart';
import 'package:evasion/core/services/photo_picker.dart';
import 'package:evasion/core/storage/storage_images.dart';
import 'package:evasion/core/widgets/failure_snack_bar.dart';
import 'package:evasion/core/widgets/pick_photo.dart';
import 'package:evasion/core/widgets/storage_image.dart';
import 'package:evasion/features/profile/presentation/profile_edit/profile_edit_controllers.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The round profile photo, with a button to replace it. A new photo is saved
/// at once, apart from the texts.
class AvatarEditor extends ConsumerWidget {
  const AvatarEditor({
    required this.userId,
    required this.avatarPath,
    super.key,
  });

  final String userId;
  final String? avatarPath;

  static const double _size = 160;

  Future<void> _change(BuildContext context, WidgetRef ref) async {
    final source = await _chooseSource(context);
    if (source == null || !context.mounted) return;
    final photo = await pickCheckedPhoto(
      context,
      ref,
      source: source,
      shape: PhotoShape.round,
      cropTitle: AppLocalizations.of(context).pagePhotoCropTitle,
    );
    if (photo == null) return;
    await ref
        .read(replaceAvatarControllerProvider(userId).notifier)
        // pickCheckedPhoto only returns photos of a known format.
        .replace(photo, detectPhotoFormat(photo)!);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = replaceAvatarControllerProvider(userId);
    ref.listen(provider, (_, next) {
      if (next case AsyncError(:final error)) {
        showFailureSnackBar(context, error);
      }
    });
    final isSaving = ref.watch(provider).isLoading;
    final colors = Theme.of(context).colorScheme;
    final path = avatarPath;

    return Column(
      spacing: 8,
      children: [
        ClipOval(
          child: SizedBox.square(
            dimension: _size,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (path != null)
                  StorageImage(bucket: StorageBucket.avatars, path: path),
                if (isSaving)
                  ColoredBox(
                    color: colors.scrim.withValues(alpha: 0.5),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
        ),
        TextButton.icon(
          onPressed: isSaving ? null : () => _change(context, ref),
          icon: const Icon(Icons.photo_camera_outlined),
          label: Text(AppLocalizations.of(context).profileEditPhotoChange),
        ),
      ],
    );
  }
}

Future<PhotoSource?> _chooseSource(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showModalBottomSheet<PhotoSource>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(l10n.pagePhotoGallery),
            onTap: () => Navigator.pop(context, PhotoSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(l10n.pagePhotoCamera),
            onTap: () => Navigator.pop(context, PhotoSource.camera),
          ),
        ],
      ),
    ),
  );
}
