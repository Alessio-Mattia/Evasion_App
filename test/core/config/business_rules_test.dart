import 'package:evasion/core/config/business_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the minimum age is below the maximum age', () {
    expect(BusinessRules.minimumAge, lessThan(BusinessRules.maximumAge));
  });

  test('the default detection radius is within the limit', () {
    expect(
      BusinessRules.defaultDetectionRadiusMeters,
      lessThanOrEqualTo(BusinessRules.maxDetectionRadiusMeters),
    );
  });

  test('the fuzzy area is smaller than the chosen location limit', () {
    expect(
      BusinessRules.postFuzzyCellSizeMeters,
      lessThan(BusinessRules.postChosenLocationMaxDistanceMeters),
    );
  });

  test('the default post lifetime is within the limits', () {
    expect(
      BusinessRules.postDefaultLifetime,
      greaterThanOrEqualTo(BusinessRules.postMinLifetime),
    );
    expect(
      BusinessRules.postDefaultLifetime,
      lessThanOrEqualTo(BusinessRules.postMaxLifetime),
    );
  });
}
