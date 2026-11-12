import 'package:evasion/core/config/business_rules.dart';
import 'package:evasion/features/profile/domain/page_draft.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// Lets the user choose the template of a new page. Returns null if they
/// closed the sheet.
Future<PageType?> choosePageType(BuildContext context) {
  return showModalBottomSheet<PageType>(
    context: context,
    showDragHandle: true,
    // As tall as the options need, up to the full screen on small phones.
    isScrollControlled: true,
    builder: (context) {
      final l10n = AppLocalizations.of(context);
      ListTile option(
        PageType type,
        IconData icon,
        String title,
        String hint,
      ) => ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(hint),
        onTap: () => Navigator.pop(context, type),
      );

      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.profilePageTypeTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              option(
                PageType.text,
                Icons.notes,
                l10n.profilePageTypeText,
                l10n.profilePageTypeTextHint,
              ),
              option(
                PageType.photo,
                Icons.photo_outlined,
                l10n.profilePageTypePhoto,
                l10n.profilePageTypePhotoHint,
              ),
              option(
                PageType.interests,
                Icons.interests_outlined,
                l10n.profilePageTypeInterests,
                l10n.profilePageTypeInterestsHint(
                  BusinessRules.interestsMaxPerPage,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}
