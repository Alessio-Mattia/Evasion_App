import 'package:evasion/core/config/business_rules.dart';
import 'package:evasion/core/models/gender.dart';
import 'package:evasion/core/models/location_mode.dart';
import 'package:evasion/features/settings/domain/settings_rules.dart';
import 'package:evasion/features/settings/domain/user_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('detection radius steps', () {
    test('go up, within the app and server limits', () {
      for (var i = 1; i < detectionRadiusSteps.length; i++) {
        expect(
          detectionRadiusSteps[i],
          greaterThan(detectionRadiusSteps[i - 1]),
        );
      }
      expect(
        detectionRadiusSteps.first,
        BusinessRules.minDetectionRadiusMeters,
      );
      expect(detectionRadiusSteps.last, BusinessRules.maxDetectionRadiusMeters);
    });

    test('include the default radius of a new user', () {
      expect(
        detectionRadiusSteps,
        contains(BusinessRules.defaultDetectionRadiusMeters),
      );
    });

    test('a saved radius maps to its step, or the closest one', () {
      expect(detectionRadiusSteps[detectionRadiusStepIndex(300)], 300);
      expect(detectionRadiusSteps[detectionRadiusStepIndex(320)], 300);
      expect(detectionRadiusSteps[detectionRadiusStepIndex(1)], 50);
      expect(detectionRadiusSteps[detectionRadiusStepIndex(9999)], 5000);
    });
  });

  group('maximum age', () {
    test('the last slider position means no maximum', () {
      expect(prefAgeMaxFromSlider(BusinessRules.prefAgeSliderMax), isNull);
      expect(prefAgeMaxFromSlider(35), 35);
    });

    test('no maximum, or one above the slider, sits at its last position', () {
      expect(prefAgeMaxToSlider(null), BusinessRules.prefAgeSliderMax);
      expect(prefAgeMaxToSlider(95), BusinessRules.prefAgeSliderMax);
      expect(prefAgeMaxToSlider(35), 35);
    });
  });

  group('toggleGender', () {
    test('removes a selected gender and adds an unselected one', () {
      expect(toggleGender(Gender.values, Gender.man), [
        Gender.woman,
        Gender.other,
      ]);
      expect(toggleGender([Gender.other], Gender.woman), [
        Gender.woman,
        Gender.other,
      ]);
    });

    test('refuses to remove the last gender', () {
      expect(toggleGender([Gender.woman], Gender.woman), isNull);
    });
  });

  test('reads a row as returned by Supabase', () {
    final settings = UserSettings.fromJson(const {
      'location_mode': 'foreground',
      'detection_radius_m': 300,
      'pref_genders': ['woman', 'other'],
      'pref_age_min': 20,
      'pref_age_max': null,
    });

    expect(
      settings,
      const UserSettings(
        locationMode: LocationMode.foreground,
        detectionRadiusM: 300,
        prefGenders: [Gender.woman, Gender.other],
        prefAgeMin: 20,
      ),
    );
  });
}
