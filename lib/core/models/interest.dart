import 'package:evasion/l10n/generated/app_localizations.dart';

/// Predefined interests shown on the profile carousel.
///
/// The codes match `private.is_interest_list` in SQL. Adding one needs a
/// migration and an app update, so the app must tolerate codes it does not
/// know: an older version simply shows one interest less.
enum Interest {
  sport,
  music,
  movies,
  reading,
  travel,
  cooking,
  gaming,
  art,
  nature,
  nightlife,
  technology,
  photography,
  volunteering;

  /// Value stored in the database.
  String get code => name;

  /// The interest for [code], or null when this version of the app does not
  /// know it.
  static Interest? fromCode(String code) {
    for (final interest in values) {
      if (interest.code == code) return interest;
    }
    return null;
  }

  /// Known interests of [codes], in their order; unknown codes are skipped.
  static List<Interest> fromCodes(Iterable<String> codes) => [
    for (final code in codes) ?fromCode(code),
  ];

  String label(AppLocalizations l10n) => switch (this) {
    Interest.sport => l10n.interestSport,
    Interest.music => l10n.interestMusic,
    Interest.movies => l10n.interestMovies,
    Interest.reading => l10n.interestReading,
    Interest.travel => l10n.interestTravel,
    Interest.cooking => l10n.interestCooking,
    Interest.gaming => l10n.interestGaming,
    Interest.art => l10n.interestArt,
    Interest.nature => l10n.interestNature,
    Interest.nightlife => l10n.interestNightlife,
    Interest.technology => l10n.interestTechnology,
    Interest.photography => l10n.interestPhotography,
    Interest.volunteering => l10n.interestVolunteering,
  };
}
