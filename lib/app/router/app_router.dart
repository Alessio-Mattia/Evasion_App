import 'package:evasion/app/router/access_redirect.dart';
import 'package:evasion/app/router/access_status.dart';
import 'package:evasion/app/router/app_routes.dart';
import 'package:evasion/app/router/app_shell.dart';
import 'package:evasion/app/startup/startup_screen.dart';
import 'package:evasion/core/models/geo_point.dart';
import 'package:evasion/features/auth/presentation/current_user.dart';
import 'package:evasion/features/auth/presentation/delete_account/delete_account_button.dart';
import 'package:evasion/features/auth/presentation/delete_account/delete_account_screen.dart';
import 'package:evasion/features/auth/presentation/sign_in_code_screen.dart';
import 'package:evasion/features/auth/presentation/sign_in_email_screen.dart';
import 'package:evasion/features/auth/presentation/sign_out_button.dart';
import 'package:evasion/features/chat/presentation/messaging_screen.dart';
import 'package:evasion/features/connections/presentation/connect/connect_screen.dart';
import 'package:evasion/features/encounters/presentation/crossing_note.dart';
import 'package:evasion/features/encounters/presentation/crossings_screen.dart';
import 'package:evasion/features/onboarding/presentation/onboarding_screen.dart';
import 'package:evasion/features/posts/presentation/create_post/create_post_screen.dart';
import 'package:evasion/features/posts/presentation/map/posts_map_screen.dart';
import 'package:evasion/features/posts/presentation/place_picker/place_picker_screen.dart';
import 'package:evasion/features/profile/domain/page_draft.dart';
import 'package:evasion/features/profile/presentation/editor/edit_page_screen.dart';
import 'package:evasion/features/profile/presentation/editor/new_page_screen.dart';
import 'package:evasion/features/profile/presentation/other_profile/other_profile_screen.dart';
import 'package:evasion/features/profile/presentation/own_profile.dart';
import 'package:evasion/features/profile/presentation/profile_edit/edit_profile_screen.dart';
import 'package:evasion/features/profile/presentation/profile_screen.dart';
import 'package:evasion/features/settings/presentation/invisible_notice.dart';
import 'package:evasion/features/settings/presentation/settings_button.dart';
import 'package:evasion/features/settings/presentation/settings_screen.dart';
import 'package:flutter/widgets.dart';
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
    initialLocation: AppRoutes.map,
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
      // Over the tabs, without the tab bar, like in the design canvas.
      GoRoute(
        path: AppRoutes.newPost,
        builder: (context, state) => switch (ref.read(currentUserProvider)) {
          final user? => CreatePostScreen(userId: user.id),
          // Only while signing out: the redirect then leaves the app.
          null => const SizedBox.shrink(),
        },
        routes: [
          GoRoute(
            path: 'place',
            builder: (context, state) =>
                PlacePickerScreen(initialPlace: state.extra as GeoPoint?),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.connect,
        builder: (context, state) => ConnectScreen(
          // Leaves the connect screen for good: back never shows the
          // connection message again.
          onOpenProfile: (userId) =>
              context.go(AppRoutes.newFriendProfile(userId)),
        ),
      ),
      // indexedStack keeps each tab alive, so its state survives tab switches.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(
          navigationShell: navigationShell,
          currentPath: state.uri.path,
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.map,
                builder: (context, state) => const PostsMapScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.crossings,
                builder: (context, state) =>
                    const CrossingsScreen(visibilityNotice: InvisibleNotice()),
                routes: [
                  GoRoute(
                    path: 'profile/:${AppRoutes.userIdParameter}',
                    builder: (context, state) => OtherProfileScreen(
                      userId: state.pathParameters[AppRoutes.userIdParameter]!,
                      meetingNote: switch (state.uri.queryParameters[AppRoutes
                          .crossingParameter]) {
                        final id? => CrossingNote(crossingId: id),
                        null => null,
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.messages,
                builder: (context, state) => const MessagingScreen(),
                routes: [
                  GoRoute(
                    path: 'friend/:${AppRoutes.userIdParameter}',
                    // Reached from the connect screen, which is gone: the
                    // tab bar leads elsewhere.
                    builder: (context, state) => OtherProfileScreen(
                      userId: state.pathParameters[AppRoutes.userIdParameter]!,
                      showBackButton: false,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => switch (ref.read(
                  currentUserProvider,
                )) {
                  final user? => ProfileScreen(
                    userId: user.id,
                    settingsButton: const SettingsButton(),
                  ),
                  // Only while signing out: the redirect then leaves the tabs.
                  null => const SizedBox.shrink(),
                },
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) =>
                        switch (ref.read(currentUserProvider)) {
                          final user? => EditProfileScreen(userId: user.id),
                          null => const SizedBox.shrink(),
                        },
                  ),
                  GoRoute(
                    path: 'pages/new/:${AppRoutes.pageTypeParameter}',
                    builder: (context, state) {
                      final type = PageType.fromCode(
                        state.pathParameters[AppRoutes.pageTypeParameter]!,
                      );
                      final user = ref.read(currentUserProvider);
                      // An unknown template, or signing out: nothing to edit.
                      if (type == null || user == null) {
                        return const SizedBox.shrink();
                      }
                      return NewPageScreen(userId: user.id, type: type);
                    },
                  ),
                  GoRoute(
                    path: 'pages/:${AppRoutes.pageIdParameter}',
                    builder: (context, state) => switch (ref.read(
                      currentUserProvider,
                    )) {
                      final user? => EditPageScreen(
                        userId: user.id,
                        pageId:
                            state.pathParameters[AppRoutes.pageIdParameter]!,
                      ),
                      null => const SizedBox.shrink(),
                    },
                  ),
                  // Inside the profile tab, so that the tab bar stays visible.
                  GoRoute(
                    path: 'settings',
                    builder: (context, state) => const SettingsScreen(
                      signOutButton: SignOutButton(),
                      deleteAccountButton: DeleteAccountButton(),
                    ),
                    routes: [
                      GoRoute(
                        path: 'delete-account',
                        builder: (context, state) =>
                            const DeleteAccountScreen(),
                      ),
                    ],
                  ),
                ],
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
