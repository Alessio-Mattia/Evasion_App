import 'dart:convert';
import 'dart:io';

import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/core/photos/photo_file.dart';
import 'package:evasion/features/posts/data/supabase_posts_repository.dart';
import 'package:evasion/features/posts/domain/post.dart';
import 'package:evasion/features/posts/domain/post_draft.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../helpers/fake_photo_picker.dart';

/// A request received by the stand-in server.
typedef Received = ({String method, Uri uri, Object? body});

/// An answer of the stand-in server: an HTTP status and a JSON body.
typedef Answer = ({int status, Object? body});

const userId = 'user-1';
const device = (latitude: 46.5191, longitude: 6.5668);
const photosPath = '/storage/v1/object/post-photos';

/// The path in post-photos of an upload request.
String uploadedPath(Received upload) =>
    upload.uri.path.replaceFirst('$photosPath/', '');

Post post() => Post(
  id: 'post-1',
  authorId: userId,
  imagePath: '$userId/a.jpg',
  latitude: 46.5191,
  longitude: 6.5668,
  precision: PostPrecision.fuzzy,
  createdAt: DateTime.utc(2026, 11, 25),
  expiresAt: DateTime.utc(2026, 11, 26),
);

/// Checks the requests sent to Supabase, through a small local HTTP server that
/// stands in for it and answers with [answer].
void main() {
  late HttpServer server;
  late SupabasePostsRepository repository;
  late List<Received> requests;
  late Answer Function(Received request) answer;

  setUp(() async {
    requests = [];
    answer = (_) => (status: 200, body: <Object>[]);
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final bytes = [for (final chunk in await request.toList()) ...chunk];
      final isJson = request.headers.contentType?.subType == 'json';
      final received = (
        method: request.method,
        uri: request.uri,
        // A photo upload sends the image itself: only its size is kept.
        body: bytes.isEmpty
            ? null
            : isJson
            ? jsonDecode(utf8.decode(bytes))
            : bytes.length,
      );
      requests.add(received);
      final (:status, :body) = answer(received);
      request.response
        ..statusCode = status
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(body));
      await request.response.close();
    });
    repository = SupabasePostsRepository(
      SupabaseClient('http://127.0.0.1:${server.port}', 'test-key'),
    );
  });

  tearDown(() => server.close(force: true));

  group('createPost', () {
    test('uploads the photo, then creates the post with defaults', () async {
      answer = (request) => request.uri.path.startsWith('/storage')
          ? (status: 200, body: {'Key': 'post-photos/x.jpg'})
          : (status: 200, body: 'post-1');

      final id = await repository.createPost(
        userId,
        PostDraft(photo: jpegBytes, format: PhotoFormat.jpeg),
        devicePosition: device,
      );

      expect(id, 'post-1');
      final [upload, create] = requests;
      expect(upload.method, 'POST');
      expect(
        upload.uri.path,
        matches(RegExp('^$photosPath/$userId/[^/]+\\.jpg\$')),
      );
      expect(create.uri.path, '/rest/v1/rpc/create_post');
      // No place, list or caption: the server's defaults apply.
      expect(create.body, {
        'image_path': uploadedPath(upload),
        'device_latitude': 46.5191,
        'device_longitude': 6.5668,
        'location_precision': 'fuzzy',
        'lifetime_minutes': 1440,
        'audience': 'everyone',
      });
    });

    test('sends every choice of the author', () async {
      answer = (request) => request.uri.path.startsWith('/storage')
          ? (status: 200, body: {'Key': 'post-photos/x.png'})
          : (status: 200, body: 'post-1');

      await repository.createPost(
        userId,
        PostDraft(
          photo: pngBytes,
          format: PhotoFormat.png,
          caption: '  Sunset ',
          place: (latitude: 46.52, longitude: 6.57),
          precision: PostPrecision.exact,
          lifetime: const Duration(days: 3),
          audience: PostAudience.selected,
          audienceIds: ['f1', 'f2', 'f1'],
        ),
        devicePosition: device,
      );

      expect(requests.last.body, {
        'image_path': uploadedPath(requests.first),
        'device_latitude': 46.5191,
        'device_longitude': 6.5668,
        'place_latitude': 46.52,
        'place_longitude': 6.57,
        'location_precision': 'exact',
        'lifetime_minutes': 4320,
        'audience': 'selected',
        'audience_ids': ['f1', 'f2'],
        'caption': 'Sunset',
      });
    });

    test('removes the photo when the server refuses the post', () async {
      answer = (request) => switch (request) {
        (method: 'POST', uri: Uri(path: '/rest/v1/rpc/create_post'), body: _) =>
          (
            status: 400,
            body: {'code': '54000', 'message': 'too many active posts'},
          ),
        (method: 'DELETE', uri: _, body: _) => (status: 200, body: <Object>[]),
        _ => (status: 200, body: {'Key': 'post-photos/x.jpg'}),
      };

      await expectLater(
        repository.createPost(
          userId,
          PostDraft(photo: jpegBytes, format: PhotoFormat.jpeg),
          devicePosition: device,
        ),
        throwsA(isA<LimitReachedFailure>()),
      );

      final [upload, _, remove] = requests;
      expect(remove.method, 'DELETE');
      expect(remove.uri.path, photosPath);
      expect((remove.body! as Map)['prefixes'], [uploadedPath(upload)]);
    });

    test('refuses an invalid draft without calling the server', () async {
      await expectLater(
        repository.createPost(
          userId,
          PostDraft(
            photo: jpegBytes,
            format: PhotoFormat.jpeg,
            lifetime: const Duration(minutes: 10),
          ),
          devicePosition: device,
        ),
        throwsA(isA<InvalidInputFailure>()),
      );

      expect(requests, isEmpty);
    });
  });

  group('updatePost', () {
    test('sends only what changes, the lifetime in minutes', () async {
      answer = (_) => (status: 204, body: null);

      await repository.updatePost('post-1', lifetime: const Duration(days: 2));

      expect(requests.single.uri.path, '/rest/v1/rpc/update_post');
      expect(requests.single.body, {
        'post_id': 'post-1',
        'lifetime_minutes': 2880,
      });
    });

    test('sends a new audience with its list, once per friend', () async {
      answer = (_) => (status: 204, body: null);

      await repository.updatePost(
        'post-1',
        audience: PostAudience.selected,
        audienceIds: ['f1', 'f1'],
      );

      expect(requests.single.body, {
        'post_id': 'post-1',
        'audience': 'selected',
        'audience_ids': ['f1'],
      });
    });

    test('a post that is gone is not found', () async {
      answer = (_) =>
          (status: 400, body: {'code': 'P0002', 'message': 'post not found'});

      await expectLater(
        repository.updatePost('post-1', audience: PostAudience.everyone),
        throwsA(isA<NotFoundFailure>()),
      );
    });

    test('refuses an invalid lifetime without calling the server', () async {
      await expectLater(
        repository.updatePost('post-1', lifetime: const Duration(days: 31)),
        throwsA(isA<InvalidInputFailure>()),
      );

      expect(requests, isEmpty);
    });
  });

  test('deletePost deletes the row, then its photo', () async {
    await repository.deletePost(post());

    final [delete, remove] = requests;
    expect(delete.method, 'DELETE');
    expect(delete.uri.path, '/rest/v1/posts');
    expect(delete.uri.queryParameters['id'], 'eq.post-1');
    expect(remove.uri.path, photosPath);
    expect((remove.body! as Map)['prefixes'], ['$userId/a.jpg']);
  });

  test('fetchOwnPosts reads the public view, most recent first', () async {
    answer = (_) => (
      status: 200,
      body: [
        {
          'id': 'post-2',
          'author_id': userId,
          'image_path': '$userId/b.jpg',
          'caption': null,
          'latitude': 46.52,
          'longitude': 6.57,
          'location_precision': 'exact',
          'audience': 'friends',
          'created_at': '2026-11-25T12:00:00+00:00',
          'expires_at': '2026-11-26T12:00:00+00:00',
        },
        {
          'id': 'post-1',
          'author_id': userId,
          'image_path': '$userId/a.jpg',
          'caption': null,
          'latitude': 46.52,
          'longitude': 6.57,
          'location_precision': 'street',
          'audience': 'everyone',
          'created_at': '2026-11-25T10:00:00+00:00',
          'expires_at': '2026-11-26T10:00:00+00:00',
        },
      ],
    );

    final posts = await repository.fetchOwnPosts(userId);

    final query = requests.single.uri.queryParameters;
    expect(requests.single.uri.path, '/rest/v1/posts_public');
    expect(query['author_id'], 'eq.$userId');
    expect(query['order'], 'created_at.desc.nullslast');
    // Never `*` on posts: its exact position cannot be read.
    expect(query['select'], isNot(contains('*')));
    expect(posts.map((post) => post.id), ['post-2']);
    expect(posts.single.audience, PostAudience.friends);
  });

  group('fetchMapFeed', () {
    const epfl = (
      southWest: (latitude: 46.51, longitude: 6.555),
      northEast: (latitude: 46.53, longitude: 6.58),
    );

    test('calls map_feed with the corners and reads its posts', () async {
      answer = (_) => (
        status: 200,
        body: [
          {
            'id': 'post-1',
            'author_id': 'user-2',
            'author_name': 'Alice',
            'author_avatar_path': 'user-2/avatar.jpg',
            'image_path': 'user-2/a.jpg',
            'caption': null,
            'latitude': 46.5191,
            'longitude': 6.5668,
            'location_precision': 'fuzzy',
            'created_at': '2026-11-25T10:00:00+00:00',
            'expires_at': '2026-11-26T10:00:00+00:00',
            'is_pinned': true,
          },
        ],
      );

      final posts = await repository.fetchMapFeed(epfl);

      expect(requests.single.uri.path, '/rest/v1/rpc/map_feed');
      expect(requests.single.body, {
        'min_latitude': 46.51,
        'min_longitude': 6.555,
        'max_latitude': 46.53,
        'max_longitude': 6.58,
      });
      expect(posts.single.authorName, 'Alice');
      expect(posts.single.authorAvatarPath, 'user-2/avatar.jpg');
      expect(posts.single.isPinned, isTrue);
    });

    test('refuses an area too large without calling the server', () async {
      await expectLater(
        repository.fetchMapFeed((
          southWest: (latitude: 46.0, longitude: 6.0),
          northEast: (latitude: 47.0, longitude: 7.0),
        )),
        throwsA(isA<InvalidInputFailure>()),
      );

      expect(requests, isEmpty);
    });
  });

  group('pins', () {
    test('pin inserts the post id only', () async {
      answer = (_) => (status: 201, body: null);

      await repository.pin('post-1');

      expect(requests.single.method, 'POST');
      expect(requests.single.uri.path, '/rest/v1/pins');
      expect(requests.single.body, {'post_id': 'post-1'});
    });

    test('pinning a pinned post does nothing', () async {
      answer = (_) =>
          (status: 409, body: {'code': '23505', 'message': 'duplicate key'});

      await repository.pin('post-1');
    });

    test('pinning a post the user cannot see is refused', () async {
      answer = (_) => (
        status: 403,
        body: {'code': '42501', 'message': 'row-level security'},
      );

      await expectLater(
        repository.pin('post-1'),
        throwsA(isA<PermissionDeniedFailure>()),
      );
    });

    test('unpin deletes the pin of the post', () async {
      answer = (_) => (status: 204, body: null);

      await repository.unpin('post-1');

      expect(requests.single.method, 'DELETE');
      expect(requests.single.uri.path, '/rest/v1/pins');
      expect(requests.single.uri.queryParameters['post_id'], 'eq.post-1');
    });
  });
}
