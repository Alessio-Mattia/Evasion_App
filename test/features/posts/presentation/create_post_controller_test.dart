import 'dart:async';

import 'package:evasion/core/config/business_rules.dart';
import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/core/photos/photo_file.dart';
import 'package:evasion/core/services/location_service.dart';
import 'package:evasion/features/posts/data/supabase_posts_repository.dart';
import 'package:evasion/features/posts/domain/post.dart';
import 'package:evasion/features/posts/domain/post_draft.dart';
import 'package:evasion/features/posts/presentation/create_post/create_post_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_location_service.dart';
import '../../../helpers/fake_photo_picker.dart';
import '../../../helpers/fake_posts_repository.dart';

const userId = 'user-1';

void main() {
  late FakeLocationService location;
  late FakePostsRepository posts;
  late ProviderContainer container;

  setUp(() {
    location = FakeLocationService();
    posts = FakePostsRepository();
    container = ProviderContainer(
      overrides: [
        locationServiceProvider.overrideWithValue(location),
        postsRepositoryProvider.overrideWithValue(posts),
      ],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    // Keeps the auto-dispose controller alive during the test.
    container.listen(createPostControllerProvider(userId), (_, _) {});
  });

  PostDraft draft({String caption = ''}) =>
      PostDraft(photo: pngBytes, format: PhotoFormat.png, caption: caption);

  Future<bool> publish(PostDraft draft) => container
      .read(createPostControllerProvider(userId).notifier)
      .publish(draft);

  Object? error() => container.read(createPostControllerProvider(userId)).error;

  test('publishes at the phone position, blurred and for a day', () async {
    expect(await publish(draft(caption: ' Café ')), isTrue);

    final (sent, position) = posts.createdDrafts.single;
    expect(position, testPosition);
    expect(sent.precision, PostPrecision.fuzzy);
    expect(sent.lifetime, BusinessRules.postDefaultLifetime);
    expect(sent.audience, PostAudience.everyone);
    expect(posts.posts.single.caption, 'Café');
  });

  test('an invalid draft reads no position and sends nothing', () async {
    final tooLong = draft(
      caption: 'a' * (BusinessRules.postCaptionMaxLength + 1),
    );

    expect(await publish(tooLong), isFalse);

    expect(location.reads, 0);
    expect(posts.createdDrafts, isEmpty);
    expect(error(), isA<InvalidInputFailure>());
  });

  group('without a position, nothing is sent', () {
    for (final (name, failure) in [
      ('location refused', const LocationAccessDenied(permanently: false)),
      (
        'location refused for good',
        const LocationAccessDenied(permanently: true),
      ),
      ('location turned off', const LocationServiceDisabled()),
      ('no position in time', TimeoutException('no fix')),
    ]) {
      test(name, () async {
        location.error = failure;

        expect(await publish(draft()), isFalse);

        expect(posts.createdDrafts, isEmpty);
        expect(error(), same(failure));
      });
    }
  });

  test('the quota of active posts is reported', () async {
    for (var i = 0; i < BusinessRules.activePostsMax; i++) {
      await publish(draft());
    }

    expect(await publish(draft()), isFalse);

    expect(error(), isA<LimitReachedFailure>());
  });

  test('a second publication while the first runs is ignored', () async {
    final results = await Future.wait([publish(draft()), publish(draft())]);

    expect(results, [isTrue, isFalse]);
    expect(posts.createdDrafts, hasLength(1));
  });
}
