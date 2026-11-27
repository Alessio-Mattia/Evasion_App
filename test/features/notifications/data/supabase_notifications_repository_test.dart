import 'dart:convert';
import 'dart:io';

import 'package:evasion/features/notifications/data/supabase_notifications_repository.dart';
import 'package:evasion/features/notifications/domain/app_notification.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A request received by the stand-in server.
typedef Received = ({String method, Uri uri, Object? body});

/// Checks the requests sent to Supabase, through a small local HTTP server that
/// stands in for it.
void main() {
  late HttpServer server;
  late SupabaseNotificationsRepository repository;
  late List<Received> requests;
  late Object? answer;

  setUp(() async {
    requests = [];
    answer = <Object>[];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final bytes = [for (final chunk in await request.toList()) ...chunk];
      requests.add((
        method: request.method,
        uri: request.uri,
        body: bytes.isEmpty ? null : jsonDecode(utf8.decode(bytes)),
      ));
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(answer));
      await request.response.close();
    });
    repository = SupabaseNotificationsRepository(
      SupabaseClient('http://127.0.0.1:${server.port}', 'test-key'),
    );
  });

  tearDown(() => server.close(force: true));

  test(
    'fetchNotifications reads my_notifications, skipping unknown kinds',
    () async {
      answer = [
        {
          'id': 'n2',
          'kind': 'match_cancelled',
          'user_id': 'user-2',
          'display_name': 'Noah',
          'avatar_path': null,
          'created_at': '2026-11-27T15:00:00+00:00',
          'read_at': null,
        },
        {
          'id': 'n1',
          'kind': 'something_new',
          'user_id': 'user-2',
          'display_name': 'Noah',
          'avatar_path': null,
          'created_at': '2026-11-27T14:00:00+00:00',
          'read_at': null,
        },
      ];

      final notifications = await repository.fetchNotifications();

      expect(requests.single.uri.path, '/rest/v1/rpc/my_notifications');
      expect(notifications.single.kind, NotificationKind.matchCancelled);
    },
  );

  test('markRead sends the ids, or nothing to mark them all', () async {
    answer = null;

    await repository.markRead(ids: ['n1', 'n2']);
    await repository.markRead();

    expect(requests.map((request) => request.uri.path).toSet(), {
      '/rest/v1/rpc/mark_notifications_read',
    });
    expect(requests.map((request) => request.body), [
      {
        'ids': ['n1', 'n2'],
      },
      <String, Object?>{},
    ]);
  });
}
