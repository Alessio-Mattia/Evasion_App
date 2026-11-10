import 'package:evasion/features/auth/data/supabase_auth_repository.dart';
import 'package:evasion/features/auth/domain/app_user.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'current_user.g.dart';

/// The signed-in user, or null when signed out.
///
/// Starts from the session restored at startup, so it is known immediately and
/// the app never shows a loading screen just to decide where to go.
@Riverpod(keepAlive: true)
class CurrentUser extends _$CurrentUser {
  @override
  AppUser? build() {
    final repository = ref.watch(authRepositoryProvider);
    final subscription = repository.authStateChanges().listen(
      (user) => state = user,
      // A failed session refresh is followed by a sign-out event: nothing to
      // do here.
      onError: (_) {},
    );
    ref.onDispose(subscription.cancel);
    return repository.currentUser;
  }
}
