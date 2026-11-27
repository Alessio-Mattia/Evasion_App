/// The token of a QR code that connects, and when it stops working: the app
/// asks for a new one a little before.
typedef ConnectionToken = ({String token, DateTime expiresAt});

/// What a scan did: who the new friend is, and whether they already were.
typedef ConnectionResult = ({String friendId, bool alreadyFriends});

/// Start of the text of an Evasion QR code: it tells it apart from any other
/// QR code, such as a restaurant menu, without asking the server.
const String connectionQrPrefix = 'evasion-connect:';

/// The text to show in the QR code of [token].
String qrPayloadFor(String token) => '$connectionQrPrefix$token';

/// The token in the text of a scanned QR code, or null if it is not an
/// Evasion QR code: the app then says so at once, without calling the
/// server.
String? tokenFromQrPayload(String payload) {
  final trimmed = payload.trim();
  if (!trimmed.startsWith(connectionQrPrefix)) return null;
  final token = trimmed.substring(connectionQrPrefix.length);
  return RegExp(r'^[0-9a-f]{32}$').hasMatch(token) ? token : null;
}
