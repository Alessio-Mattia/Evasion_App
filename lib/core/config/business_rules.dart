/// Product thresholds, in one place.
///
/// All values are provisional until the product decisions are made, and can
/// be changed here freely. The server enforces its own copy of the values
/// marked "Also enforced in SQL": when changing one, add a migration that
/// updates the SQL side too, so that both stay in sync.
abstract final class BusinessRules {
  // Account

  /// Minimum age to sign up, from the terms of use.
  static const int minimumAge = 18;

  /// Oldest accepted age, to catch typing mistakes in the birth date.
  /// Also enforced in SQL (birth date trigger).
  static const int maximumAge = 120;

  /// Number of digits of the sign-in code sent by email. Also configured in
  /// Supabase: `otp_length` in supabase/config.toml and in the dashboard.
  static const int signInCodeLength = 6;

  // Profile
  //
  // Text lengths are counted in Unicode code points, like Postgres
  // `char_length`: check them with `String.runes.length`, not
  // `String.length`. An emoji such as 👨‍👩‍👧 shows as one character but
  // counts as several code points.

  /// Also enforced in SQL.
  static const int displayNameMaxLength = 50;

  /// Also enforced in SQL.
  static const int bioMaxLength = 500;

  /// Also enforced in SQL.
  static const int occupationMaxLength = 100;

  /// Also enforced in SQL.
  static const int universityMaxLength = 100;

  /// Largest profile photo, in bytes. Also enforced in SQL (avatars bucket).
  static const int avatarMaxBytes = 5 * 1024 * 1024;

  /// Accepted profile photo formats. Also enforced in SQL (avatars bucket).
  /// HEIC is excluded, since Android cannot display it: convert to JPEG.
  static const List<String> avatarMimeTypes = [
    'image/jpeg',
    'image/png',
    'image/webp',
  ];

  // Encounters

  /// Default detection radius of a new user, editable in the settings.
  static const int defaultDetectionRadiusMeters = 100;

  /// Largest detection radius a user can choose. Also enforced in SQL.
  static const int maxDetectionRadiusMeters = 5000;

  /// How long raw positions are kept before being purged.
  /// Also enforced in SQL (purge job).
  static const Duration rawLocationRetention = Duration(hours: 24);

  // Meetups, likes and matches

  /// How long a validated meetup unlocks the like between two people.
  /// Also enforced in SQL.
  static const Duration meetupLikeUnlockDuration = Duration(days: 7);

  /// Messages each person can send after a match, recharged by a new meetup.
  /// Also enforced in SQL (messages trigger).
  static const int messageQuotaPerMatch = 20;

  // Posts

  /// Radius of the fuzzy area shown instead of the post's exact location.
  /// Also enforced in SQL (blurring).
  static const int postFuzzyRadiusMeters = 300;

  /// Maximum distance between a chosen post location and the author's real
  /// position, to prevent fake posts. Also enforced in SQL.
  static const int postChosenLocationMaxDistanceMeters = 5000;
}
