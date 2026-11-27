import 'package:evasion/features/connections/domain/connection_qr.dart';
import 'package:flutter_test/flutter_test.dart';

const token = '0123456789abcdef0123456789abcdef';

void main() {
  test('a QR code holds the token behind the Evasion prefix', () {
    expect(qrPayloadFor(token), 'evasion-connect:$token');
  });

  test('reads back the token of an Evasion QR code', () {
    expect(tokenFromQrPayload(qrPayloadFor(token)), token);
    expect(tokenFromQrPayload('  ${qrPayloadFor(token)}\n'), token);
  });

  test('any other QR code has no token', () {
    expect(tokenFromQrPayload('https://example.com/menu'), isNull);
    expect(tokenFromQrPayload(token), isNull);
    expect(tokenFromQrPayload('evasion-connect:'), isNull);
    expect(tokenFromQrPayload('evasion-connect:not-a-token'), isNull);
    expect(
      tokenFromQrPayload('evasion-connect:${token.toUpperCase()}'),
      isNull,
    );
  });
}
