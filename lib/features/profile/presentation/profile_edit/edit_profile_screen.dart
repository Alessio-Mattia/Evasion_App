import 'dart:async';

import 'package:evasion/core/widgets/failure_snack_bar.dart';
import 'package:evasion/core/widgets/form_page_layout.dart';
import 'package:evasion/features/profile/domain/profile.dart';
import 'package:evasion/features/profile/domain/profile_details.dart';
import 'package:evasion/features/profile/presentation/own_profile.dart';
import 'package:evasion/features/profile/presentation/profile_edit/avatar_editor.dart';
import 'package:evasion/features/profile/presentation/profile_edit/birth_date_row.dart';
import 'package:evasion/features/profile/presentation/profile_edit/profile_edit_controllers.dart';
import 'package:evasion/features/profile/presentation/profile_edit/profile_edit_dialogs.dart';
import 'package:evasion/features/profile/presentation/profile_edit/profile_text_fields.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Edits the profile of [userId]: photo, texts and birth date.
class EditProfileScreen extends ConsumerWidget {
  const EditProfileScreen({required this.userId, super.key});

  /// Provided by the router, so that this feature does not depend on auth.
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(ownProfileProvider(userId))) {
      AsyncValue(:final value?) => _EditProfileForm(profile: value),
      AsyncValue(:final error?) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              failureMessage(context, error),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }
}

class _EditProfileForm extends ConsumerStatefulWidget {
  const _EditProfileForm({required this.profile});

  /// Kept up to date: it changes after a new photo or birth date is saved.
  final Profile profile;

  @override
  ConsumerState<_EditProfileForm> createState() => _EditProfileFormState();
}

class _EditProfileFormState extends ConsumerState<_EditProfileForm> {
  // The texts as the screen opened; the user's typing is then kept, even when
  // the profile reloads after a new photo.
  late final _displayName = TextEditingController(
    text: widget.profile.displayName,
  );
  late final _occupation = TextEditingController(
    text: widget.profile.occupation,
  );
  late final _university = TextEditingController(
    text: widget.profile.university,
  );
  late final _bio = TextEditingController(text: widget.profile.bio);

  @override
  void dispose() {
    for (final controller in [_displayName, _occupation, _university, _bio]) {
      controller.dispose();
    }
    super.dispose();
  }

  ProfileDetails get _details => ProfileDetails(
    displayName: _displayName.text,
    occupation: _occupation.text,
    university: _university.text,
    bio: _bio.text,
  );

  Future<void> _save(ProfileDetails details) async {
    final saved = await ref
        .read(saveDetailsControllerProvider(widget.profile.id).notifier)
        .save(details);
    // Navigator.pop, unlike a back gesture, does not ask the PopScope.
    if (saved && mounted) Navigator.of(context).pop();
  }

  Future<void> _confirmLeaving() async {
    if (await confirmDiscardChanges(context) && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = saveDetailsControllerProvider(widget.profile.id);
    ref.listen(provider, (_, next) {
      if (next case AsyncError(:final error)) {
        showFailureSnackBar(context, error);
      }
    });
    final isSaving = ref.watch(provider).isLoading;
    final details = _details;
    final hasChanges = details != ProfileDetails.of(widget.profile);

    return PopScope(
      // A back gesture with unsaved texts asks first.
      canPop: !hasChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_confirmLeaving());
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.profileEditTitle)),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    AvatarEditor(
                      userId: widget.profile.id,
                      avatarPath: widget.profile.avatarPath,
                    ),
                    const SizedBox(height: 24),
                    ProfileTextFields(
                      displayName: _displayName,
                      occupation: _occupation,
                      university: _university,
                      bio: _bio,
                      onChanged: () => setState(() {}),
                    ),
                    const SizedBox(height: 8),
                    BirthDateRow(profile: widget.profile),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: LoadingButton(
                  label: l10n.profileEditSave,
                  isLoading: isSaving,
                  onPressed: hasChanges && details.isValid
                      ? () => _save(details)
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
