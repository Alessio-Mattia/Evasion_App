import 'dart:async';

import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/features/auth/domain/app_user.dart';
import 'package:evasion/features/auth/domain/auth_repository.dart';

const testUser = AppUser(id: 'user-1', email: 'alex@epfl.ch');

/// In-memory auth for widget and controller tests.
///
/// [validCode] is the only code accepted; set [sendCodeFailure] to make the
/// next code request fail. Set [pendingCall] to keep calls running until it
/// completes, to test what happens while a request is in progress.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AppUser? signedInUser, this.validCode = '123456'})
    : _currentUser = signedInUser;

  final String validCode;
  AppFailure? sendCodeFailure;
  Completer<void>? pendingCall;
  final List<String> sentCodesTo = [];
  int verifyCodeCalls = 0;

  AppUser? _currentUser;
  final _changes = StreamController<AppUser?>.broadcast();

  @override
  AppUser? get currentUser => _currentUser;

  @override
  Stream<AppUser?> authStateChanges() => _changes.stream;

  @override
  Future<void> sendCode(String email) async {
    sentCodesTo.add(email);
    await pendingCall?.future;
    if (sendCodeFailure case final failure?) throw failure;
  }

  @override
  Future<void> verifyCode({required String email, required String code}) async {
    verifyCodeCalls++;
    await pendingCall?.future;
    if (code != validCode) throw const InvalidCodeFailure();
    _emit(AppUser(id: 'user-1', email: email));
  }

  @override
  Future<void> signOut() async => _emit(null);

  /// Reauthentication codes sent, and account deletions asked.
  int reauthenticationCodesSent = 0;
  int deleteAccountCalls = 0;

  /// Set to make the next account deletions fail.
  AppFailure? deleteAccountFailure;
  bool get isDeleted => _deleted;
  bool _deleted = false;

  @override
  Future<void> sendReauthenticationCode() async {
    reauthenticationCodesSent++;
    await pendingCall?.future;
    if (sendCodeFailure case final failure?) throw failure;
  }

  @override
  Future<void> deleteAccount() async {
    deleteAccountCalls++;
    await pendingCall?.future;
    if (deleteAccountFailure case final failure?) throw failure;
    _deleted = true;
    _emit(null);
  }

  void _emit(AppUser? user) {
    _currentUser = user;
    _changes.add(user);
  }
}
