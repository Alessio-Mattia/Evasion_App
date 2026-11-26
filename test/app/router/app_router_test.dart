import 'package:evasion/features/chat/presentation/messaging_screen.dart';
import 'package:evasion/features/encounters/presentation/crossings_screen.dart';
import 'package:evasion/features/posts/presentation/create_post/create_post_screen.dart';
import 'package:evasion/features/posts/presentation/map/posts_map_screen.dart';
import 'package:evasion/features/profile/presentation/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_evasion_app.dart';

Finder _navLabel(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

void main() {
  testWidgets('shows the four tabs with their French labels', (tester) async {
    await pumpEvasionApp(tester);

    for (final label in ['Carte', 'Croisements', 'Messages', 'Profil']) {
      expect(_navLabel(label), findsOneWidget);
    }
  });

  testWidgets('tapping a tab shows its screen', (tester) async {
    await pumpEvasionApp(tester);

    final screensByLabel = {
      'Croisements': CrossingsScreen,
      'Messages': MessagingScreen,
      'Profil': ProfileScreen,
      'Carte': PostsMapScreen,
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
    final homeElement = tester.element(find.byType(PostsMapScreen));

    await tester.tap(_navLabel('Profil'));
    await tester.pumpAndSettle();
    expect(find.byType(PostsMapScreen), findsNothing);

    await tester.tap(_navLabel('Carte'));
    await tester.pumpAndSettle();
    expect(tester.element(find.byType(PostsMapScreen)), same(homeElement));
  });

  testWidgets('the map opens post creation over the tabs', (tester) async {
    await pumpEvasionApp(tester);

    await tester.tap(find.byTooltip('Créer un post'));
    await tester.pumpAndSettle();

    expect(find.byType(CreatePostScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
