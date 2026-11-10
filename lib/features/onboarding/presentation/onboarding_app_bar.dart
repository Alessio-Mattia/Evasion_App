import 'package:evasion/features/onboarding/presentation/onboarding_controllers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Back button and progress bar shown above each onboarding step.
class OnboardingAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const OnboardingAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 4);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingControllerProvider).value;
    final index = state?.index ?? 0;
    final count = state?.steps.length ?? 1;
    return AppBar(
      automaticallyImplyLeading: false,
      leading: index > 0
          ? BackButton(
              onPressed: () =>
                  ref.read(onboardingControllerProvider.notifier).back(),
            )
          : null,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(4),
        child: LinearProgressIndicator(value: (index + 1) / count),
      ),
    );
  }
}
