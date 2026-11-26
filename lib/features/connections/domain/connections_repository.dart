import 'package:evasion/features/connections/domain/connection_qr.dart';
import 'package:evasion/features/connections/domain/friend.dart';

/// Connects people who meet in person through a QR code, and manages the
/// signed-in user's friends. Every method throws an `AppFailure` on error.
abstract interface class ConnectionsRepository {
  /// A new token for the user's QR code (show it with `qrPayloadFor`),
  /// valid `BusinessRules.connectionTokenLifetime` and once. The previous
  /// token stops working. Fails with `PermissionDeniedFailure` for an
  /// incomplete profile.
  Future<ConnectionToken> createToken();

  /// Makes the user and the owner of the scanned QR code friends, from the
  /// text of the QR code.
  ///
  /// Fails with:
  /// - `InvalidInputFailure`, without calling the server, if it is not an
  ///   Evasion QR code (see `tokenFromQrPayload`, to say so precisely);
  /// - `NotFoundFailure` if the QR code expired, was already used, or
  ///   belongs to someone blocked either way: the user never learns which;
  /// - `InvalidInputFailure` for the user's own QR code, or when both sent
  ///   recent positions over `BusinessRules.connectionMaxDistanceMeters`
  ///   apart;
  /// - `PermissionDeniedFailure` for an incomplete profile.
  Future<ConnectionResult> scan(String qrPayload);

  /// Who scanned the user's QR code of [token], or null while nobody has.
  /// Ask every few seconds while the QR code is on screen, so that the user
  /// sees the new connection at once and can undo it with [removeFriend].
  Future<Friend?> whoScanned(String token);

  /// The user's friends, the most recent first.
  Future<List<Friend>> fetchFriends();

  /// Ends the friendship with [friendId], without telling them. Removing
  /// someone who is not a friend does nothing.
  Future<void> removeFriend(String friendId);
}
