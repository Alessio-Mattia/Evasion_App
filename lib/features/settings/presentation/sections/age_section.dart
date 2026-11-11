import 'dart:async';

import 'package:evasion/core/config/business_rules.dart';
import 'package:evasion/features/settings/domain/settings_rules.dart';
import 'package:evasion/features/settings/domain/user_settings.dart';
import 'package:evasion/features/settings/presentation/settings_section.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Age range of the people to encounter. The last slider position means no
/// maximum.
class AgeSection extends ConsumerStatefulWidget {
  const AgeSection({required this.settings, super.key});

  final UserSettings settings;

  @override
  ConsumerState<AgeSection> createState() => _AgeSectionState();
}

class _AgeSectionState extends ConsumerState<AgeSection> {
  /// Range while the slider is dragged; saved only when released.
  RangeValues? _dragged;

  String _label(AppLocalizations l10n, int age) =>
      age >= BusinessRules.prefAgeSliderMax
      ? l10n.settingsAgeNoMaxLabel(age)
      : '$age';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final range =
        _dragged ??
        RangeValues(
          widget.settings.prefAgeMin.toDouble(),
          prefAgeMaxToSlider(widget.settings.prefAgeMax).toDouble(),
        );
    final min = range.start.round();
    final max = prefAgeMaxFromSlider(range.end.round());

    return SettingsSection(
      title: l10n.settingsAgeTitle,
      children: [
        Text(
          max == null
              ? l10n.settingsAgeRangeNoMax(min)
              : l10n.settingsAgeRange(min, max),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        RangeSlider(
          values: range,
          min: BusinessRules.minimumAge.toDouble(),
          max: BusinessRules.prefAgeSliderMax.toDouble(),
          divisions: BusinessRules.prefAgeSliderMax - BusinessRules.minimumAge,
          labels: RangeLabels(
            _label(l10n, range.start.round()),
            _label(l10n, range.end.round()),
          ),
          onChanged: (values) => setState(() => _dragged = values),
          onChangeEnd: (values) {
            setState(() => _dragged = null);
            unawaited(
              changeSettings(
                context,
                ref,
                (current) => current.copyWith(
                  prefAgeMin: values.start.round(),
                  prefAgeMax: prefAgeMaxFromSlider(values.end.round()),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
