import 'package:evasion/core/config/business_rules.dart';
import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/core/map/map_view.dart';
import 'package:evasion/core/models/geo_point.dart';
import 'package:evasion/features/posts/data/supabase_posts_repository.dart';
import 'package:evasion/features/posts/domain/post.dart';
import 'package:evasion/features/posts/presentation/map/map_feed_controller.dart';
import 'package:evasion/features/posts/presentation/map/post_markers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_posts_repository.dart';

/// About 2 km around Lausanne.
const GeoBounds lausanne = (
  southWest: (latitude: 46.51, longitude: 6.62),
  northEast: (latitude: 46.53, longitude: 6.65),
);

/// Far more than 50 km on a side.
const GeoBounds switzerland = (
  southWest: (latitude: 45.8, longitude: 5.9),
  northEast: (latitude: 47.8, longitude: 10.5),
);

Post post(
  String id, {
  PostPrecision precision = PostPrecision.fuzzy,
  bool isPinned = false,
}) => Post(
  id: id,
  authorId: 'someone',
  imagePath: 'someone/$id.jpg',
  latitude: 46.52,
  longitude: 6.63,
  precision: precision,
  createdAt: DateTime.now(),
  expiresAt: DateTime.now().add(const Duration(hours: 5)),
  isPinned: isPinned,
);

void main() {
  late FakePostsRepository posts;
  late ProviderContainer container;

  setUp(() {
    posts = FakePostsRepository();
    container = ProviderContainer(
      overrides: [postsRepositoryProvider.overrideWithValue(posts)],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    // Keeps the auto-dispose controller alive during the test.
    container.listen(mapFeedControllerProvider, (_, _) {});
  });

  MapFeedController controller() =>
      container.read(mapFeedControllerProvider.notifier);
  MapFeed feed() => container.read(mapFeedControllerProvider);

  group('postMarkers', () {
    test('a blurred post is an area covering its cell, never a pin', () {
      final [marker] = postMarkers([post('p1')]);

      expect(marker.id, 'p1');
      expect(marker.position, (latitude: 46.52, longitude: 6.63));
      expect(
        (marker.shape as MapArea).radiusMeters,
        greaterThanOrEqualTo(BusinessRules.postFuzzyCellSizeMeters * 0.7),
      );
    });

    test('an exact post is a point', () {
      final [marker] = postMarkers([
        post('p1', precision: PostPrecision.exact),
      ]);

      expect(marker.shape, isA<MapPoint>());
    });
  });

  test('loads the posts of the area shown', () async {
    posts.othersPosts.add(post('p1'));

    await controller().showArea(lausanne);

    expect(posts.requestedAreas, [lausanne]);
    expect(feed().posts.map((post) => post.id), ['p1']);
    expect(feed().areaTooLarge, isFalse);
  });

  test('zoomed out too far, asks for nothing and says so', () async {
    posts.othersPosts.add(post('p1'));
    await controller().showArea(lausanne);

    await controller().showArea(switzerland);

    expect(posts.requestedAreas, [lausanne]);
    expect(feed().posts, isEmpty);
    expect(feed().areaTooLarge, isTrue);
  });

  test('a failed load keeps the posts and reports why', () async {
    posts.othersPosts.add(post('p1'));
    await controller().showArea(lausanne);

    posts.failure = const NetworkFailure();
    await controller().showArea(lausanne);

    expect(feed().posts.map((post) => post.id), ['p1']);
    expect(feed().failure, isA<NetworkFailure>());
  });

  test('refresh loads the last area again', () async {
    await controller().showArea(lausanne);
    posts.othersPosts.add(post('new'));

    await controller().refresh();

    expect(feed().posts.map((post) => post.id), ['new']);
  });

  group('togglePin', () {
    setUp(() => posts.othersPosts.add(post('p1')));

    test('pins, then unpins', () async {
      await controller().showArea(lausanne);

      expect(await controller().togglePin(feed().posts.single), isTrue);
      expect(feed().posts.single.isPinned, isTrue);
      expect(posts.pins, {'p1'});

      expect(await controller().togglePin(feed().posts.single), isTrue);
      expect(feed().posts.single.isPinned, isFalse);
      expect(posts.pins, isEmpty);
    });

    test('a failure puts the post back as it was', () async {
      await controller().showArea(lausanne);
      posts.failure = const NetworkFailure();

      expect(await controller().togglePin(feed().posts.single), isFalse);

      expect(feed().posts.single.isPinned, isFalse);
      expect(feed().failure, isA<NetworkFailure>());
    });

    test('a post no longer available leaves the map', () async {
      await controller().showArea(lausanne);
      posts.failure = const NotFoundFailure();

      expect(await controller().togglePin(feed().posts.single), isFalse);

      expect(feed().posts, isEmpty);
      expect(feed().failure, isA<NotFoundFailure>());
    });
  });
}
