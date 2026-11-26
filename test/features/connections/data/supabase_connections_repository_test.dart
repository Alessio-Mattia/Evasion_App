import 'dart:convert';
import 'dart:io';

import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/features/connections/data/supabase_connections_repository.dart';
import 'package:evasion/features/connections/domain/connection_qr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A request received by the stand-in server.
typedef Received = ({String method, Uri uri, Object? body});

/// An answer of the stand-in server: an HTTP status and a JSON body.
typedef Answer = ({int status, Object? body});

const token = '0123456789abcdef0123456789abcdef';

/// Checks the requests sent to Supabase, through a small local HTTP server that
/// stands in for it and answers with [answer].
void main() {
  late HttpServer server;
  late SupabaseConnectionsRepository repository;
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
    repository = SupabaseConnectionsRepository(
      SupabaseClient('http://127.0.0.1:${server.port}', 'test-key'),
    );
  });

  tearDown(() => server.close(force: true));

  test('createToken reads the token and its expiry', () async {
    answer = (_) => (
      status: 200,
      body: [
        {'token': token, 'expires_at': '2026-11-26T14:02:00+00:00'},
      ],
    );

    final created = await repository.createToken();

    expect(requests.single.uri.path, '/rest/v1/rpc/create_connection_token');
    expect(created.token, token);
    expect(created.expiresAt, DateTime.utc(2026, 11, 26, 14, 2));
  });

  group('scan', () {
    test('sends the token of the QR code and reads the result', () async {
      answer = (_) => (
        status: 200,
        body: [
          {'friend_id': 'user-2', 'already_friends': false},
        ],
      );

      final result = await repository.scan(qrPayloadFor(token));

      expect(requests.single.uri.path, '/rest/v1/rpc/scan_connection_token');
      expect(requests.single.body, {'token': token});
      expect(result, (friendId: 'user-2', alreadyFriends: false));
    });

    test('refuses another QR code without calling the server', () async {
      await expectLater(
        repository.scan('https://example.com/menu'),
        throwsA(isA<InvalidInputFailure>()),
      );

      expect(requests, isEmpty);
    });

    test('a QR code no longer valid is not found', () async {
      answer = (_) => (
        status: 400,
        body: {'code': 'P0002', 'message': 'this QR code is not valid'},
      );

      await expectLater(
        repository.scan(qrPayloadFor(token)),
        throwsA(isA<NotFoundFailure>()),
      );
    });

    test('two people too far apart are refused', () async {
      answer = (_) => (
        status: 400,
        body: {'code': '23514', 'message': 'the two users are too far apart'},
      );

      await expectLater(
        repository.scan(qrPayloadFor(token)),
        throwsA(isA<InvalidInputFailure>()),
      );
    });
  });

  group('whoScanned', () {
    test('asks about the token and reads who scanned it', () async {
      answer = (_) => (
        status: 200,
        body: [
          {
            'friend_id': 'user-2',
            'display_name': 'Noah',
            'age': 23,
            'avatar_path': 'user-2/a.jpg',
            'is_student_verified': true,
          },
        ],
      );

      final scanner = await repository.whoScanned(token);

      expect(requests.single.uri.path, '/rest/v1/rpc/connection_token_scan');
      expect(requests.single.body, {'token': token});
      expect(scanner?.displayName, 'Noah');
    });

    test('is null while nobody has scanned', () async {
      expect(await repository.whoScanned(token), isNull);
    });
  });

  test('fetchFriends reads my_friends in the server order', () async {
    answer = (_) => (
      status: 200,
      body: [
        {
          'user_id': 'user-3',
          'display_name': 'Léa',
          'age': 21,
          'avatar_path': null,
          'is_student_verified': false,
          'friends_since': '2026-11-26T15:00:00+00:00',
        },
        {
          'user_id': 'user-2',
          'display_name': 'Noah',
          'age': 23,
          'avatar_path': 'user-2/a.jpg',
          'is_student_verified': true,
          'friends_since': '2026-11-25T15:00:00+00:00',
        },
      ],
    );

    final friends = await repository.fetchFriends();

    expect(requests.single.uri.path, '/rest/v1/rpc/my_friends');
    expect(friends.map((friend) => friend.displayName), ['Léa', 'Noah']);
  });

  test('removeFriend sends the id of the friend', () async {
    answer = (_) => (status: 204, body: null);

    await repository.removeFriend('user-2');

    expect(requests.single.uri.path, '/rest/v1/rpc/remove_friend');
    expect(requests.single.body, {'friend_id': 'user-2'});
  });
}
