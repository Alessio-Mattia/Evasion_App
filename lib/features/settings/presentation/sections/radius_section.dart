import 'dart:async';

import 'package:evasion/features/settings/domain/settings_rules.dart';
import 'package:evasion/features/settings/domain/user_settings.dart';
import 'package:evasion/features/settings/presentation/settings_section.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// "300 m" under one kilometer, "1,5 km" from one kilometer.
String formatRadius(AppLocalizations l10n, int meters) => meters < 1000
    ? l10n.settingsRadiusMeters(meters)
    : l10n.settingsRadiusKilometers(
        NumberFormat.decimalPattern(l10n.localeName).format(meters / 1000),
      );

/// Detection radius, chosen among [detectionRadiusSteps].
class RadiusSection extends ConsumerStatefulWidget {
  const RadiusSection({required this.settings, super.key});

  final UserSettings settings;

  @override
  ConsumerState<RadiusSection> createState() => _RadiusSectionState();
}

class _RadiusSectionState extends ConsumerState<RadiusSection> {
  /// Position while the slider is dragged; saved only when released.
  double? _dragged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final position =
        _dragged ??
        detectionRadiusStepIndex(widget.settings.detectionRadiusM).toDouble();
    final radius = formatRadius(l10n, detectionRadiusSteps[position.round()]);

    return SettingsSection(
      title: l10n.settingsRadiusTitle,
      hint: l10n.settingsRadiusHint,
      children: [
        Text(radius, style: Theme.of(context).textTheme.titleLarge),
        Slider(
          value: position,
          max: (detectionRadiusSteps.length - 1).toDouble(),
          divisions: detectionRadiusSteps.length - 1,
          label: radius,
          onChanged: (value) => setState(() => _dragged = value),
          onChangeEnd: (value) {
            setState(() => _dragged = null);
            unawaited(
              changeSettings(
                context,
                ref,
                (current) => current.copyWith(
                  detectionRadiusM: detectionRadiusSteps[value.round()],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
