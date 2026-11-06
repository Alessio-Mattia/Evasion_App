import 'package:evasion/core/config/business_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the fuzzy area is smaller than the chosen location limit', () {
    expect(
      BusinessRules.postFuzzyRadiusMeters,
      lessThan(BusinessRules.postChosenLocationMaxDistanceMeters),
    );
  });
}
