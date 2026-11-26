import 'dart:convert';
import 'dart:io';

import 'package:evasion/core/config/business_rules.dart';
import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/features/encounters/data/supabase_encounters_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A request received by the stand-in server.
typedef Received = ({String method, Uri uri, Object? body});

/// An answer of the stand-in server: an HTTP status and a JSON body.
typedef Answer = ({int status, Object? body});

const epfl = (latitude: 46.5191, longitude: 6.5668);

/// Checks the requests sent to Supabase, through a small local HTTP server that
/// stands in for it and answers with [answer].
void main() {
  late HttpServer server;
  late SupabaseEncountersRepository repository;
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
    repository = SupabaseEncountersRepository(
      SupabaseClient('http://127.0.0.1:${server.port}', 'test-key'),
    );
  });

  tearDown(() => server.close(force: true));

  group('reportLocation', () {
    test('sends the position and its accuracy, and says if kept', () async {
      answer = (_) => (status: 200, body: true);

      final kept = await repository.reportLocation((
        position: epfl,
        accuracyMeters: 12.5,
      ));

      expect(kept, isTrue);
      expect(requests.single.method, 'POST');
      expect(requests.single.uri.path, '/rest/v1/rpc/report_location');
      expect(requests.single.body, {
        'latitude': 46.5191,
        'longitude': 6.5668,
        'accuracy_meters': 12.5,
      });
    });

    test('a position the server ignores is not kept', () async {
      answer = (_) => (status: 200, body: false);

      final kept = await repository.reportLocation((
        position: epfl,
        accuracyMeters: 10,
      ));

      expect(kept, isFalse);
    });

    test('does not send a position too imprecise', () async {
      final kept = await repository.reportLocation((
        position: epfl,
        accuracyMeters: BusinessRules.locationMaxAccuracyMeters + 1,
      ));

      expect(kept, isFalse);
      expect(requests, isEmpty);
    });

    test('a user who does not share their location is refused', () async {
      answer = (_) => (
        status: 403,
        body: {
          'code': '42501',
          'message': 'the user does not share their location',
        },
      );

      await expectLater(
        repository.reportLocation((position: epfl, accuracyMeters: 10)),
        throwsA(isA<PermissionDeniedFailure>()),
      );
    });
  });

  test('fetchCrossings reads my_crossings in the server order', () async {
    answer = (_) => (
      status: 200,
      body: [
        {
          'id': 'crossing-2',
          'user_id': 'user-3',
          'display_name': 'Léa',
          'age': 21,
          'avatar_path': 'user-3/a.jpg',
          'is_student_verified': false,
          'crossed_at': '2026-11-26T14:30:00+00:00',
          'latitude': 46.5194,
          'longitude': 6.5672,
        },
        {
          'id': 'crossing-1',
          'user_id': 'user-2',
          'display_name': null,
          'age': null,
          'avatar_path': null,
          'is_student_verified': null,
          'crossed_at': '2026-11-26T12:00:00+00:00',
          'latitude': 46.5194,
          'longitude': 6.5672,
        },
      ],
    );

    final crossings = await repository.fetchCrossings();

    expect(requests.single.uri.path, '/rest/v1/rpc/my_crossings');
    expect(crossings.map((crossing) => crossing.displayName), ['Léa']);
  });
}
