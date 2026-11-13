abstract final class AppRoutes {
  static const String home = '/home';
  static const String messages = '/messages';
  static const String add = '/add';
  static const String profile = '/profile';
  static const String settings = '/profile/settings';
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
