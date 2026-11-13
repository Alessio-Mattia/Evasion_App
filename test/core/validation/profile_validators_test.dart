import 'package:evasion/core/utils/server_date.dart';
import 'package:evasion/core/validation/profile_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validateDisplayName', () {
    test('accepts a usual name, trimmed', () {
      expect(validateDisplayName('  Alex  '), isNull);
    });

    test('refuses a blank name', () {
      expect(validateDisplayName('   '), DisplayNameError.empty);
    });

    test('allows exactly 50 code points', () {
      expect(validateDisplayName('a' * 50), isNull);
      expect(validateDisplayName('a' * 51), DisplayNameError.tooLong);
    });

    test('counts emojis like the server does, in code points', () {
      // Each family emoji shows as one character but is 5 code points:
      // 10 of them reach the limit of 50, 11 go over.
      const family = '\u{1F468}‍\u{1F469}‍\u{1F467}';
      expect(validateDisplayName(family * 10), isNull);
      expect(validateDisplayName(family * 11), DisplayNameError.tooLong);
    });
  });

  group('serverToday', () {
    test('is the UTC date, like Postgres current_date', () {
      // 00:30 on 11 November in Switzerland (UTC+1) is still the 10th in UTC.
      expect(
        serverToday(DateTime.utc(2026, 11, 10, 23, 30)),
        DateTime(2026, 11, 10),
      );
    });

    test('keeps no time of day', () {
      final today = serverToday();

      expect([today.hour, today.minute, today.second], [0, 0, 0]);
    });
  });

  group('birth date limits', () {
    final today = DateTime(2026, 11, 10);

    test('exactly 18 years old is allowed, one day less is not', () {
      expect(isAllowedBirthDate(DateTime(2008, 11, 10), today), isTrue);
      expect(isAllowedBirthDate(DateTime(2008, 11, 11), today), isFalse);
    });

    test('exactly 120 years old is allowed, one day more is not', () {
      expect(isAllowedBirthDate(DateTime(1906, 11, 10), today), isTrue);
      expect(isAllowedBirthDate(DateTime(1906, 11, 9), today), isFalse);
    });

    test('the time of day is ignored', () {
      expect(isAllowedBirthDate(DateTime(2008, 11, 10, 23, 59), today), isTrue);
    });

    test('on 29 February, 18 years earlier is the 28th, as in Postgres', () {
      final leapDay = DateTime(2028, 2, 29);

      expect(latestAllowedBirthDate(leapDay), DateTime(2010, 2, 28));
      // 1 March 2010.
      expect(isAllowedBirthDate(DateTime(2010, 3), leapDay), isFalse);
    });
  });

  group('fitsLength', () {
    test('counts the trimmed text, in code points like Postgres', () {
      expect(fitsLength('  ${'a' * 10}  ', 10), isTrue);
      expect(fitsLength('a' * 11, 10), isFalse);
      // 👨‍👩‍👧 is one character on screen but 5 code points.
      expect(fitsLength('👨‍👩‍👧', 4), isFalse);
    });
  });

  test('toSqlDate writes a Postgres date, padded', () {
    expect(toSqlDate(DateTime(2001, 2, 3, 23, 59)), '2001-02-03');
  });
}
