import 'dart:convert';
import 'dart:io';

import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/core/photos/photo_file.dart';
import 'package:evasion/features/profile/data/supabase_profile_repository.dart';
import 'package:evasion/features/profile/domain/page_draft.dart';
import 'package:evasion/features/profile/domain/profile_details.dart';
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

  group('updatePage', () {
    const lakePage = ProfilePage.photo(
      id: 'p1',
      position: 1,
      imagePath: '$userId/old.jpg',
    );

    test('changes the content of the page only', () async {
      answer = (_) => (status: 200, body: {'id': 'p1'});

      await repository.updatePage(
        userId,
        const ProfilePage.text(id: 'p1', position: 1, text: 'Avant'),
        const TextPageDraft(' Après '),
      );

      final update = requests.single;
      expect(update.method, 'PATCH');
      expect(update.uri.path, '/rest/v1/profile_pages');
      expect(update.uri.queryParameters['id'], 'eq.p1');
      expect(update.body, {
        'content': {'text': 'Après'},
      });
    });

    test('keeping the photo changes only the caption', () async {
      answer = (_) => (status: 200, body: {'id': 'p1'});

      await repository.updatePage(
        userId,
        lakePage,
        const KeptPhotoPageDraft(imagePath: '$userId/old.jpg', caption: 'Lac'),
      );

      expect(requests.single.body, {
        'content': {'caption': 'Lac'},
      });
    });

    test('a new photo is uploaded, used, then the old one deleted', () async {
      answer = (request) => switch (request) {
        (method: 'PATCH', uri: _, body: _) => (status: 200, body: {'id': 'p1'}),
        (method: 'DELETE', uri: _, body: _) => (status: 200, body: <Object>[]),
        _ => (status: 200, body: {'Key': 'profile-photos/x.png'}),
      };

      await repository.updatePage(
        userId,
        lakePage,
        PhotoPageDraft(bytes: pngBytes, format: PhotoFormat.png),
      );

      final [upload, update, remove] = requests;
      final newPath = upload.uri.path.replaceFirst(
        '/storage/v1/object/profile-photos/',
        '',
      );
      expect(update.body, {
        'content': <String, Object>{},
        'image_path': newPath,
      });
      expect((remove.body! as Map)['prefixes'], ['$userId/old.jpg']);
    });

    test('a page deleted meanwhile keeps nothing of the new photo', () async {
      answer = (request) => switch (request) {
        (method: 'PATCH', uri: _, body: _) => (
          status: 406,
          body: {'code': 'PGRST116', 'message': 'no rows'},
        ),
        (method: 'DELETE', uri: _, body: _) => (status: 200, body: <Object>[]),
        _ => (status: 200, body: {'Key': 'profile-photos/x.png'}),
      };

      await expectLater(
        repository.updatePage(
          userId,
          lakePage,
          PhotoPageDraft(bytes: pngBytes, format: PhotoFormat.png),
        ),
        throwsA(isA<NotFoundFailure>()),
      );

      final [upload, _, remove] = requests;
      // The new photo goes, the old one stays with its page.
      expect((remove.body! as Map)['prefixes'], [
        upload.uri.path.replaceFirst('/storage/v1/object/profile-photos/', ''),
      ]);
    });

    test('refuses to change the template without calling the server', () async {
      await expectLater(
        repository.updatePage(userId, lakePage, const TextPageDraft('Hey')),
        throwsA(isA<InvalidInputFailure>()),
      );

      expect(requests, isEmpty);
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

  test('fetchOwnProfile reads whether the birth date was corrected', () async {
    answer = (_) => (
      status: 200,
      body: {
        'id': userId,
        'is_student_verified': false,
        'is_complete': true,
        'birth_date_corrected': true,
      },
    );

    final profile = await repository.fetchOwnProfile(userId);

    expect(
      requests.single.uri.queryParameters['select'],
      contains('birth_date_corrected'),
    );
    expect(profile.birthDateCorrected, isTrue);
  });

  group('updateDetails', () {
    test('saves the four texts, null for the emptied ones', () async {
      answer = (_) => (status: 200, body: {'id': userId});

      await repository.updateDetails(
        userId,
        ProfileDetails(
          displayName: ' Alex ',
          occupation: 'Biologie',
          university: '  ',
          bio: '',
        ),
      );

      final update = requests.single;
      expect(update.method, 'PATCH');
      expect(update.uri.path, '/rest/v1/profiles');
      expect(update.uri.queryParameters['id'], 'eq.$userId');
      expect(update.body, {
        'display_name': 'Alex',
        'occupation': 'Biologie',
        'university': null,
        'bio': null,
      });
    });

    test(
      'a text over the limit refused by the server is an invalid input',
      () async {
        answer = (_) => (
          status: 400,
          body: {'code': '23514', 'message': 'profiles_bio_length'},
        );

        await expectLater(
          repository.updateDetails(
            userId,
            ProfileDetails(
              displayName: 'Alex',
              occupation: '',
              university: '',
              bio: 'a' * 501,
            ),
          ),
          throwsA(isA<InvalidInputFailure>()),
        );
      },
    );
  });

  group('correctBirthDate', () {
    test('sends the date alone, as a Postgres date', () async {
      answer = (_) => (status: 200, body: {'id': userId});

      await repository.correctBirthDate(userId, DateTime(2001, 2, 3));

      expect(requests.single.method, 'PATCH');
      expect(requests.single.body, {'birth_date': '2001-02-03'});
    });

    test(
      'a second correction refused by the trigger is an invalid input',
      () async {
        answer = (_) => (
          status: 400,
          body: {
            'code': '23514',
            'message': 'birth_date can only be corrected once',
          },
        );

        await expectLater(
          repository.correctBirthDate(userId, DateTime(2001, 2, 3)),
          throwsA(isA<InvalidInputFailure>()),
        );
      },
    );
  });

  group('replaceAvatar', () {
    const oldPath = '$userId/old.jpg';

    Answer avatarServer(Received request, {int updateStatus = 200}) =>
        switch (request) {
          (method: 'GET', uri: _, body: _) => (
            status: 200,
            body: {'avatar_path': oldPath},
          ),
          (method: 'PATCH', uri: _, body: _) => (
            status: updateStatus,
            body: updateStatus == 200
                ? {'id': userId}
                : {'code': '23514', 'message': 'avatar_path'},
          ),
          (method: 'DELETE', uri: _, body: _) => (
            status: 200,
            body: <Object>[],
          ),
          _ => (status: 200, body: {'Key': 'avatars/x.png'}),
        };

    String uploadedPath(Received upload) =>
        upload.uri.path.replaceFirst('/storage/v1/object/avatars/', '');

    test('uploads a new file, uses it, then deletes the old one', () async {
      answer = avatarServer;

      await repository.replaceAvatar(userId, pngBytes, PhotoFormat.png);

      final [read, upload, update, remove] = requests;
      expect(read.uri.queryParameters['select'], 'avatar_path');
      expect(upload.method, 'POST');
      expect(
        upload.uri.path,
        matches(RegExp('^/storage/v1/object/avatars/$userId/[^/]+\\.png\$')),
      );
      expect(update.body, {'avatar_path': uploadedPath(upload)});
      expect(remove.uri.path, '/storage/v1/object/avatars');
      expect((remove.body! as Map)['prefixes'], [oldPath]);
    });

    test(
      'a refused update deletes the new file and keeps the old one',
      () async {
        answer = (request) => avatarServer(request, updateStatus: 400);

        await expectLater(
          repository.replaceAvatar(userId, pngBytes, PhotoFormat.png),
          throwsA(isA<InvalidInputFailure>()),
        );

        final [_, upload, _, remove] = requests;
        expect((remove.body! as Map)['prefixes'], [uploadedPath(upload)]);
      },
    );
  });
}
