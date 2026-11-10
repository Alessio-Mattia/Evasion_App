import 'dart:async';

import 'package:evasion/app/router/app_routes.dart';
import 'package:evasion/core/config/business_rules.dart';
import 'package:evasion/core/widgets/failure_snack_bar.dart';
import 'package:evasion/core/widgets/form_page_layout.dart';
import 'package:evasion/features/auth/domain/auth_validators.dart';
import 'package:evasion/features/auth/presentation/sign_in_controllers.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Second sign-in step: the user enters the code received by [email].
///
/// On success the router leaves this screen by itself, as the session changes.
class SignInCodeScreen extends ConsumerStatefulWidget {
  const SignInCodeScreen({required this.email, super.key});

  final String email;

  @override
  ConsumerState<SignInCodeScreen> createState() => _SignInCodeScreenState();
}

class _SignInCodeScreenState extends ConsumerState<SignInCodeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    // The last digit and the keyboard's done key can both submit: a code can
    // only be used once, so a second call would fail.
    if (ref.read(verifyCodeControllerProvider).isLoading) return;
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(verifyCodeControllerProvider.notifier)
        .verifyCode(email: widget.email, code: _codeController.text);
  }

  Future<void> _resend() async {
    if (ref.read(sendCodeControllerProvider).isLoading) return;
    final l10n = AppLocalizations.of(context);
    final sent = await ref
        .read(sendCodeControllerProvider.notifier)
        .sendCode(widget.email);
    if (!sent || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.signInCodeResent)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const codeLength = BusinessRules.signInCodeLength;
    final isVerifying = ref.watch(verifyCodeControllerProvider).isLoading;
    final isResending = ref.watch(sendCodeControllerProvider).isLoading;
    for (final provider in [
      verifyCodeControllerProvider,
      sendCodeControllerProvider,
    ]) {
      ref.listen(provider, (_, next) {
        if (next case AsyncError(:final error)) {
          showFailureSnackBar(context, error);
        }
      });
    }

    return FormPageLayout(
      appBar: AppBar(),
      title: l10n.signInCodeTitle,
      subtitle: l10n.signInCodeSentTo(codeLength, widget.email),
      children: [
        Form(
          key: _formKey,
          child: TextFormField(
            controller: _codeController,
            decoration: InputDecoration(
              labelText: l10n.signInCodeLabel,
              counterText: '',
            ),
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: codeLength,
            textInputAction: TextInputAction.done,
            validator: (value) => isValidSignInCode(value ?? '')
                ? null
                : l10n.signInCodeInvalid(codeLength),
            // Submits as soon as the last digit is typed or pasted.
            onChanged: (value) {
              if (value.length == codeLength) unawaited(_verify());
            },
            onFieldSubmitted: (_) => _verify(),
          ),
        ),
        LoadingButton(
          label: l10n.signInVerify,
          isLoading: isVerifying,
          onPressed: _verify,
        ),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: isResending ? null : _resend,
              child: Text(l10n.signInResendCode),
            ),
            TextButton(
              onPressed: () => context.go(AppRoutes.signIn),
              child: Text(l10n.signInChangeEmail),
            ),
          ],
        ),
      ],
    );
  }
}
