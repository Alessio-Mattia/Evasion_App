import 'package:evasion/core/utils/server_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ageOn', () {
    final birthDate = DateTime(2000, 5, 17);

    test('the day before the birthday', () {
      expect(ageOn(birthDate, DateTime(2024, 5, 16)), 23);
    });

    test('on the birthday', () {
      expect(ageOn(birthDate, DateTime(2024, 5, 17)), 24);
    });

    test('after the birthday, in a later month', () {
      expect(ageOn(birthDate, DateTime(2024, 6)), 24);
    });

    test('before the birthday, in an earlier month', () {
      expect(ageOn(birthDate, DateTime(2024, 4, 30)), 23);
    });

    test('born on February 29, counted from March 1 in common years', () {
      final leapDay = DateTime(2004, 2, 29);
      expect(ageOn(leapDay, DateTime(2023, 2, 28)), 18);
      expect(ageOn(leapDay, DateTime(2023, 3)), 19);
    });
  });

  test('serverToday uses the UTC date, like the database', () {
    // 23:30 in Zurich (UTC+1) is still the same day in UTC.
    final evening = DateTime.utc(2024, 1, 15, 22, 30);
    expect(serverToday(evening), DateTime(2024, 1, 15));

    // 00:30 in Zurich is still the day before in UTC.
    final midnight = DateTime.utc(2024, 1, 15, 23, 30);
    expect(serverToday(midnight), DateTime(2024, 1, 15));
  });
}
