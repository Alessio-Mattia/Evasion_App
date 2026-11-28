import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/core/scanner/scanner_view.dart';
import 'package:evasion/core/services/location_service.dart';
import 'package:evasion/core/widgets/failure_snack_bar.dart';
import 'package:evasion/features/connections/presentation/connect/connect_card.dart';
import 'package:evasion/features/connections/presentation/connect/connect_controllers.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The camera, scanning the QR code of someone met in person, with where the
/// scan stands below it.
class ScanView extends ConsumerWidget {
  const ScanView({required this.onOpenProfile, super.key});

  final ValueChanged<String> onOpenProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(scanControllerProvider.notifier);
    final scanAgain = OutlinedButton(
      onPressed: controller.reset,
      child: Text(l10n.scanAgain),
    );

    final status = switch (ref.watch(scanControllerProvider)) {
      ScanWaiting() => ConnectCard(message: l10n.scanHint),
      ScanSending() => ConnectCard(
        leading: const Center(child: CircularProgressIndicator()),
        message: l10n.scanSending,
      ),
      ScanConnected(:final friendId, :final alreadyFriends) => ConnectCard(
        message: alreadyFriends ? l10n.scanAlreadyFriends : l10n.scanConnected,
        actions: [
          FilledButton(
            onPressed: () => onOpenProfile(friendId),
            child: Text(l10n.connectSeeProfile),
          ),
          scanAgain,
        ],
      ),
      ScanNotEvasion() => ConnectCard(
        message: l10n.scanNotEvasion,
        actions: [scanAgain],
      ),
      ScanFailed(:final failure) => ConnectCard(
        message: switch (failure) {
          // Expired, used, or of someone blocked: the user never learns which.
          NotFoundFailure() => l10n.scanExpired,
          // Their own QR code, or the two are too far apart.
          InvalidInputFailure() => l10n.scanRefused,
          _ => failureMessage(context, failure),
        },
        actions: [scanAgain],
      ),
    };

    return ref.watch(scannerViewBuilderProvider)(
      ScannerViewProps(
        onCode: controller.onCode,
        // Over the camera only: nothing to aim at when it cannot scan.
        overlay: Stack(
          children: [
            Positioned(left: 16, right: 16, bottom: 24, child: status),
          ],
        ),
        problemBuilder: _CameraProblem.new,
      ),
    );
  }
}

/// Instead of the camera, when it cannot scan.
class _CameraProblem extends ConsumerWidget {
  const _CameraProblem(this.problem);

  final ScannerProblem problem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 16,
            children: [
              Text(switch (problem) {
                ScannerProblem.permissionDenied => l10n.scanCameraDenied,
                ScannerProblem.unavailable => l10n.scanCameraUnavailable,
              }, textAlign: TextAlign.center),
              if (problem == ScannerProblem.permissionDenied)
                FilledButton(
                  // Only the phone's settings can allow a refused camera.
                  onPressed: () =>
                      ref.read(locationServiceProvider).openSettings(),
                  child: Text(l10n.scanOpenSettings),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
