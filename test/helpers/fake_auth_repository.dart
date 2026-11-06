import 'dart:async';

import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/features/auth/domain/app_user.dart';
import 'package:evasion/features/auth/domain/auth_repository.dart';

const testUser = AppUser(id: 'user-1', email: 'alex@epfl.ch');

/// In-memory auth for widget and controller tests.
///
/// [validCode] is the only code accepted; set [sendCodeFailure] to make the
/// next code request fail.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AppUser? signedInUser, this.validCode = '123456'})
    : _currentUser = signedInUser;

  final String validCode;
  AppFailure? sendCodeFailure;
  final List<String> sentCodesTo = [];

  AppUser? _currentUser;
  final _changes = StreamController<AppUser?>.broadcast();

  @override
  AppUser? get currentUser => _currentUser;

  @override
  Stream<AppUser?> authStateChanges() => _changes.stream;

  @override
  Future<void> sendCode(String email) async {
    if (sendCodeFailure case final failure?) throw failure;
    sentCodesTo.add(email);
  }

  @override
  Future<void> verifyCode({required String email, required String code}) async {
    if (code != validCode) throw const InvalidCodeFailure();
    _emit(AppUser(id: 'user-1', email: email));
  }

  @override
  Future<void> signOut() async => _emit(null);

  void _emit(AppUser? user) {
    _currentUser = user;
    _changes.add(user);
  }
}
