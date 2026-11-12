import 'package:evasion/core/widgets/form_page_layout.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// Frame of a page editor: the form, then the save button at the bottom.
class PageEditorScaffold extends StatelessWidget {
  const PageEditorScaffold({
    required this.isSaving,
    required this.onSave,
    required this.children,
    super.key,
  });

  final bool isSaving;

  /// Null while the page cannot be saved yet.
  final VoidCallback? onSave;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.pageEditorNewTitle)),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final child in children)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: child,
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: LoadingButton(
                label: l10n.pageEditorAdd,
                isLoading: isSaving,
                onPressed: onSave,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Counter and error of a text limited to [max] code points, like the server
/// counts them.
InputDecoration limitedTextDecoration(
  BuildContext context, {
  required String label,
  required String text,
  required int max,
}) {
  final l10n = AppLocalizations.of(context);
  final length = text.trim().runes.length;
  return InputDecoration(
    labelText: label,
    alignLabelWithHint: true,
    border: const OutlineInputBorder(),
    counterText: l10n.lengthCounter(length, max),
    errorText: length > max ? l10n.pageTextTooLong(max) : null,
  );
}
