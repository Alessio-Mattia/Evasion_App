import 'package:evasion/app/router/app_routes.dart';
import 'package:evasion/core/widgets/failure_snack_bar.dart';
import 'package:evasion/features/auth/domain/auth_validators.dart';
import 'package:evasion/features/auth/presentation/sign_in_controllers.dart';
import 'package:evasion/features/auth/presentation/sign_in_layout.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// First sign-in step: the user enters their email and receives a code.
class SignInEmailScreen extends ConsumerStatefulWidget {
  const SignInEmailScreen({super.key});

  @override
  ConsumerState<SignInEmailScreen> createState() => _SignInEmailScreenState();
}

class _SignInEmailScreenState extends ConsumerState<SignInEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // The button and the keyboard's done key can both submit.
    if (ref.read(sendCodeControllerProvider).isLoading) return;
    if (!_formKey.currentState!.validate()) return;
    final email = normalizeEmail(_emailController.text);
    final sent = await ref
        .read(sendCodeControllerProvider.notifier)
        .sendCode(email);
    if (sent && mounted) await context.push(AppRoutes.signInCodeFor(email));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isLoading = ref.watch(sendCodeControllerProvider).isLoading;
    ref.listen(sendCodeControllerProvider, (_, next) {
      if (next case AsyncError(:final error)) {
        showFailureSnackBar(context, error);
      }
    });

    return SignInLayout(
      title: l10n.signInTitle,
      subtitle: l10n.signInSubtitle,
      children: [
        Form(
          key: _formKey,
          child: TextFormField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: l10n.signInEmailLabel,
              helperText: l10n.signInStudentHint,
              helperMaxLines: 2,
            ),
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            autocorrect: false,
            textInputAction: TextInputAction.done,
            validator: (value) =>
                isValidEmail(value ?? '') ? null : l10n.signInEmailInvalid,
            onFieldSubmitted: (_) => _submit(),
          ),
        ),
        SignInSubmitButton(
          label: l10n.signInSendCode,
          isLoading: isLoading,
          onPressed: _submit,
        ),
      ],
    );
  }
}
