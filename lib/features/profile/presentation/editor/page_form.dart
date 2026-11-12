import 'package:evasion/features/profile/domain/page_draft.dart';
import 'package:evasion/features/profile/domain/profile_page.dart';
import 'package:evasion/features/profile/presentation/editor/interests_page_form.dart';
import 'package:evasion/features/profile/presentation/editor/photo_page_form.dart';
import 'package:evasion/features/profile/presentation/editor/text_page_form.dart';
import 'package:flutter/widgets.dart';

/// The editor of a [type] page: a new one, or [initial] filled in.
Widget pageForm({
  required PageType type,
  required bool isSaving,
  required ValueChanged<PageDraft> onSave,
  ProfilePage? initial,
}) => switch ((type, initial)) {
  (PageType.text, final TextPage? page) => TextPageForm(
    initial: page,
    isSaving: isSaving,
    onSave: onSave,
  ),
  (PageType.photo, final PhotoPage? page) => PhotoPageForm(
    initial: page,
    isSaving: isSaving,
    onSave: onSave,
  ),
  (PageType.interests, final InterestsPage? page) => InterestsPageForm(
    initial: page,
    isSaving: isSaving,
    onSave: onSave,
  ),
  // A page always has the type it is opened with.
  _ => throw ArgumentError.value(initial, 'initial', 'not a $type page'),
};
