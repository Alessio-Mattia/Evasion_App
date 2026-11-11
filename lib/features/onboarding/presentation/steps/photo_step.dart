import 'dart:typed_data';

import 'package:evasion/core/services/photo_picker.dart';
import 'package:evasion/core/widgets/failure_snack_bar.dart';
import 'package:evasion/core/widgets/form_page_layout.dart';
import 'package:evasion/features/onboarding/domain/profile_photo.dart';
import 'package:evasion/features/onboarding/presentation/onboarding_app_bar.dart';
import 'package:evasion/features/onboarding/presentation/onboarding_controllers.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Last step: a real photo of the user, cropped square and shown round.
class PhotoStep extends ConsumerStatefulWidget {
  const PhotoStep({required this.onPhotoSaved, super.key});

  /// Called once the photo is saved: the profile is then complete.
  final VoidCallback onPhotoSaved;

  @override
  ConsumerState<PhotoStep> createState() => _PhotoStepState();
}

class _PhotoStepState extends ConsumerState<PhotoStep> {
  Uint8List? _photo;

  Future<void> _pick(PhotoSource source) async {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final appearance = CropAppearance(
      title: l10n.onboardingPhotoCropTitle,
      toolbarColor: colors.surface,
      toolbarForeground: colors.onSurface,
      backgroundColor: colors.surface,
      accentColor: colors.primary,
    );

    final Uint8List? picked;
    try {
      picked = await ref
          .read(photoPickerProvider)
          .pickSquarePhoto(source, appearance);
    } on PhotoAccessDenied {
      if (mounted) _showMessage(l10n.photoAccessDenied);
      return;
    } on Object catch (error) {
      if (mounted) showFailureSnackBar(context, error);
      return;
    }
    if (picked == null || !mounted) return;

    switch (checkPhoto(picked)) {
      case PhotoProblem.unsupportedFormat:
        _showMessage(l10n.photoUnsupportedFormat);
      case PhotoProblem.tooLarge:
        _showMessage(l10n.photoTooLarge);
      case null:
        setState(() => _photo = picked);
    }
  }

  Future<void> _confirm() async {
    final photo = _photo;
    if (photo == null || ref.read(savePhotoControllerProvider).isLoading) {
      return;
    }
    final saved = await ref
        .read(savePhotoControllerProvider.notifier)
        .save(photo, detectPhotoFormat(photo)!);
    if (saved) widget.onPhotoSaved();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isSaving = ref.watch(savePhotoControllerProvider).isLoading;
    ref.listen(savePhotoControllerProvider, (_, next) {
      if (next case AsyncError(:final error)) {
        showFailureSnackBar(context, error);
      }
    });
    final photo = _photo;

    return FormPageLayout(
      appBar: const OnboardingAppBar(),
      title: l10n.onboardingPhotoTitle,
      subtitle: l10n.onboardingPhotoSubtitle,
      children: [
        if (photo == null) ...[
          OutlinedButton.icon(
            onPressed: () => _pick(PhotoSource.gallery),
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(l10n.onboardingPhotoGallery),
          ),
          OutlinedButton.icon(
            onPressed: () => _pick(PhotoSource.camera),
            icon: const Icon(Icons.photo_camera_outlined),
            label: Text(l10n.onboardingPhotoCamera),
          ),
        ] else ...[
          Center(
            child: CircleAvatar(
              radius: 96,
              backgroundImage: MemoryImage(photo),
            ),
          ),
          LoadingButton(
            label: l10n.onboardingPhotoConfirm,
            isLoading: isSaving,
            onPressed: _confirm,
          ),
          TextButton(
            onPressed: isSaving ? null : () => setState(() => _photo = null),
            child: Text(l10n.onboardingPhotoChooseAnother),
          ),
        ],
      ],
    );
  }
}
