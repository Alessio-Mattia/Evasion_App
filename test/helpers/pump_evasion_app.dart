import 'package:evasion/app/app.dart';
import 'package:evasion/app/config/app_environment.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpEvasionApp(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appEnvironmentProvider.overrideWithValue(AppEnvironment.dev)],
      child: const EvasionApp(),
    ),
  );
  await tester.pumpAndSettle();
}
