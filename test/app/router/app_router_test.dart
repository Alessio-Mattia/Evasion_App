import 'package:evasion/features/chat/presentation/messaging_screen.dart';
import 'package:evasion/features/map/presentation/home_screen.dart';
import 'package:evasion/features/posts/presentation/add_post_screen.dart';
import 'package:evasion/features/profile/presentation/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_evasion_app.dart';

Finder _navLabel(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

void main() {
  testWidgets('shows the four tabs with their French labels', (tester) async {
    await pumpEvasionApp(tester);

    for (final label in ['Accueil', 'Messagerie', 'Ajout', 'Profil']) {
      expect(_navLabel(label), findsOneWidget);
    }
  });

  testWidgets('tapping a tab shows its screen', (tester) async {
    await pumpEvasionApp(tester);

    final screensByLabel = {
      'Messagerie': MessagingScreen,
      'Ajout': AddPostScreen,
      'Profil': ProfileScreen,
      'Accueil': HomeScreen,
    };
    for (final MapEntry(key: label, value: screen) in screensByLabel.entries) {
      await tester.tap(_navLabel(label));
      await tester.pumpAndSettle();

      expect(find.byType(screen), findsOneWidget);
    }
  });

  testWidgets('a tab keeps its state when switching away and back', (
    tester,
  ) async {
    await pumpEvasionApp(tester);
    final homeElement = tester.element(find.byType(HomeScreen));

    await tester.tap(_navLabel('Profil'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsNothing);

    await tester.tap(_navLabel('Accueil'));
    await tester.pumpAndSettle();
    expect(tester.element(find.byType(HomeScreen)), same(homeElement));
  });
}
