import 'package:evasion/app/app.dart';
import 'package:evasion/app/config/app_environment.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void bootstrap(AppEnvironment environment) {
  assert(
    appFlavor == environment.name,
    'Entry point "${environment.name}" launched with native flavor '
    '"$appFlavor": pass the matching --flavor.',
  );

  runApp(
    ProviderScope(
      overrides: [appEnvironmentProvider.overrideWithValue(environment)],
      child: const EvasionApp(),
    ),
  );
}
