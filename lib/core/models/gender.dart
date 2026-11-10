import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:json_annotation/json_annotation.dart';

/// Gender of a user, used in profiles and in encounter criteria.
///
/// The JSON values match the `gender` check constraint in SQL.
enum Gender {
  @JsonValue('woman')
  woman,
  @JsonValue('man')
  man,
  @JsonValue('other')
  other;

  /// Value stored in the database.
  String get databaseValue => name;

  String label(AppLocalizations l10n) => switch (this) {
    Gender.woman => l10n.genderWoman,
    Gender.man => l10n.genderMan,
    Gender.other => l10n.genderOther,
  };
}
