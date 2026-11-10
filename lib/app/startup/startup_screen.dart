import 'package:evasion/app/router/access_status.dart';
import 'package:evasion/features/profile/presentation/own_profile.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shown while the profile of the signed-in user loads, to decide between the
/// onboarding and the app; offers a retry if loading failed.
class StartupScreen extends ConsumerWidget {
  const StartupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final hasFailed =
        ref.watch(accessStatusProvider) == AccessStatus.profileError;
    return Scaffold(
      body: Center(
        child: hasFailed
            ? Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 16,
                children: [
                  Text(l10n.startupProfileError),
                  FilledButton(
                    onPressed: () => ref.invalidate(ownProfileProvider),
                    child: Text(l10n.retry),
                  ),
                ],
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}
