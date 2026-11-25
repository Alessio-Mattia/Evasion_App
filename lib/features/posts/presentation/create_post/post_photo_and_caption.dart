import 'dart:typed_data';

import 'package:evasion/app/theme/app_colors.dart';
import 'package:evasion/core/config/business_rules.dart';
import 'package:evasion/core/widgets/limited_text_decoration.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// The 4:5 photo of the post, tappable to choose it, beside its caption.
class PostPhotoAndCaption extends StatelessWidget {
  const PostPhotoAndCaption({
    required this.photo,
    required this.caption,
    required this.onPickPhoto,
    required this.onCaptionChanged,
    super.key,
  });

  final Uint8List? photo;
  final TextEditingController caption;
  final VoidCallback? onPickPhoto;
  final VoidCallback onCaptionChanged;

  static const double _photoWidth = 128;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final photo = this.photo;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 14,
      children: [
        Semantics(
          button: true,
          label: photo == null
              ? l10n.createPostAddPhoto
              : l10n.createPostChangePhoto,
          child: InkWell(
            onTap: onPickPhoto,
            borderRadius: BorderRadius.circular(AppRadii.field),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.field),
              child: SizedBox(
                width: _photoWidth,
                height: _photoWidth * 5 / 4,
                child: photo == null
                    ? ColoredBox(
                        color: colors.surfaceContainerHighest,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          spacing: 8,
                          children: [
                            Icon(
                              Icons.add_a_photo_outlined,
                              color: colors.primary,
                            ),
                            Text(
                              l10n.createPostAddPhoto,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ],
                        ),
                      )
                    : Image.memory(photo, fit: BoxFit.cover),
              ),
            ),
          ),
        ),
        Expanded(
          child: TextField(
            controller: caption,
            minLines: 5,
            maxLines: 7,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => onCaptionChanged(),
            decoration: limitedTextDecoration(
              context,
              label: l10n.createPostCaptionLabel,
              text: caption.text,
              max: BusinessRules.postCaptionMaxLength,
            ),
          ),
        ),
      ],
    );
  }
}
