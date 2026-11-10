import 'package:evasion/core/widgets/form_page_layout.dart';
import 'package:evasion/features/onboarding/presentation/onboarding_app_bar.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// Last step. Temporary: the photo upload needs the `avatars` storage bucket,
/// and comes in the next pull request.
class PhotoStep extends StatelessWidget {
  const PhotoStep({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FormPageLayout(
      appBar: const OnboardingAppBar(),
      title: l10n.onboardingPhotoTitle,
      subtitle: l10n.onboardingPhotoComingSoon,
      children: const [],
    );
  }
}
