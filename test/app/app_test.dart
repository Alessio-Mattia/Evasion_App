import 'package:evasion/features/posts/presentation/map/posts_map_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_evasion_app.dart';

void main() {
  testWidgets('starts on the home tab, in dark theme and in French', (
    tester,
  ) async {
    await pumpEvasionApp(tester);

    expect(find.byType(PostsMapScreen), findsOneWidget);

    final context = tester.element(find.byType(PostsMapScreen));
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(Localizations.localeOf(context), const Locale('fr'));
  });
}
