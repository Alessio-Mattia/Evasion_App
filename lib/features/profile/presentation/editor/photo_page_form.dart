import 'dart:typed_data';

import 'package:evasion/core/config/business_rules.dart';
import 'package:evasion/core/photos/photo_file.dart';
import 'package:evasion/core/services/photo_picker.dart';
import 'package:evasion/core/widgets/pick_photo.dart';
import 'package:evasion/features/profile/domain/page_draft.dart';
import 'package:evasion/features/profile/presentation/editor/page_editor_scaffold.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Editor of a photo page: a portrait photo, then an optional caption.
class PhotoPageForm extends ConsumerStatefulWidget {
  const PhotoPageForm({
    required this.isSaving,
    required this.onSave,
    super.key,
  });

  final bool isSaving;
  final ValueChanged<PageDraft> onSave;

  @override
  ConsumerState<PhotoPageForm> createState() => _PhotoPageFormState();
}

class _PhotoPageFormState extends ConsumerState<PhotoPageForm> {
  final _caption = TextEditingController();
  Uint8List? _photo;

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
    if (picked != null && mounted) setState(() => _photo = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final photo = _photo;
    final caption = _caption.text;

    return PageEditorScaffold(
      isSaving: widget.isSaving,
      onSave: photo != null && !isCaptionTooLong(caption)
          ? () => widget.onSave(
              PhotoPageDraft(
                bytes: photo,
                format: detectPhotoFormat(photo)!,
                caption: caption,
              ),
            )
          : null,
      children: [
        if (photo == null) ...[
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
                  child: Image.memory(photo, fit: BoxFit.cover),
                ),
              ),
            ),
          ),
          TextButton(
            onPressed: widget.isSaving
                ? null
                : () => setState(() => _photo = null),
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
              text: caption,
              max: BusinessRules.pageCaptionMaxLength,
            ),
          ),
        ],
      ],
    );
  }
}
