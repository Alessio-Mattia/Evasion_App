import 'package:evasion/core/config/business_rules.dart';
import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/core/scanner/scanner_view.dart';
import 'package:evasion/features/connections/domain/connection_qr.dart';
import 'package:evasion/features/connections/presentation/connect/connect_screen.dart';
import 'package:evasion/features/profile/domain/public_profile.dart';
import 'package:evasion/features/profile/presentation/other_profile/other_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/fake_connections_repository.dart';
import '../../../helpers/fake_location_service.dart';
import '../../../helpers/fake_profile_repositories.dart';
import '../../../helpers/fake_scanner_view.dart';
import '../../../helpers/pump_evasion_app.dart';

void main() {
  late FakeConnectionsRepository connections;
  late FakeScannerView scanner;
  late FakeLocationService location;
  late FakeProfileStore profiles;

  final noe = testFriend(name: 'Noé');
  const noeToken = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  setUp(() {
    connections = FakeConnectionsRepository();
    scanner = FakeScannerView();
    location = FakeLocationService();
    profiles = FakeProfileStore(completeProfile(testUser.id))
      ..others[noe.userId] = PublicProfile(
        id: noe.userId,
        displayName: noe.displayName,
        age: noe.age,
        isStudentVerified: noe.isStudentVerified,
      );
  });

  Future<void> openConnect(WidgetTester tester) async {
    await pumpEvasionApp(
      tester,
      connections: connections,
      scanner: scanner,
      location: location,
      profiles: profiles,
    );
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Messages'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip("Se connecter avec quelqu'un"));
    await tester.pumpAndSettle();
  }

  /// Leaves the screen, which stops its timers before the test ends.
  Future<void> closeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
  }

  String shownPayload(WidgetTester tester) =>
      (tester.widget<QrImageView>(find.byType(QrImageView)).key!
              as ValueKey<String>)
          .value;

  Future<void> tapTab(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(label),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The new friend's profile, in the messages tab, the connect screen left
  /// behind: the tab bar is the way out, and back to the messages.
  Future<void> expectNewFriendProfile(WidgetTester tester) async {
    expect(find.byType(OtherProfileScreen), findsOneWidget);
    expect(find.text('Noé, 23'), findsOneWidget);
    expect(find.byType(ConnectScreen), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);

    // Through another tab: the messages tab opens on its root again.
    await tapTab(tester, 'Profil');
    await tapTab(tester, 'Messages');
    expect(find.byType(OtherProfileScreen), findsNothing);
    expect(find.byType(ConnectScreen), findsNothing);
    expect(find.byTooltip("Se connecter avec quelqu'un"), findsOneWidget);
  }

  Future<void> showScanner(WidgetTester tester) async {
    await tester.tap(find.text('Scanner'));
    await tester.pumpAndSettle();
  }

  group('my QR code', () {
    testWidgets('the messages tab opens it, holding a fresh token', (
      tester,
    ) async {
      await openConnect(tester);

      expect(find.byType(ConnectScreen), findsOneWidget);
      expect(shownPayload(tester), qrPayloadFor(connections.currentToken!));

      await closeApp(tester);
    });

    testWidgets('is renewed before it expires', (tester) async {
      await openConnect(tester);
      final first = connections.currentToken;

      await tester.pump(
        BusinessRules.connectionTokenLifetime -
            BusinessRules.connectionTokenRenewMargin,
      );
      await tester.pumpAndSettle();

      expect(connections.currentToken, isNot(first));
      expect(shownPayload(tester), qrPayloadFor(connections.currentToken!));

      await closeApp(tester);
    });

    testWidgets('shows who scanned it, then stops asking', (tester) async {
      await openConnect(tester);

      connections
        ..scannedBy = noe
        ..friends.add(noe);
      await tester.pump(BusinessRules.connectionScanPollInterval);
      await tester.pumpAndSettle();

      expect(find.text('Noé vient de se connecter avec toi.'), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
      final calls = connections.whoScannedCalls;
      await tester.pump(BusinessRules.connectionScanPollInterval * 3);
      expect(connections.whoScannedCalls, calls);

      await tester.tap(find.text('Voir son profil'));
      await tester.pumpAndSettle();
      await expectNewFriendProfile(tester);

      await closeApp(tester);
    });

    testWidgets('the connection can be undone, then a new code shown', (
      tester,
    ) async {
      await openConnect(tester);
      connections
        ..scannedBy = noe
        ..friends.add(noe);
      await tester.pump(BusinessRules.connectionScanPollInterval);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Annuler la connexion'));
      await tester.pumpAndSettle();

      expect(connections.friends, isEmpty);
      expect(
        find.textContaining('La connexion avec Noé est annulée'),
        findsOne,
      );

      await tester.tap(find.text('Afficher un nouveau code'));
      await tester.pumpAndSettle();
      expect(shownPayload(tester), qrPayloadFor(connections.currentToken!));

      await closeApp(tester);
    });

    testWidgets('a failure says why and can be retried', (tester) async {
      connections.failure = const NetworkFailure();
      await openConnect(tester);

      expect(find.byType(QrImageView), findsNothing);
      expect(find.textContaining('connexion'), findsWidgets);

      connections.failure = null;
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsOneWidget);

      await closeApp(tester);
    });
  });

  group('scanning', () {
    testWidgets('a QR code makes the two friends, once', (tester) async {
      connections.othersTokens[noeToken] = noe;
      await openConnect(tester);
      await showScanner(tester);
      expect(find.byKey(FakeScannerView.key), findsOneWidget);
      expect(
        find.text('Vise le QR code de la personne que tu rencontres.'),
        findsOne,
      );

      scanner.see(qrPayloadFor(noeToken));
      await tester.pumpAndSettle();
      // The camera keeps seeing the same code.
      scanner.see(qrPayloadFor(noeToken));
      await tester.pumpAndSettle();

      expect(find.text("C'est fait : vous êtes maintenant amis !"), findsOne);
      expect(connections.friends, [noe]);

      await tester.tap(find.text('Voir son profil'));
      await tester.pumpAndSettle();
      await expectNewFriendProfile(tester);

      await closeApp(tester);
    });

    testWidgets('says when the two were already friends', (tester) async {
      connections
        ..othersTokens[noeToken] = noe
        ..friends.add(noe);
      await openConnect(tester);
      await showScanner(tester);

      scanner.see(qrPayloadFor(noeToken));
      await tester.pumpAndSettle();

      expect(find.text('Vous étiez déjà amis.'), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('another QR code is told apart without the server', (
      tester,
    ) async {
      await openConnect(tester);
      await showScanner(tester);

      scanner.see('https://example.com/menu');
      await tester.pumpAndSettle();

      expect(find.text("Ce n'est pas un QR code Evasion."), findsOneWidget);
      expect(connections.friends, isEmpty);
      await closeApp(tester);
    });

    testWidgets('an expired or used QR code asks for a new one', (
      tester,
    ) async {
      await openConnect(tester);
      await showScanner(tester);

      scanner.see(qrPayloadFor(noeToken));
      await tester.pumpAndSettle();

      expect(find.textContaining("n'est plus valable"), findsOneWidget);

      // Scanning again works once the other renewed their code.
      connections.othersTokens[noeToken] = noe;
      await tester.tap(find.text('Scanner un autre code'));
      await tester.pumpAndSettle();
      scanner.see(qrPayloadFor(noeToken));
      await tester.pumpAndSettle();
      expect(find.textContaining('vous êtes maintenant amis'), findsOneWidget);

      await closeApp(tester);
    });

    testWidgets('a refused QR code must be scanned in person', (tester) async {
      await openConnect(tester);
      // The user's own QR code, shown first.
      final ownToken = connections.currentToken!;
      await showScanner(tester);

      scanner.see(qrPayloadFor(ownToken));
      await tester.pumpAndSettle();

      expect(find.textContaining('doit être scanné sur place'), findsOne);
      await closeApp(tester);
    });

    testWidgets('a refused camera leads to the settings', (tester) async {
      scanner.problem = ScannerProblem.permissionDenied;
      await openConnect(tester);
      await showScanner(tester);

      expect(find.textContaining('besoin de la caméra'), findsOneWidget);
      // Nothing to aim at.
      expect(find.textContaining('Vise le QR code'), findsNothing);
      await tester.tap(find.text('Ouvrir les réglages'));
      expect(location.settingsOpened, 1);

      await closeApp(tester);
    });
  });
}
