import 'package:evasion/features/auth/domain/auth_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isValidEmail', () {
    test('accepts usual addresses, university or not', () {
      for (final email in [
        'alex@epfl.ch',
        'a.b-c@students.unil.ch',
        'someone@gmail.com',
        '  Alex@EPFL.ch  ',
      ]) {
        expect(isValidEmail(email), isTrue, reason: email);
      }
    });

    test('rejects malformed addresses', () {
      for (final email in [
        '',
        'alex',
        'alex@',
        '@epfl.ch',
        'alex@epfl',
        'a b@x.ch',
      ]) {
        expect(isValidEmail(email), isFalse, reason: email);
      }
    });
  });

  test('normalizeEmail trims and lowercases', () {
    expect(normalizeEmail('  Alex@EPFL.ch '), 'alex@epfl.ch');
  });

  group('isValidSignInCode', () {
    test('accepts exactly six digits', () {
      expect(isValidSignInCode('123456'), isTrue);
      expect(isValidSignInCode(' 123456 '), isTrue);
    });

    test('rejects other lengths and non-digits', () {
      for (final code in ['', '12345', '1234567', '12a456', '12 456']) {
        expect(isValidSignInCode(code), isFalse, reason: code);
      }
    });
  });
}
