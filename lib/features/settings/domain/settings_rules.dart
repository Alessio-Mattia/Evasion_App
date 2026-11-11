import 'package:evasion/core/config/business_rules.dart';
import 'package:evasion/core/models/gender.dart';

/// Radii offered by the slider, in meters. Steps rather than a linear scale:
/// a linear slider from 50 m to 5 km would make small radii impossible to set.
const detectionRadiusSteps = [
  BusinessRules.minDetectionRadiusMeters,
  100,
  200,
  300,
  500,
  750,
  1000,
  1500,
  2000,
  3000,
  4000,
  BusinessRules.maxDetectionRadiusMeters,
];

/// Index of the step closest to [meters], for radii saved outside the steps.
int detectionRadiusStepIndex(int meters) {
  var closest = 0;
  for (var i = 1; i < detectionRadiusSteps.length; i++) {
    if ((detectionRadiusSteps[i] - meters).abs() <
        (detectionRadiusSteps[closest] - meters).abs()) {
      closest = i;
    }
  }
  return closest;
}

/// Maximum age stored for a slider position: its last position means no
/// maximum.
int? prefAgeMaxFromSlider(int sliderValue) =>
    sliderValue >= BusinessRules.prefAgeSliderMax ? null : sliderValue;

/// Slider position for a stored maximum age; no maximum, or one above the
/// slider, sits at its last position.
int prefAgeMaxToSlider(int? prefAgeMax) =>
    prefAgeMax == null || prefAgeMax >= BusinessRules.prefAgeSliderMax
    ? BusinessRules.prefAgeSliderMax
    : prefAgeMax;

/// [genders] with [gender] added or removed, in a stable order. Null when it
/// would leave no gender at all, which would mean meeting nobody.
List<Gender>? toggleGender(List<Gender> genders, Gender gender) {
  final selected = genders.toSet();
  if (!selected.add(gender)) selected.remove(gender);
  if (selected.isEmpty) return null;
  return Gender.values.where(selected.contains).toList();
}
