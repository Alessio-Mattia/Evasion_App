import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/core/errors/app_failure_message.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('fr'));

  const failures = <AppFailure>[
    NetworkFailure(),
    UnauthenticatedFailure(),
    PermissionDeniedFailure(),
    NotFoundFailure(),
    ConflictFailure(),
    UnexpectedFailure(),
  ];

  test('every failure has its own French message', () {
    final messages = failures.map((failure) => failure.message(l10n)).toList();

    expect(messages, everyElement(isNotEmpty));
    expect(messages.toSet(), hasLength(failures.length));
  });

  test('a network failure shows the network message', () {
    expect(const NetworkFailure().message(l10n), l10n.errorNetwork);
  });
}
