abstract final class AppRoutes {
  static const String home = '/home';
  static const String messages = '/messages';
  static const String add = '/add';
  static const String profile = '/profile';

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
