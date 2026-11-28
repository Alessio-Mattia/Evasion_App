import 'package:evasion/core/config/business_rules.dart';
import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/features/connections/domain/connection_qr.dart';
import 'package:evasion/features/connections/domain/connections_repository.dart';
import 'package:evasion/features/connections/domain/friend.dart';

/// A person met in person, for tests of controllers and screens.
Friend testFriend({String id = 'user-2', String name = 'Noah'}) => Friend(
  userId: id,
  displayName: name,
  age: 23,
  isStudentVerified: true,
  avatarPath: '$id/avatar.jpg',
  friendsSince: DateTime.utc(2026, 11, 26, 14),
);

/// In-memory connections of the signed-in user, for tests of controllers and
/// screens. Like the server, a token works once and only the latest one the
/// user created works; [othersTokens] are QR codes of other people the user
/// can scan.
class FakeConnectionsRepository implements ConnectionsRepository {
  FakeConnectionsRepository({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  /// The user's friends, the most recent first.
  final List<Friend> friends = [];

  /// QR tokens of other people, by token: scanning one makes them friends.
  final Map<String, Friend> othersTokens = {};

  /// The latest token the user created, if any.
  String? currentToken;

  /// Who scanned [currentToken]: set it to act as someone scanning it.
  Friend? scannedBy;

  /// Set to make the next calls fail.
  AppFailure? failure;

  final Set<String> _usedTokens = {};
  int _nextToken = 1;

  @override
  Future<ConnectionToken> createToken() async {
    _throwIfFailing();
    final token = (_nextToken++).toRadixString(16).padLeft(32, '0');
    currentToken = token;
    scannedBy = null;
    return (
      token: token,
      expiresAt: _now().add(BusinessRules.connectionTokenLifetime),
    );
  }

  @override
  Future<ConnectionResult> scan(String qrPayload) async {
    _throwIfFailing();
    final token = tokenFromQrPayload(qrPayload);
    if (token == null || token == currentToken) {
      throw const InvalidInputFailure();
    }
    final owner = othersTokens[token];
    if (owner == null || !_usedTokens.add(token)) {
      throw const NotFoundFailure();
    }
    final alreadyFriends = friends.any(
      (friend) => friend.userId == owner.userId,
    );
    if (!alreadyFriends) friends.insert(0, owner);
    return (friendId: owner.userId, alreadyFriends: alreadyFriends);
  }

  /// How many times [whoScanned] was asked.
  int whoScannedCalls = 0;

  @override
  Future<Friend?> whoScanned(String token) async {
    whoScannedCalls++;
    _throwIfFailing();
    return token == currentToken ? scannedBy : null;
  }

  @override
  Future<List<Friend>> fetchFriends() async {
    _throwIfFailing();
    return [...friends];
  }

  @override
  Future<void> removeFriend(String friendId) async {
    _throwIfFailing();
    friends.removeWhere((friend) => friend.userId == friendId);
  }

  void _throwIfFailing() {
    if (failure case final failure?) throw failure;
  }
}
