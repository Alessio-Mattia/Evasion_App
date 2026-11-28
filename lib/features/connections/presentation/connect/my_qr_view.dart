import 'package:evasion/core/storage/storage_images.dart';
import 'package:evasion/core/widgets/failure_snack_bar.dart';
import 'package:evasion/core/widgets/storage_image.dart';
import 'package:evasion/features/connections/domain/connection_qr.dart';
import 'package:evasion/features/connections/domain/friend.dart';
import 'package:evasion/features/connections/presentation/connect/connect_card.dart';
import 'package:evasion/features/connections/presentation/connect/connect_controllers.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// The user's QR code, renewed while on screen, then who scanned it.
class MyQrView extends ConsumerWidget {
  const MyQrView({required this.onOpenProfile, super.key});

  final ValueChanged<String> onOpenProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(myQrControllerProvider.notifier);

    Future<void> cancel() async {
      final failure = await controller.cancelConnection();
      if (failure != null && context.mounted) {
        showFailureSnackBar(context, failure);
      }
    }

    final newCode = OutlinedButton(
      onPressed: controller.renew,
      child: Text(l10n.connectNewCode),
    );

    final content = switch (ref.watch(myQrControllerProvider)) {
      AsyncValue(value: (:final token, scannedBy: null, cancelled: _)) =>
        _QrCode(payload: qrPayloadFor(token.token)),
      AsyncValue(value: (token: _, :final scannedBy?, cancelled: false)) =>
        ConnectCard(
          leading: _Avatar(scannedBy),
          message: l10n.connectScannedBy(scannedBy.displayName),
          detail: l10n.connectNowFriends,
          actions: [
            FilledButton(
              onPressed: () => onOpenProfile(scannedBy.userId),
              child: Text(l10n.connectSeeProfile),
            ),
            TextButton(onPressed: cancel, child: Text(l10n.connectCancel)),
            newCode,
          ],
        ),
      AsyncValue(value: (token: _, :final scannedBy?, cancelled: true)) =>
        ConnectCard(
          message: l10n.connectCancelled(scannedBy.displayName),
          actions: [newCode],
        ),
      AsyncValue(:final error?) => ConnectCard(
        message: failureMessage(context, error),
        actions: [
          FilledButton(onPressed: controller.renew, child: Text(l10n.retry)),
        ],
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          l10n.connectMyCodeHint,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        content,
      ],
    );
  }
}

/// Dark modules on a light square, which every camera reads well, in the
/// colours of the theme.
class _QrCode extends StatelessWidget {
  const _QrCode({required this.payload});

  final String payload;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Semantics(
        label: AppLocalizations.of(context).connectQrSemantics,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.onSurface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: QrImageView(
            // Keyed by its text, which tests read through it.
            key: ValueKey(payload),
            data: payload,
            size: 240,
            padding: EdgeInsets.zero,
            backgroundColor: colors.onSurface,
            eyeStyle: QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: colors.surface,
            ),
            dataModuleStyle: QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: colors.surface,
            ),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar(this.friend);

  final Friend friend;

  @override
  Widget build(BuildContext context) {
    final avatar = friend.avatarPath;
    return Center(
      child: ClipOval(
        child: SizedBox.square(
          dimension: 72,
          child: avatar == null
              ? ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                )
              : StorageImage(bucket: StorageBucket.avatars, path: avatar),
        ),
      ),
    );
  }
}
