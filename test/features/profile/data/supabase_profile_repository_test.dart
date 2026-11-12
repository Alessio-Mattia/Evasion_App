import 'dart:convert';
import 'dart:io';

import 'package:evasion/features/profile/data/supabase_profile_repository.dart';
import 'package:evasion/features/profile/domain/profile_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Checks the requests sent to Supabase, through a small local HTTP server that
/// stands in for it and answers with [response].
void main() {
  late HttpServer server;
  late SupabaseProfileRepository repository;
  late List<Uri> requests;
  late Object response;

  setUp(() async {
    requests = [];
    response = <Object>[];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests.add(request.uri);
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(response));
      await request.response.close();
    });
    repository = SupabaseProfileRepository(
      SupabaseClient('http://127.0.0.1:${server.port}', 'test-key'),
    );
  });

  tearDown(() => server.close(force: true));

  group('fetchOwnPages', () {
    test('asks for the pages of the user in ascending position', () async {
      await repository.fetchOwnPages('user-1');

      final query = requests.single.queryParameters;
      expect(requests.single.path, '/rest/v1/profile_pages');
      expect(query['profile_id'], 'eq.user-1');
      // The Supabase client sorts in descending order unless told otherwise.
      expect(query['order'], 'position.asc.nullslast');
    });

    test('keeps the order of the server and skips unknown pages', () async {
      response = [
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
          'image_path': 'user-1/a.jpg',
        },
      ];

      final pages = await repository.fetchOwnPages('user-1');

      expect(pages.map((page) => page.id), ['p1', 'p3']);
      expect(pages.last, isA<PhotoPage>());
    });
  });
}
