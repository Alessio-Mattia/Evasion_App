import 'dart:convert';
import 'dart:io';

import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/core/photos/photo_file.dart';
import 'package:evasion/features/profile/data/supabase_profile_repository.dart';
import 'package:evasion/features/profile/domain/page_draft.dart';
import 'package:evasion/features/profile/domain/profile_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../helpers/fake_photo_picker.dart';

/// A request received by the stand-in server.
typedef Received = ({String method, Uri uri, Object? body});

/// An answer of the stand-in server: an HTTP status and a JSON body.
typedef Answer = ({int status, Object? body});

const userId = 'user-1';

/// Checks the requests sent to Supabase, through a small local HTTP server that
/// stands in for it and answers with [answer].
void main() {
  late HttpServer server;
  late SupabaseProfileRepository repository;
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
    repository = SupabaseProfileRepository(
      SupabaseClient('http://127.0.0.1:${server.port}', 'test-key'),
    );
  });

  tearDown(() => server.close(force: true));

  group('fetchOwnPages', () {
    test('asks for the pages of the user in ascending position', () async {
      await repository.fetchOwnPages(userId);

      final query = requests.single.uri.queryParameters;
      expect(requests.single.uri.path, '/rest/v1/profile_pages');
      expect(query['profile_id'], 'eq.$userId');
      // The Supabase client sorts in descending order unless told otherwise.
      expect(query['order'], 'position.asc.nullslast');
    });

    test('keeps the order of the server and skips unknown pages', () async {
      answer = (_) => (
        status: 200,
        body: [
          {
            'id': 'p1',
            'position': 1,
            'type': 'text',
            'content': {'text': 'Salut'},
            'image_path': null,
          },
          {
            'id': 'p2',
            'position': 2,
            'type': 'video',
            'content': <String, Object>{},
            'image_path': null,
          },
          {
            'id': 'p3',
            'position': 3,
            'type': 'photo',
            'content': <String, Object>{},
            'image_path': '$userId/a.jpg',
          },
        ],
      );

      final pages = await repository.fetchOwnPages(userId);

      expect(pages.map((page) => page.id), ['p1', 'p3']);
      expect(pages.last, isA<PhotoPage>());
    });
  });

  test('fetchOwnPageSlots keeps the pages of unknown types', () async {
    answer = (_) => (
      status: 200,
      body: [
        {'id': 'p1', 'position': 1},
        {'id': 'p2', 'position': 2},
      ],
    );

    final slots = await repository.fetchOwnPageSlots(userId);

    expect(requests.single.uri.queryParameters['select'], 'id,position');
    expect(slots, [(id: 'p1', position: 1), (id: 'p2', position: 2)]);
  });

  group('addPage', () {
    test('inserts a text page with its position and content only', () async {
      answer = (_) => (status: 201, body: null);

      await repository.addPage(
        userId,
        const TextPageDraft(' Salut '),
        position: 2,
      );

      expect(requests.single.method, 'POST');
      expect(requests.single.uri.path, '/rest/v1/profile_pages');
      expect(requests.single.body, {
        'position': 2,
        'type': 'text',
        'content': {'text': 'Salut'},
      });
    });

    test('uploads the photo to a new file, then inserts the page', () async {
      answer = (request) => request.uri.path.startsWith('/storage')
          ? (status: 200, body: {'Key': 'profile-photos/x.png'})
          : (status: 201, body: null);

      await repository.addPage(
        userId,
        PhotoPageDraft(bytes: pngBytes, format: PhotoFormat.png),
        position: 1,
      );

      final [upload, insert] = requests;
      expect(upload.method, 'POST');
      expect(
        upload.uri.path,
        matches(
          RegExp('^/storage/v1/object/profile-photos/$userId/[^/]+\\.png\$'),
        ),
      );
      final imagePath = upload.uri.path.replaceFirst(
        '/storage/v1/object/profile-photos/',
        '',
      );
      // No caption key at all: the server refuses a null one.
      expect(insert.body, {
        'position': 1,
        'type': 'photo',
        'content': <String, Object>{},
        'image_path': imagePath,
      });
    });

    test('removes the uploaded photo when the page is refused', () async {
      answer = (request) => switch (request) {
        (method: 'POST', uri: Uri(path: '/rest/v1/profile_pages'), body: _) => (
          status: 409,
          body: {'code': '23505', 'message': 'duplicate key'},
        ),
        (method: 'DELETE', uri: _, body: _) => (status: 200, body: <Object>[]),
        _ => (status: 200, body: {'Key': 'profile-photos/x.png'}),
      };

      await expectLater(
        repository.addPage(
          userId,
          PhotoPageDraft(bytes: pngBytes, format: PhotoFormat.png),
          position: 1,
        ),
        throwsA(isA<ConflictFailure>()),
      );

      final [upload, _, remove] = requests;
      expect(remove.method, 'DELETE');
      expect(remove.uri.path, '/storage/v1/object/profile-photos');
      expect((remove.body! as Map)['prefixes'], [
        upload.uri.path.replaceFirst('/storage/v1/object/profile-photos/', ''),
      ]);
    });
  });

  test('deletePage deletes the row, then the photo it used', () async {
    await repository.deletePage(
      const ProfilePage.photo(
        id: 'p1',
        position: 1,
        imagePath: '$userId/a.jpg',
      ),
    );

    final [row, photo] = requests;
    expect(row.method, 'DELETE');
    expect(row.uri.path, '/rest/v1/profile_pages');
    expect(row.uri.queryParameters['id'], 'eq.p1');
    expect(photo.uri.path, '/storage/v1/object/profile-photos');
    expect((photo.body! as Map)['prefixes'], ['$userId/a.jpg']);
  });

  test('reorderPages calls the reordering function with the ids', () async {
    answer = (_) => (status: 204, body: null);

    await repository.reorderPages(['p2', 'p1']);

    expect(requests.single.uri.path, '/rest/v1/rpc/reorder_profile_pages');
    expect(requests.single.body, {
      'page_ids': ['p2', 'p1'],
    });
  });
}
