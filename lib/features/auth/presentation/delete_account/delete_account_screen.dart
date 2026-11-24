import 'package:evasion/core/config/business_rules.dart';
import 'package:evasion/core/widgets/failure_snack_bar.dart';
import 'package:evasion/core/widgets/form_page_layout.dart';
import 'package:evasion/features/auth/data/supabase_auth_repository.dart';
import 'package:evasion/features/auth/domain/auth_validators.dart';
import 'package:evasion/features/auth/presentation/delete_account/delete_account_controllers.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Deletes the account, after a new code sent by email: an unlocked phone in
/// someone else's hands is not enough. The screen itself is the confirmation.
///
/// Once the account is deleted, the user is signed out and the router shows
/// the sign-in screen.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _code = TextEditingController();
  bool _codeSent = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final sent = await ref
        .read(sendDeletionCodeControllerProvider.notifier)
        .send();
    if (sent && mounted) setState(() => _codeSent = true);
  }

  Future<void> _delete() async {
    // The app's messenger outlives this screen, which closes on sign-out.
    final messenger = ScaffoldMessenger.of(context);
    final done = AppLocalizations.of(context).deleteAccountDone;
    final deleted = await ref
        .read(deleteAccountControllerProvider.notifier)
        .delete(_code.text);
    if (!deleted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(done)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    for (final provider in [
      sendDeletionCodeControllerProvider,
      deleteAccountControllerProvider,
    ]) {
      ref.listen(provider, (_, next) {
        if (next case AsyncError(:final error)) {
          showFailureSnackBar(context, error);
        }
      });
    }
    final isSending = ref.watch(sendDeletionCodeControllerProvider).isLoading;
    final isDeleting = ref.watch(deleteAccountControllerProvider).isLoading;
    final email = ref.watch(authRepositoryProvider).currentUser?.email ?? '';

    return FormPageLayout(
      appBar: AppBar(),
      title: l10n.deleteAccountTitle,
      subtitle: l10n.deleteAccountSubtitle,
      children: [
        if (!_codeSent)
          LoadingButton(
            label: l10n.deleteAccountSendCode,
            isLoading: isSending,
            onPressed: _sendCode,
          )
        else ...[
          Text(l10n.deleteAccountCodeSentTo(email)),
          TextField(
            controller: _code,
            decoration: InputDecoration(
              labelText: l10n.signInCodeLabel,
              counterText: '',
            ),
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: BusinessRules.signInCodeLength,
            // No submission on the last digit, unlike sign-in: deleting
            // needs a deliberate tap.
            onChanged: (_) => setState(() {}),
          ),
          LoadingButton(
            label: l10n.deleteAccountConfirm,
            isLoading: isDeleting,
            isDestructive: true,
            onPressed: isValidSignInCode(_code.text) ? _delete : null,
          ),
          TextButton(
            onPressed: isSending || isDeleting ? null : _sendCode,
            child: Text(l10n.signInResendCode),
          ),
        ],
      ],
    );
  }
}
