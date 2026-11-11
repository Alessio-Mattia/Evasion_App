import 'package:evasion/core/widgets/failure_snack_bar.dart';
import 'package:evasion/features/settings/domain/user_settings.dart';
import 'package:evasion/features/settings/presentation/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A titled group of settings.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    required this.title,
    required this.children,
    this.hint,
    super.key,
  });

  final String title;
  final String? hint;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Text(title, style: textTheme.titleMedium),
          if (hint case final hint?) Text(hint, style: textTheme.bodySmall),
          ...children,
        ],
      ),
    );
  }
}

/// Applies [change] and saves it; shows the failure if saving failed, in which
/// case the screen goes back to the saved value.
Future<void> changeSettings(
  BuildContext context,
  WidgetRef ref,
  UserSettings Function(UserSettings current) change,
) async {
  final failure = await ref
      .read(settingsControllerProvider.notifier)
      .change(change);
  if (failure != null && context.mounted) {
    showFailureSnackBar(context, failure);
  }
}
