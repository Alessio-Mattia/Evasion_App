import 'dart:async';

import 'package:evasion/core/config/business_rules.dart';
import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/features/connections/data/supabase_connections_repository.dart';
import 'package:evasion/features/connections/domain/connection_qr.dart';
import 'package:evasion/features/connections/domain/friend.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'connect_controllers.g.dart';

/// The user's QR code on screen, and who scanned it.
typedef MyQrState = ({
  ConnectionToken token,

  /// Who scanned the QR code: they are now friends with the user.
  Friend? scannedBy,

  /// Whether the user undid that connection.
  bool cancelled,
});

/// The user's QR code. While it is on screen, the code is renewed a little
/// before it expires, and the server is asked every
/// `BusinessRules.connectionScanPollInterval` who scanned it. Both stop once
/// someone did, and when the screen closes.
@riverpod
class MyQrController extends _$MyQrController {
  Timer? _renewTimer;
  Timer? _pollTimer;

  @override
  Future<MyQrState> build() async {
    ref.onDispose(_stopTimers);
    final token = await ref.read(connectionsRepositoryProvider).createToken();
    _startTimers(token);
    return (token: token, scannedBy: null, cancelled: false);
  }

  /// Shows a new QR code, for example after a scan.
  void renew() {
    _stopTimers();
    ref.invalidateSelf();
  }

  /// Undoes the connection with the person who scanned the QR code, without
  /// telling them. Returns why it failed, if it did: the connection then
  /// stays, and the user can try again.
  Future<AppFailure?> cancelConnection() async {
    final current = state.value;
    final friend = current?.scannedBy;
    if (current == null || friend == null) return null;
    try {
      await ref.read(connectionsRepositoryProvider).removeFriend(friend.userId);
    } on AppFailure catch (failure) {
      return failure;
    }
    if (ref.mounted) {
      state = AsyncData((
        token: current.token,
        scannedBy: friend,
        cancelled: true,
      ));
    }
    return null;
  }

  void _startTimers(ConnectionToken token) {
    final untilRenewal =
        token.expiresAt.difference(DateTime.now()) -
        BusinessRules.connectionTokenRenewMargin;
    _renewTimer = Timer(
      untilRenewal.isNegative ? Duration.zero : untilRenewal,
      renew,
    );
    _pollTimer = Timer.periodic(
      BusinessRules.connectionScanPollInterval,
      (_) => unawaited(_checkScan(token)),
    );
  }

  Future<void> _checkScan(ConnectionToken token) async {
    final Friend? friend;
    try {
      friend = await ref
          .read(connectionsRepositoryProvider)
          .whoScanned(token.token);
    } on AppFailure {
      // A missed check, for example offline: the next one asks again.
      return;
    }
    if (friend == null || !ref.mounted) return;
    // The token is used: no need to renew it nor to ask again.
    _stopTimers();
    state = AsyncData((token: token, scannedBy: friend, cancelled: false));
  }

  void _stopTimers() {
    _renewTimer?.cancel();
    _pollTimer?.cancel();
  }
}

/// Where scanning someone's QR code stands.
sealed class ScanState {
  const ScanState();
}

/// Waiting for a QR code.
final class ScanWaiting extends ScanState {
  const ScanWaiting();
}

/// A QR code is being sent to the server.
final class ScanSending extends ScanState {
  const ScanSending();
}

/// The user and [friendId] are friends now, or [alreadyFriends] were.
final class ScanConnected extends ScanState {
  const ScanConnected({required this.friendId, required this.alreadyFriends});

  final String friendId;
  final bool alreadyFriends;
}

/// A QR code that is not an Evasion one: told at once, without the server.
final class ScanNotEvasion extends ScanState {
  const ScanNotEvasion();
}

/// The server refused the QR code, or could not be reached.
final class ScanFailed extends ScanState {
  const ScanFailed(this.failure);

  final AppFailure failure;
}

/// Scans the QR code of someone met in person. The camera reports the same
/// code many times a second: a code is handled once, and none while one is
/// sent or once connected. [reset] waits for a new code, the same one
/// included.
@riverpod
class ScanController extends _$ScanController {
  String? _lastCode;

  @override
  ScanState build() => const ScanWaiting();

  Future<void> onCode(String code) async {
    if (code == _lastCode || state is ScanSending || state is ScanConnected) {
      return;
    }
    _lastCode = code;
    if (tokenFromQrPayload(code) == null) {
      state = const ScanNotEvasion();
      return;
    }
    state = const ScanSending();
    try {
      final result = await ref.read(connectionsRepositoryProvider).scan(code);
      if (!ref.mounted) return;
      state = ScanConnected(
        friendId: result.friendId,
        alreadyFriends: result.alreadyFriends,
      );
    } on AppFailure catch (failure) {
      if (ref.mounted) state = ScanFailed(failure);
    }
  }

  void reset() {
    _lastCode = null;
    state = const ScanWaiting();
  }
}
