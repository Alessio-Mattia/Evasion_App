import 'package:evasion/core/config/business_rules.dart';
import 'package:evasion/core/validation/profile_validators.dart';
import 'package:evasion/core/widgets/form_page_layout.dart';
import 'package:evasion/features/onboarding/presentation/onboarding_app_bar.dart';
import 'package:evasion/features/onboarding/presentation/onboarding_controllers.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DisplayNameStep extends ConsumerStatefulWidget {
  const DisplayNameStep({required this.onContinue, super.key});

  final Future<void> Function() onContinue;

  @override
  ConsumerState<DisplayNameStep> createState() => _DisplayNameStepState();
}

class _DisplayNameStepState extends ConsumerState<DisplayNameStep> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: ref.read(onboardingControllerProvider).value?.displayName,
  );

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    ref
        .read(onboardingControllerProvider.notifier)
        .setDisplayName(_nameController.text);
    await widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FormPageLayout(
      appBar: const OnboardingAppBar(),
      title: l10n.onboardingNameTitle,
      subtitle: l10n.onboardingNameSubtitle,
      children: [
        Form(
          key: _formKey,
          child: TextFormField(
            controller: _nameController,
            decoration: InputDecoration(labelText: l10n.onboardingNameLabel),
            autofillHints: const [AutofillHints.givenName],
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            validator: (value) => switch (validateDisplayName(value ?? '')) {
              DisplayNameError.empty => l10n.onboardingNameEmpty,
              DisplayNameError.tooLong => l10n.onboardingNameTooLong(
                BusinessRules.displayNameMaxLength,
              ),
              null => null,
            },
            onFieldSubmitted: (_) => _submit(),
          ),
        ),
        LoadingButton(
          label: l10n.onboardingContinue,
          isLoading: false,
          onPressed: _submit,
        ),
      ],
    );
  }
}
