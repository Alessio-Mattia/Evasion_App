import 'package:evasion/core/config/business_rules.dart';
import 'package:evasion/core/models/interest.dart';
import 'package:evasion/features/profile/domain/page_draft.dart';
import 'package:evasion/features/profile/domain/profile_page.dart';
import 'package:evasion/features/profile/presentation/editor/page_editor_scaffold.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// Editor of an interests page: chips to tick, kept in the order chosen.
class InterestsPageForm extends StatefulWidget {
  const InterestsPageForm({
    required this.isSaving,
    required this.onSave,
    this.initial,
    super.key,
  });

  /// The page being edited, or null for a new one.
  final InterestsPage? initial;
  final bool isSaving;
  final ValueChanged<PageDraft> onSave;

  @override
  State<InterestsPageForm> createState() => _InterestsPageFormState();
}

class _InterestsPageFormState extends State<InterestsPageForm> {
  late final List<Interest> _selected = [...?widget.initial?.interests];

  void _toggle(Interest interest) => setState(() {
    if (!_selected.remove(interest)) _selected.add(interest);
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const max = BusinessRules.interestsMaxPerPage;
    final isFull = _selected.length >= max;

    return PageEditorScaffold(
      isNew: widget.initial == null,
      isSaving: widget.isSaving,
      onSave: areInterestsValid(_selected)
          ? () => widget.onSave(InterestsPageDraft([..._selected]))
          : null,
      children: [
        Text(l10n.pageInterestsHelp(max)),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final interest in Interest.values)
              FilterChip(
                label: Text(interest.label(l10n)),
                selected: _selected.contains(interest),
                onSelected: isFull && !_selected.contains(interest)
                    ? null
                    : (_) => _toggle(interest),
              ),
          ],
        ),
        Text(
          l10n.lengthCounter(_selected.length, max),
          textAlign: TextAlign.end,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
