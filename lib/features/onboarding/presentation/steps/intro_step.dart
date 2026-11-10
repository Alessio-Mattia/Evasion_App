import 'package:evasion/core/widgets/form_page_layout.dart';
import 'package:evasion/features/onboarding/presentation/onboarding_app_bar.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// Explains the three principles of the app before the questions.
class IntroStep extends StatelessWidget {
  const IntroStep({required this.onContinue, super.key});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FormPageLayout(
      appBar: const OnboardingAppBar(),
      title: l10n.onboardingIntroTitle,
      subtitle: l10n.onboardingIntroSubtitle,
      children: [
        _Principle(
          icon: Icons.handshake_outlined,
          title: l10n.onboardingPrincipleRealTitle,
          body: l10n.onboardingPrincipleRealBody,
        ),
        _Principle(
          icon: Icons.balance_outlined,
          title: l10n.onboardingPrincipleEqualTitle,
          body: l10n.onboardingPrincipleEqualBody,
        ),
        _Principle(
          icon: Icons.lock_outline,
          title: l10n.onboardingPrinciplePrivacyTitle,
          body: l10n.onboardingPrinciplePrivacyBody,
        ),
        LoadingButton(
          label: l10n.onboardingStart,
          isLoading: false,
          onPressed: onContinue,
        ),
      ],
    );
  }
}

class _Principle extends StatelessWidget {
  const _Principle({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(body),
    );
  }
}
