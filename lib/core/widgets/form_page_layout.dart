import 'package:flutter/material.dart';

/// Frame of a form screen (sign-in, onboarding): a title, an explanation, then
/// the form, centered and scrollable when the keyboard is open.
class FormPageLayout extends StatelessWidget {
  const FormPageLayout({
    required this.title,
    required this.subtitle,
    required this.children,
    this.appBar,
    super.key,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final PreferredSizeWidget? appBar;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: appBar,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16,
                children: [
                  Text(title, style: textTheme.headlineMedium),
                  Text(subtitle, style: textTheme.bodyLarge),
                  const SizedBox(height: 8),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Main button of a form, replaced by a spinner while it works.
class LoadingButton extends StatelessWidget {
  const LoadingButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
    this.isDestructive = false,
    super.key,
  });

  final String label;
  final bool isLoading;

  /// Shows the button in the error colours, for an action that cannot be
  /// undone.
  final bool isDestructive;

  /// Null disables the button, for example while the form is not filled.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return FilledButton(
      onPressed: isLoading ? null : onPressed,
      style: isDestructive
          ? FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
            )
          : null,
      child: isLoading
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
  }
}
