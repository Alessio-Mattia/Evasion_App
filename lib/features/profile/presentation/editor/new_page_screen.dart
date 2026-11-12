import 'package:evasion/core/widgets/failure_snack_bar.dart';
import 'package:evasion/features/profile/domain/page_draft.dart';
import 'package:evasion/features/profile/presentation/editor/interests_page_form.dart';
import 'package:evasion/features/profile/presentation/editor/photo_page_form.dart';
import 'package:evasion/features/profile/presentation/editor/text_page_form.dart';
import 'package:evasion/features/profile/presentation/page_editing_controllers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Creates a page of [type] at the end of the carousel of [userId], then goes
/// back to the profile.
class NewPageScreen extends ConsumerWidget {
  const NewPageScreen({required this.userId, required this.type, super.key});

  /// Provided by the router, so that this feature does not depend on auth.
  final String userId;
  final PageType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = addPageControllerProvider(userId);
    final isSaving = ref.watch(provider).isLoading;
    ref.listen(provider, (_, next) {
      if (next case AsyncError(:final error)) {
        showFailureSnackBar(context, error);
      }
    });

    Future<void> save(PageDraft draft) async {
      final added = await ref.read(provider.notifier).add(draft);
      if (added && context.mounted) context.pop();
    }

    return switch (type) {
      PageType.text => TextPageForm(isSaving: isSaving, onSave: save),
      PageType.photo => PhotoPageForm(isSaving: isSaving, onSave: save),
      PageType.interests => InterestsPageForm(isSaving: isSaving, onSave: save),
    };
  }
}
