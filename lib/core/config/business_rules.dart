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

  /// How long after entering an email code the account can be deleted.
  /// Also enforced by the delete-account Edge Function
  /// (REAUTH_WINDOW_SECONDS).
  static const Duration accountDeletionReauthWindow = Duration(minutes: 5);

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

  /// Side of the square profile photo sent by the app, in pixels. App side
  /// only: large enough for a sharp photo, small enough to upload quickly.
  static const int avatarSizePixels = 1080;

  /// How long a link to a private photo stays valid. A leaked link stops
  /// working after it, and a block takes effect on the next link. App side
  /// only.
  static const Duration signedUrlLifetime = Duration(hours: 1);

  // Profile carousel
  //
  // The first page is built from the profile; users add up to
  // profilePagesMax more, so 6 pages in all.

  /// Free pages a user can add. Also enforced in SQL.
  static const int profilePagesMax = 5;

  /// Also enforced in SQL. Counted in code points, like the texts above.
  static const int pageTextMaxLength = 300;

  /// Also enforced in SQL. Counted in code points, like the texts above.
  static const int pageCaptionMaxLength = 100;

  /// Also enforced in SQL.
  static const int interestsMaxPerPage = 10;

  /// Largest page photo, in bytes. Also enforced in SQL (profile-photos
  /// bucket).
  static const int profilePhotoMaxBytes = avatarMaxBytes;

  /// Size of a page photo sent by the app, in pixels: portrait 4:5, the
  /// shape of the carousel cards. App side only.
  static const int pagePhotoWidthPixels = 1080;
  static const int pagePhotoHeightPixels = 1350;

  /// Accepted page photo formats. Also enforced in SQL (profile-photos
  /// bucket).
  static const List<String> profilePhotoMimeTypes = avatarMimeTypes;

  // Encounters

  /// Default detection radius of a new user, editable in the settings.
  static const int defaultDetectionRadiusMeters = 100;

  /// Largest detection radius a user can choose. Also enforced in SQL.
  static const int maxDetectionRadiusMeters = 5000;

  /// Smallest detection radius offered by the app. App side only: below it,
  /// indoor GPS accuracy (10 to 50 m) makes the setting meaningless.
  static const int minDetectionRadiusMeters = 50;

  /// Top of the age preference slider; its last position means "no maximum"
  /// (`pref_age_max` null). App side only.
  static const int prefAgeSliderMax = 80;

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

  /// Side of the grid cells of fuzzy posts: a fuzzy post shows at the centre
  /// of its cell, so at most about 0.7 times this distance from its real
  /// point. Also enforced in SQL (private.fuzzy_point).
  static const int postFuzzyCellSizeMeters = 300;

  /// Maximum distance between a chosen post location and the author's real
  /// position, to prevent fake posts. Also enforced in SQL.
  static const int postChosenLocationMaxDistanceMeters = 5000;

  /// Lifetime of a post when the author does not choose one.
  /// Also the default in SQL (create_post).
  static const Duration postDefaultLifetime = Duration(hours: 24);

  /// Shortest and longest lifetime of a post, counted from its creation, also
  /// when the author changes it later. Also enforced in SQL.
  static const Duration postMinLifetime = Duration(hours: 1);
  static const Duration postMaxLifetime = Duration(days: 30);

  /// Posts a user can have at once; expired posts do not count.
  /// Also enforced in SQL (create_post).
  static const int activePostsMax = 5;

  /// Also enforced in SQL. Counted in code points, like the texts above.
  static const int postCaptionMaxLength = 300;

  /// Largest post photo, in bytes. Also enforced in SQL (post-photos bucket).
  static const int postPhotoMaxBytes = avatarMaxBytes;

  /// Accepted post photo formats. Also enforced in SQL (post-photos bucket).
  static const List<String> postPhotoMimeTypes = avatarMimeTypes;
}
