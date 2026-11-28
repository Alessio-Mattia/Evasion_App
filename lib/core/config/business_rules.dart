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

  /// How long the latest position of a user is kept before being purged.
  /// Only the latest one is ever kept. Also enforced in SQL (purge job).
  static const Duration rawLocationRetention = Duration(hours: 24);

  /// Shortest time between two positions sent by the app: a position sent
  /// sooner is ignored. Also enforced in SQL (report_location).
  static const Duration locationReportMinInterval = Duration(seconds: 30);

  /// How often the app sends the position while it is open and the user is
  /// visible: often enough for the server, which only matches positions
  /// less than crossingMaxPositionAge old. App side only.
  static const Duration locationReportInterval = Duration(seconds: 90);

  /// Imprecise positions in a row before the app asks for the precise
  /// location: one may be a bad fix, several mean the user chose
  /// "approximate". App side only.
  static const int impreciseReportsBeforeNotice = 3;

  /// Worst GPS accuracy accepted, in metres: a less precise position, as
  /// often indoors, is ignored rather than create false crossings.
  /// Also enforced in SQL (report_location).
  static const int locationMaxAccuracyMeters = 100;

  /// Above this speed since the previous position, the user is in a vehicle:
  /// the position is kept but creates no crossing. Also enforced in SQL.
  static const int crossingMaxSpeedKmh = 50;

  /// How old the other person's latest position may be for two people to
  /// count as there at the same time. Also enforced in SQL.
  static const Duration crossingMaxPositionAge = Duration(minutes: 3);

  /// Two people cross at most once in this time. Also enforced in SQL.
  static const Duration crossingRepeatInterval = Duration(hours: 1);

  /// How long crossings are kept and shown. Also enforced in SQL.
  static const Duration crossingHistory = Duration(days: 7);

  /// Smallest side of the grid cells of crossing zones. A crossing shows at
  /// the centre of the cell holding the midpoint of the two positions, as
  /// large as the radius that made the crossing and never smaller than this:
  /// never a precise point. Also enforced in SQL (detect_crossings).
  static const int crossingZoneCellSizeMeters = 100;

  /// Crossing times are shown rounded to the nearest multiple of this.
  /// Also enforced in SQL (my_crossings).
  static const Duration crossingTimeRounding = Duration(minutes: 30);

  // Connections
  //
  // Meeting in person, one person scans the other's QR code: the two become
  // friends, which unlocks messages and the like.

  /// How long the token of a QR code works, once: a screenshot sent later is
  /// useless. The app asks for a new one before it expires.
  /// Also enforced in SQL (create_connection_token).
  static const Duration connectionTokenLifetime = Duration(minutes: 2);

  /// When both people sent a recent position, they must be at most this far
  /// apart to connect: a QR code shown in a video call connects nobody.
  /// Also enforced in SQL (scan_connection_token).
  static const int connectionMaxDistanceMeters = 500;

  // Likes and matches
  //
  // A like is secret, between friends only, and revealed to the other by a
  // match only. It is meant to be deliberate, not a way to probe who liked
  // you.

  /// Also enforced in SQL. Counted in code points, like the texts above.
  /// The message is optional.
  static const int likeMessageMaxLength = 300;

  /// After removing a like, the user cannot like the same friend again for
  /// this long: liking then removing cannot be used to probe.
  /// Also enforced in SQL (like_friend).
  static const Duration likeCooldownAfterRemoval = Duration(days: 7);

  // Messages
  //
  // Between friends only, with no quota for now. Text only.

  /// Also enforced in SQL (send_message). Counted in code points, like the
  /// texts above.
  static const int messageMaxLength = 2000;

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

  /// Lifetimes offered when posting, within postMinLifetime and
  /// postMaxLifetime; postDefaultLifetime is selected first. App side only.
  static const List<Duration> postLifetimeChoices = [
    Duration(hours: 1),
    Duration(hours: 6),
    Duration(hours: 24),
    Duration(days: 3),
    Duration(days: 7),
  ];

  /// Posts a user can have at once; expired posts do not count.
  /// Also enforced in SQL (create_post).
  static const int activePostsMax = 5;

  /// Also enforced in SQL. Counted in code points, like the texts above.
  static const int postCaptionMaxLength = 300;

  /// Largest post photo, in bytes. Also enforced in SQL (post-photos bucket).
  static const int postPhotoMaxBytes = avatarMaxBytes;

  /// Accepted post photo formats. Also enforced in SQL (post-photos bucket).
  static const List<String> postPhotoMimeTypes = avatarMimeTypes;

  // Map

  /// Largest area the map can ask posts for, in metres on each side: zoomed
  /// out further, the app must not ask. Keeps anyone from downloading every
  /// post at once. Also enforced in SQL (map_feed).
  static const int mapFeedMaxAreaSideMeters = 50000;

  /// Posts the map receives for an area at most, the most recent first.
  /// Also enforced in SQL (map_feed).
  static const int mapFeedMaxPosts = 200;

  /// Where the map opens when the phone's position is unknown: the campus
  /// of the launch (Lausanne, between UNIL and EPFL). App side only.
  static const ({double latitude, double longitude}) mapDefaultCenter = (
    latitude: 46.5215,
    longitude: 6.5735,
  );

  /// Zoom of the map when it opens: a few streets around. App side only.
  static const double mapInitialZoom = 14;

  /// Radius of the area drawn for a blurred post: it covers its whole grid
  /// cell (half its diagonal), wherever the post really is. App side only.
  static const double mapFuzzyAreaRadiusMeters =
      postFuzzyCellSizeMeters * 0.71;
}
