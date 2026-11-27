import 'package:evasion/core/config/business_rules.dart';
import 'package:evasion/core/map/map_view.dart';
import 'package:evasion/core/models/geo_point.dart';
import 'package:evasion/core/services/location_service.dart';
import 'package:evasion/features/posts/domain/post.dart';
import 'package:evasion/features/posts/presentation/map/post_card.dart';
import 'package:evasion/features/posts/presentation/map/posts_map_screen.dart';
import 'package:evasion/l10n/generated/app_localizations_fr.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_location_service.dart';
import '../../../helpers/fake_map_view.dart';
import '../../../helpers/fake_posts_repository.dart';
import '../../../helpers/pump_evasion_app.dart';
import 'map_feed_controller_test.dart' show lausanne, post, switzerland;

void main() {
  late FakePostsRepository posts;
  late FakeLocationService location;
  late FakeMapView map;

  setUp(() {
    posts = FakePostsRepository();
    location = FakeLocationService();
    map = FakeMapView();
  });

  Future<void> openMap(WidgetTester tester) async {
    await pumpEvasionApp(tester, posts: posts, location: location, map: map);
  }

  Future<void> showArea(WidgetTester tester, GeoBounds area) async {
    map.showArea(area);
    await tester.pumpAndSettle();
  }

  test('time left is said in the largest whole unit', () {
    final l10n = AppLocalizationsFr();
    final now = DateTime(2026, 11, 26, 12);

    expect(
      timeLeft(l10n, now.add(const Duration(days: 3)), now),
      'encore 3 jours',
    );
    expect(
      timeLeft(l10n, now.add(const Duration(hours: 5)), now),
      'encore 5 h',
    );
    expect(
      timeLeft(l10n, now.add(const Duration(minutes: 20)), now),
      'encore 20 min',
    );
    expect(
      timeLeft(l10n, now.add(const Duration(seconds: 10)), now),
      'encore 1 min',
    );
  });

  testWidgets('the map fills the screen above the tabs', (tester) async {
    await openMap(tester);

    // It once took only the width of the title.
    final screen = tester.getSize(find.byType(PostsMapScreen));
    expect(tester.getSize(find.byKey(FakeMapView.key)).width, screen.width);
  });

  testWidgets('opens on the campus, then moves to the phone', (tester) async {
    await openMap(tester);

    expect(map.props!.initialCenter, BusinessRules.mapDefaultCenter);
    expect(map.props!.focus, testPosition);
    expect(map.props!.showUserLocation, isTrue);
  });

  testWidgets('without the location, stays on the campus', (tester) async {
    location.error = const LocationAccessDenied(permanently: false);

    await openMap(tester);

    expect(map.props!.focus, isNull);
    expect(map.props!.showUserLocation, isFalse);
  });

  testWidgets('shows the posts of the area, blurred ones as areas', (
    tester,
  ) async {
    posts.othersPosts.addAll([
      post('blurred'),
      post('exact', precision: PostPrecision.exact),
    ]);
    await openMap(tester);

    await showArea(tester, lausanne);

    final shapes = {for (final marker in map.markers) marker.id: marker.shape};
    expect(shapes['blurred'], isA<MapArea>());
    expect(shapes['exact'], isA<MapPoint>());
  });

  testWidgets('zoomed out too far, asks to zoom in', (tester) async {
    await openMap(tester);

    await showArea(tester, switzerland);

    expect(find.text('Zoome pour voir les posts'), findsOneWidget);
    expect(posts.requestedAreas, isEmpty);
  });

  testWidgets('a tap shows the post, and pins it', (tester) async {
    posts.othersPosts.add(
      post('p1').copyWith(caption: 'Soleil sur les quais', authorName: 'Léa'),
    );
    await openMap(tester);
    await showArea(tester, lausanne);

    map.tapMarker('p1');
    await tester.pumpAndSettle();

    expect(find.text('Soleil sur les quais'), findsOneWidget);
    expect(find.text('Léa'), findsOneWidget);
    expect(find.textContaining('encore'), findsOneWidget);
    expect(map.props!.selectedId, 'p1');

    await tester.tap(find.byTooltip('Épingler'));
    await tester.pumpAndSettle();
    expect(posts.pins, {'p1'});
    expect(find.byTooltip("Retirer l'épingle"), findsOneWidget);

    map.tapEmpty();
    await tester.pumpAndSettle();
    expect(find.byType(PostCard), findsNothing);
  });
}
