import 'dart:typed_data';

import 'package:evasion/core/config/business_rules.dart';
import 'package:evasion/core/photos/photo_file.dart';
import 'package:evasion/core/services/photo_picker.dart';
import 'package:evasion/core/storage/storage_images.dart';
import 'package:evasion/core/widgets/pick_photo.dart';
import 'package:evasion/core/widgets/storage_image.dart';
import 'package:evasion/features/profile/domain/page_draft.dart';
import 'package:evasion/features/profile/domain/profile_page.dart';
import 'package:evasion/features/profile/presentation/editor/page_editor_scaffold.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Editor of a photo page: a portrait photo, then an optional caption.
class PhotoPageForm extends ConsumerStatefulWidget {
  const PhotoPageForm({
    required this.isSaving,
    required this.onSave,
    this.initial,
    super.key,
  });

  /// The page being edited, or null for a new one.
  final PhotoPage? initial;
  final bool isSaving;
  final ValueChanged<PageDraft> onSave;

  @override
  ConsumerState<PhotoPageForm> createState() => _PhotoPageFormState();
}

class _PhotoPageFormState extends ConsumerState<PhotoPageForm> {
  late final _caption = TextEditingController(text: widget.initial?.caption);

  /// A photo just chosen, which replaces the one of the page.
  Uint8List? _newPhoto;

  /// The photo of the page being edited, kept until another one is chosen.
  late String? _keptPath = widget.initial?.imagePath;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _pick(PhotoSource source) async {
    final picked = await pickCheckedPhoto(
      context,
      ref,
      source: source,
      shape: PhotoShape.portrait,
      cropTitle: AppLocalizations.of(context).pagePhotoCropTitle,
    );
    if (picked != null && mounted) setState(() => _newPhoto = picked);
  }

  PageDraft? _draft() {
    final caption = _caption.text;
    if (isCaptionTooLong(caption)) return null;
    if (_newPhoto case final photo?) {
      return PhotoPageDraft(
        bytes: photo,
        format: detectPhotoFormat(photo)!,
        caption: caption,
      );
    }
    if (_keptPath case final path?) {
      return KeptPhotoPageDraft(imagePath: path, caption: caption);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final newPhoto = _newPhoto;
    final keptPath = _keptPath;
    final hasPhoto = newPhoto != null || keptPath != null;
    final draft = _draft();

    return PageEditorScaffold(
      isNew: widget.initial == null,
      isSaving: widget.isSaving,
      onSave: draft != null ? () => widget.onSave(draft) : null,
      children: [
        if (!hasPhoto) ...[
          OutlinedButton.icon(
            onPressed: () => _pick(PhotoSource.gallery),
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(l10n.pagePhotoGallery),
          ),
          OutlinedButton.icon(
            onPressed: () => _pick(PhotoSource.camera),
            icon: const Icon(Icons.photo_camera_outlined),
            label: Text(l10n.pagePhotoCamera),
          ),
        ] else ...[
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: AspectRatio(
                aspectRatio: 4 / 5,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: newPhoto != null
                      ? Image.memory(newPhoto, fit: BoxFit.cover)
                      : StorageImage(
                          bucket: StorageBucket.profilePhotos,
                          path: keptPath!,
                        ),
                ),
              ),
            ),
          ),
          TextButton(
            onPressed: widget.isSaving
                ? null
                : () => setState(() {
                    _newPhoto = null;
                    _keptPath = null;
                  }),
            child: Text(l10n.pagePhotoChooseAnother),
          ),
          TextField(
            controller: _caption,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: limitedTextDecoration(
              context,
              label: l10n.pageCaptionLabel,
              text: _caption.text,
              max: BusinessRules.pageCaptionMaxLength,
            ),
          ),
        ],
      ],
    );
  }
}
