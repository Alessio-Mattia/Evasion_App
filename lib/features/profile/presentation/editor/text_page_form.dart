import 'package:evasion/core/config/business_rules.dart';
import 'package:evasion/core/widgets/limited_text_decoration.dart';
import 'package:evasion/features/profile/domain/page_draft.dart';
import 'package:evasion/features/profile/domain/profile_page.dart';
import 'package:evasion/features/profile/presentation/editor/page_editor_scaffold.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// Editor of a text page.
class TextPageForm extends StatefulWidget {
  const TextPageForm({
    required this.isSaving,
    required this.onSave,
    this.initial,
    super.key,
  });

  /// The page being edited, or null for a new one.
  final TextPage? initial;
  final bool isSaving;
  final ValueChanged<PageDraft> onSave;

  @override
  State<TextPageForm> createState() => _TextPageFormState();
}

class _TextPageFormState extends State<TextPageForm> {
  late final _text = TextEditingController(text: widget.initial?.text);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _text.text;
    return PageEditorScaffold(
      isNew: widget.initial == null,
      isSaving: widget.isSaving,
      onSave: checkPageText(text) == null
          ? () => widget.onSave(TextPageDraft(text))
          : null,
      children: [
        TextField(
          controller: _text,
          autofocus: true,
          minLines: 5,
          maxLines: 10,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
          decoration: limitedTextDecoration(
            context,
            label: AppLocalizations.of(context).pageTextLabel,
            text: text,
            max: BusinessRules.pageTextMaxLength,
          ),
        ),
      ],
    );
  }
}
