import 'package:evasion/app/router/access_redirect.dart';
import 'package:evasion/app/router/access_status.dart';
import 'package:evasion/app/router/app_routes.dart';
import 'package:evasion/app/router/app_shell.dart';
import 'package:evasion/app/startup/startup_screen.dart';
import 'package:evasion/features/auth/presentation/sign_in_code_screen.dart';
import 'package:evasion/features/auth/presentation/sign_in_email_screen.dart';
import 'package:evasion/features/auth/presentation/sign_out_button.dart';
import 'package:evasion/features/chat/presentation/messaging_screen.dart';
import 'package:evasion/features/map/presentation/home_screen.dart';
import 'package:evasion/features/onboarding/presentation/onboarding_screen.dart';
import 'package:evasion/features/posts/presentation/add_post_screen.dart';
import 'package:evasion/features/profile/presentation/own_profile.dart';
import 'package:evasion/features/profile/presentation/profile_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_router.g.dart';

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  // The router is built once; this notifier makes it re-run its redirect
  // whenever the access status changes (sign-in, profile loaded, onboarding
  // done, sign-out).
  final status = ValueNotifier(ref.read(accessStatusProvider));
  ref.listen(accessStatusProvider, (_, next) => status.value = next);

  final router = GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: status,
    redirect: (context, state) =>
        accessRedirect(status: status.value, location: state.matchedLocation),
    routes: [
      GoRoute(
        path: AppRoutes.startup,
        builder: (context, state) => const StartupScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => OnboardingScreen(
          // Reading the profile again moves a now complete user to the app.
          onProfileSaved: () => ref.invalidate(ownProfileProvider),
        ),
      ),
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
    status.dispose();
  });
  return router;
}
