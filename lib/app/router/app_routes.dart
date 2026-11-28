abstract final class AppRoutes {
  static const String map = '/map';
  static const String crossings = '/crossings';
  static const String userIdParameter = 'userId';
  static const String crossingParameter = 'crossing';

  /// The profile of [userId], opened from their crossing [crossingId], which
  /// it recalls.
  static String crossingProfile(String userId, String crossingId) => Uri(
    path: '$crossings/profile/$userId',
    queryParameters: {crossingParameter: crossingId},
  ).toString();
  static const String messages = '/messages';

  /// Creating a post, over the tabs. Pops `true` once published.
  static const String newPost = '/new-post';

  /// Picking the place of a new post on the map, given the place chosen
  /// before as `extra`. Pops the place chosen.
  static const String choosePlace = '/new-post/place';
  static const String profile = '/profile';
  static const String settings = '/profile/settings';
  static const String deleteAccount = '/profile/settings/delete-account';
  static const String editProfile = '/profile/edit';
  static const String pageTypeParameter = 'type';

  /// Screen creating a page of the template [type] (`PageType.code`).
  static String newProfilePage(String type) => '$profile/pages/new/$type';

  static const String pageIdParameter = 'pageId';

  /// Screen editing the profile page [pageId].
  static String editProfilePage(String pageId) => '$profile/pages/$pageId';

  static const String startup = '/startup';
  static const String onboarding = '/onboarding';

  static const String signIn = '/sign-in';
  static const String signInCode = '/sign-in/code';
  static const String emailParameter = 'email';

  /// Code screen for [email], passed in the address so that it survives a
  /// rebuild of the route.
  static String signInCodeFor(String email) => Uri(
    path: signInCode,
    queryParameters: {emailParameter: email},
  ).toString();
}
