import 'dart:math';

import 'package:evasion/core/config/business_rules.dart';

enum DisplayNameError { empty, tooLong }

/// Checks a display name the way the server does: not blank, and at most
/// [BusinessRules.displayNameMaxLength] code points once trimmed.
DisplayNameError? validateDisplayName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return DisplayNameError.empty;
  if (trimmed.runes.length > BusinessRules.displayNameMaxLength) {
    return DisplayNameError.tooLong;
  }
  return null;
}

/// Most recent birth date allowed on [today]: the user must be at least
/// [BusinessRules.minimumAge].
DateTime latestAllowedBirthDate(DateTime today) =>
    _yearsBefore(today, BusinessRules.minimumAge);

/// Oldest birth date allowed on [today], to catch typing mistakes.
DateTime earliestAllowedBirthDate(DateTime today) =>
    _yearsBefore(today, BusinessRules.maximumAge);

bool isAllowedBirthDate(DateTime birthDate, DateTime today) {
  final day = DateTime(birthDate.year, birthDate.month, birthDate.day);
  return !day.isAfter(latestAllowedBirthDate(today)) &&
      !day.isBefore(earliestAllowedBirthDate(today));
}

/// Same day [years] earlier. A 29 February becomes the 28th in a common year,
/// as `current_date - interval 'N years'` does in Postgres.
DateTime _yearsBefore(DateTime day, int years) {
  final year = day.year - years;
  final lastDayOfMonth = DateTime(year, day.month + 1, 0).day;
  return DateTime(year, day.month, min(day.day, lastDayOfMonth));
}

/// Whether [text], once trimmed, has at most [max] code points, as the server
/// counts them with `char_length`.
bool fitsLength(String text, int max) => text.trim().runes.length <= max;
