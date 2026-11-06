import 'package:evasion/core/widgets/failure_snack_bar.dart';
import 'package:evasion/features/auth/presentation/sign_in_controllers.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Signs the user out; the router then shows the sign-in screen.
class SignOutButton extends ConsumerWidget {
  const SignOutButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(signOutControllerProvider).isLoading;
    ref.listen(signOutControllerProvider, (_, next) {
      if (next case AsyncError(:final error)) {
        showFailureSnackBar(context, error);
      }
    });

    return OutlinedButton(
      onPressed: isLoading
          ? null
          : () => ref.read(signOutControllerProvider.notifier).signOut(),
      child: Text(AppLocalizations.of(context).signOut),
    );
  }
}
