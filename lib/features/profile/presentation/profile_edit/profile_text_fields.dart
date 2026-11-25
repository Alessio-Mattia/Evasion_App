import 'package:evasion/core/config/business_rules.dart';
import 'package:evasion/core/validation/profile_validators.dart';
import 'package:evasion/core/widgets/limited_text_decoration.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// The texts of the profile, each with its counter and its error.
class ProfileTextFields extends StatelessWidget {
  const ProfileTextFields({
    required this.displayName,
    required this.occupation,
    required this.university,
    required this.bio,
    required this.onChanged,
    super.key,
  });

  final TextEditingController displayName;
  final TextEditingController occupation;
  final TextEditingController university;
  final TextEditingController bio;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    InputDecoration decoration(
      TextEditingController controller,
      String label,
      int max,
    ) => limitedTextDecoration(
      context,
      label: label,
      text: controller.text,
      max: max,
    );

    final nameDecoration = decoration(
      displayName,
      l10n.profileEditNameLabel,
      BusinessRules.displayNameMaxLength,
    );

    return Column(
      spacing: 16,
      children: [
        TextField(
          controller: displayName,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => onChanged(),
          decoration:
              validateDisplayName(displayName.text) == DisplayNameError.empty
              ? nameDecoration.copyWith(errorText: l10n.profileEditNameEmpty)
              : nameDecoration,
        ),
        TextField(
          controller: occupation,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => onChanged(),
          decoration: decoration(
            occupation,
            l10n.profileEditOccupationLabel,
            BusinessRules.occupationMaxLength,
          ),
        ),
        TextField(
          controller: university,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => onChanged(),
          decoration: decoration(
            university,
            l10n.profileEditUniversityLabel,
            BusinessRules.universityMaxLength,
          ),
        ),
        TextField(
          controller: bio,
          minLines: 3,
          maxLines: 8,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => onChanged(),
          decoration: decoration(
            bio,
            l10n.profileEditBioLabel,
            BusinessRules.bioMaxLength,
          ),
        ),
      ],
    );
  }
}
