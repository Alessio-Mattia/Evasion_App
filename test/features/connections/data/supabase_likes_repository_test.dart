import 'dart:convert';
import 'dart:io';

import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/features/connections/data/supabase_likes_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A request received by the stand-in server.
typedef Received = ({String method, Uri uri, Object? body});

/// An answer of the stand-in server: an HTTP status and a JSON body.
typedef Answer = ({int status, Object? body});

/// Checks the requests sent to Supabase, through a small local HTTP server that
/// stands in for it and answers with [answer].
void main() {
  late HttpServer server;
  late SupabaseLikesRepository repository;
  late List<Received> requests;
  late Answer Function(Received request) answer;

  setUp(() async {
    requests = [];
    answer = (_) => (status: 200, body: <Object>[]);
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final bytes = [for (final chunk in await request.toList()) ...chunk];
      final received = (
        method: request.method,
        uri: request.uri,
        body: bytes.isEmpty ? null : jsonDecode(utf8.decode(bytes)),
      );
      requests.add(received);
      final (:status, :body) = answer(received);
      request.response
        ..statusCode = status
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(body));
      await request.response.close();
    });
    repository = SupabaseLikesRepository(
      SupabaseClient('http://127.0.0.1:${server.port}', 'test-key'),
    );
  });

  tearDown(() => server.close(force: true));

  group('likeFriend', () {
    test('sends the friend and the trimmed message, says if a match', () async {
      answer = (_) => (status: 200, body: true);

      final matched = await repository.likeFriend(
        'user-2',
        message: '  Un café ?  ',
      );

      expect(matched, isTrue);
      expect(requests.single.uri.path, '/rest/v1/rpc/like_friend');
      expect(requests.single.body, {
        'friend_id': 'user-2',
        'message': 'Un café ?',
      });
    });

    test('sends no message when there is none, or a blank one', () async {
      answer = (_) => (status: 200, body: false);

      await repository.likeFriend('user-2');
      await repository.likeFriend('user-2', message: '   ');

      expect(requests.map((request) => request.body), [
        {'friend_id': 'user-2'},
        {'friend_id': 'user-2'},
      ]);
    });

    test('refuses a message too long without calling the server', () async {
      await expectLater(
        repository.likeFriend('user-2', message: 'a' * 301),
        throwsA(isA<InvalidInputFailure>()),
      );

      expect(requests, isEmpty);
    });

    test('only a friend can be liked', () async {
      answer = (_) => (
        status: 403,
        body: {'code': '42501', 'message': 'only a friend can be liked'},
      );

      await expectLater(
        repository.likeFriend('user-3'),
        throwsA(isA<PermissionDeniedFailure>()),
      );
    });

    test('a like removed recently cannot be given again', () async {
      answer = (_) => (
        status: 400,
        body: {
          'code': '54000',
          'message': 'this like was removed less than 7 days ago',
        },
      );

      await expectLater(
        repository.likeFriend('user-2'),
        throwsA(isA<LimitReachedFailure>()),
      );
    });
  });

  test('removeLike sends the friend; refused after a match', () async {
    answer = (_) => (
      status: 400,
      body: {'code': '23514', 'message': 'a like cannot be removed'},
    );

    await expectLater(
      repository.removeLike('user-2'),
      throwsA(isA<InvalidInputFailure>()),
    );

    expect(requests.single.uri.path, '/rest/v1/rpc/remove_like');
    expect(requests.single.body, {'friend_id': 'user-2'});
  });

  test('cancelMatch sends the friend', () async {
    answer = (_) => (status: 204, body: null);

    await repository.cancelMatch('user-2');

    expect(requests.single.uri.path, '/rest/v1/rpc/cancel_match');
    expect(requests.single.body, {'friend_id': 'user-2'});
  });

  test('fetchPendingLikes reads my_likes', () async {
    answer = (_) => (
      status: 200,
      body: [
        {
          'user_id': 'user-2',
          'display_name': 'Noah',
          'age': 23,
          'avatar_path': null,
          'is_student_verified': false,
          'message': null,
          'liked_at': '2026-11-27T14:00:00+00:00',
        },
      ],
    );

    final likes = await repository.fetchPendingLikes();

    expect(requests.single.uri.path, '/rest/v1/rpc/my_likes');
    expect(likes.single.displayName, 'Noah');
  });

  test('fetchMatches reads my_matches', () async {
    answer = (_) => (
      status: 200,
      body: [
        {
          'user_id': 'user-2',
          'display_name': 'Noah',
          'age': 23,
          'avatar_path': null,
          'is_student_verified': false,
          'their_message': 'Avec plaisir',
          'my_message': 'Un café ?',
          'matched_at': '2026-11-27T15:00:00+00:00',
        },
      ],
    );

    final matches = await repository.fetchMatches();

    expect(requests.single.uri.path, '/rest/v1/rpc/my_matches');
    expect(matches.single.theirMessage, 'Avec plaisir');
  });
}
