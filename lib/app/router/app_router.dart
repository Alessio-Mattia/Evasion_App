import 'package:evasion/app/router/app_routes.dart';
import 'package:evasion/app/router/app_shell.dart';
import 'package:evasion/app/router/auth_redirect.dart';
import 'package:evasion/features/auth/presentation/current_user.dart';
import 'package:evasion/features/auth/presentation/sign_in_code_screen.dart';
import 'package:evasion/features/auth/presentation/sign_in_email_screen.dart';
import 'package:evasion/features/auth/presentation/sign_out_button.dart';
import 'package:evasion/features/chat/presentation/messaging_screen.dart';
import 'package:evasion/features/map/presentation/home_screen.dart';
import 'package:evasion/features/posts/presentation/add_post_screen.dart';
import 'package:evasion/features/profile/presentation/profile_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_router.g.dart';

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  // The router is built once; this notifier makes it re-run its redirect on
  // every sign-in and sign-out.
  final isSignedIn = ValueNotifier(ref.read(currentUserProvider) != null);
  ref.listen(currentUserProvider, (_, user) => isSignedIn.value = user != null);

  final router = GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: isSignedIn,
    redirect: (context, state) => authRedirect(
      isSignedIn: isSignedIn.value,
      location: state.matchedLocation,
    ),
    routes: [
      GoRoute(
        path: AppRoutes.signIn,
        builder: (context, state) => const SignInEmailScreen(),
        routes: [
          GoRoute(
            path: 'code',
            // Without an email there is no code to check: back to step one.
            redirect: (context, state) =>
                state.uri.queryParameters[AppRoutes.emailParameter] == null
                ? AppRoutes.signIn
                : null,
            builder: (context, state) => SignInCodeScreen(
              email: state.uri.queryParameters[AppRoutes.emailParameter]!,
            ),
          ),
        ],
      ),
      // indexedStack keeps each tab alive, so its state survives tab switches.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.messages,
                builder: (context, state) => const MessagingScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.add,
                builder: (context, state) => const AddPostScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) =>
                    const ProfileScreen(signOutButton: SignOutButton()),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    isSignedIn.dispose();
  });
  return router;
}
