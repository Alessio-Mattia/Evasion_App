import 'package:evasion/core/models/geo_point.dart';
import 'package:evasion/core/services/location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_location_service.dart';
import '../../../helpers/fake_map_view.dart';
import '../../../helpers/fake_posts_repository.dart';
import '../../../helpers/pump_evasion_app.dart';

/// A small area whose centre is [center].
GeoBounds areaAround(GeoPoint center) => (
  southWest: (
    latitude: center.latitude - 0.005,
    longitude: center.longitude - 0.005,
  ),
  northEast: (
    latitude: center.latitude + 0.005,
    longitude: center.longitude + 0.005,
  ),
);

/// About 1 km north of the test position.
const GeoPoint nearby = (latitude: 46.529, longitude: 6.63);

/// About 10 km north of the test position.
const GeoPoint faraway = (latitude: 46.61, longitude: 6.63);

void main() {
  late FakePostsRepository posts;
  late FakeLocationService location;
  late FakeMapView map;

  setUp(() {
    posts = FakePostsRepository();
    location = FakeLocationService();
    map = FakeMapView();
  });

  /// The test window is smaller than a phone: the form scrolls.
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> openPicker(WidgetTester tester) async {
    await pumpEvasionApp(tester, posts: posts, location: location, map: map);
    await tester.tap(find.byTooltip('Créer un post'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.widgetWithText(TextButton, 'Changer'));
  }

  Future<void> moveMapTo(WidgetTester tester, GeoPoint center) async {
    map.showArea(areaAround(center));
    await tester.pumpAndSettle();
  }

  Finder confirmButton() =>
      find.widgetWithText(FilledButton, 'Choisir ce lieu');

  bool canConfirm(WidgetTester tester) =>
      tester.widget<FilledButton>(confirmButton()).onPressed != null;

  testWidgets('draws the allowed circle around the phone', (tester) async {
    await openPicker(tester);

    expect(find.text('Choisir le lieu'), findsOneWidget);
    final circle = map.markers.single;
    expect(circle.position, testPosition);
  });

  testWidgets('a place nearby is chosen and sent with the post', (
    tester,
  ) async {
    await openPicker(tester);
    await moveMapTo(tester, nearby);
    expect(canConfirm(tester), isTrue);

    await tester.tap(confirmButton());
    await tester.pumpAndSettle();
    expect(find.text('Lieu choisi sur la carte'), findsOneWidget);

    await tapVisible(tester, find.text('Ajouter une photo'));
    await tapVisible(tester, find.text('Choisir dans ma galerie'));
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Publier'));

    final (draft, device) = posts.createdDrafts.single;
    expect(draft.place, nearby);
    expect(device, testPosition);
  });

  testWidgets('a place too far cannot be chosen', (tester) async {
    await openPicker(tester);

    await moveMapTo(tester, faraway);

    expect(canConfirm(tester), isFalse);
    expect(find.text('Trop loin de toi (5 km au maximum)'), findsOneWidget);
  });

  testWidgets('without the position, nothing can be chosen', (tester) async {
    location.error = const LocationServiceDisabled();
    await openPicker(tester);
    // The map may report an area all the same.
    await moveMapTo(tester, nearby);

    expect(canConfirm(tester), isFalse);
    expect(find.textContaining('Ta position est nécessaire'), findsOneWidget);
  });

  testWidgets('back to my position forgets the place', (tester) async {
    await openPicker(tester);
    await moveMapTo(tester, nearby);
    await tester.tap(confirmButton());
    await tester.pumpAndSettle();

    await tapVisible(tester, find.text('Revenir à ma position'));

    expect(find.text('Ma position actuelle'), findsOneWidget);
    expect(find.text('Revenir à ma position'), findsNothing);
  });
}
