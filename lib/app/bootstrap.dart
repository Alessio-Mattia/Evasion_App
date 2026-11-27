import 'package:evasion/app/app.dart';
import 'package:evasion/app/config/app_environment.dart';
import 'package:evasion/app/config/supabase_config.dart';
import 'package:evasion/app/theme/app_fonts.dart';
import 'package:evasion/core/map/map_config.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> bootstrap(AppEnvironment environment) async {
  assert(
    appFlavor == environment.name,
    'Entry point "${environment.name}" launched with native flavor '
    '"$appFlavor": pass the matching --flavor.',
  );

  WidgetsFlutterBinding.ensureInitialized();
  AppFonts.registerLicenses();
  MapConfig.fromEnvironment().apply();

  final supabaseConfig = SupabaseConfig.fromEnvironment();
  await Supabase.initialize(
    url: supabaseConfig.url,
    publishableKey: supabaseConfig.publishableKey,
  );

  runApp(
    ProviderScope(
      overrides: [appEnvironmentProvider.overrideWithValue(environment)],
      child: const EvasionApp(),
    ),
  );
}
