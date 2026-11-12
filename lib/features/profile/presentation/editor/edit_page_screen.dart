import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/core/widgets/failure_snack_bar.dart';
import 'package:evasion/features/profile/domain/page_draft.dart';
import 'package:evasion/features/profile/presentation/editor/page_form.dart';
import 'package:evasion/features/profile/presentation/own_profile.dart';
import 'package:evasion/features/profile/presentation/page_editing_controllers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Edits the page [pageId] of [userId], then goes back to the profile.
class EditPageScreen extends ConsumerWidget {
  const EditPageScreen({required this.userId, required this.pageId, super.key});

  /// Provided by the router, so that this feature does not depend on auth.
  final String userId;
  final String pageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = updatePageControllerProvider(userId);
    ref.listen(provider, (_, next) {
      if (next case AsyncError(:final error)) {
        showFailureSnackBar(context, error);
      }
    });

    return switch (ref.watch(ownPagesProvider(userId))) {
      AsyncValue(:final value?) => switch ([
        for (final page in value)
          if (page.id == pageId) page,
      ]) {
        [final page] => pageForm(
          type: page.type,
          initial: page,
          isSaving: ref.watch(provider).isLoading,
          onSave: (draft) async {
            final saved = await ref.read(provider.notifier).save(page, draft);
            if (saved && context.mounted) context.pop();
          },
        ),
        // Deleted meanwhile, for example from another phone.
        _ => _Message(failureMessage(context, const NotFoundFailure())),
      },
      AsyncValue(:final error?) => _Message(failureMessage(context, error)),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(text, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
