import 'package:evasion/core/widgets/form_page_layout.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// Frame of a page editor: the form, then the save button at the bottom.
class PageEditorScaffold extends StatelessWidget {
  const PageEditorScaffold({
    required this.isNew,
    required this.isSaving,
    required this.onSave,
    required this.children,
    super.key,
  });

  /// Whether the page is being created, rather than edited.
  final bool isNew;
  final bool isSaving;

  /// Null while the page cannot be saved yet.
  final VoidCallback? onSave;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? l10n.pageEditorNewTitle : l10n.pageEditorEditTitle),
      ),
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
                label: isNew ? l10n.pageEditorAdd : l10n.pageEditorSave,
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
