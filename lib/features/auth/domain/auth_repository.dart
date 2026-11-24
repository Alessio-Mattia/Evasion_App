import 'package:evasion/features/auth/domain/app_user.dart';

/// Signs users in and out with a code sent by email.
///
/// The same flow signs in an existing user and creates a new account. Every
/// method throws an `AppFailure` on error.
abstract interface class AuthRepository {
  /// The signed-in user, restored from the saved session at startup.
  AppUser? get currentUser;

  /// Emits the user on every sign-in, and null on every sign-out.
  Stream<AppUser?> authStateChanges();

  /// Sends a sign-in code to [email], creating the account if needed.
  Future<void> sendCode(String email);

  /// Checks the [code] received by [email] and signs the user in.
  Future<void> verifyCode({required String email, required String code});

  Future<void> signOut();

  /// Sends a new code to the signed-in user's email, to confirm a sensitive
  /// action such as deleting the account. Never creates an account.
  Future<void> sendReauthenticationCode();

  /// Deletes the signed-in user's account, its data and its photos, then
  /// signs out. The user must have entered a code (see [verifyCode]) a few
  /// minutes ago at most, else it fails with
  /// `ReauthenticationRequiredFailure`.
  Future<void> deleteAccount();
}
