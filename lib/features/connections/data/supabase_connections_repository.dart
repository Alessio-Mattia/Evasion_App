import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/core/errors/failure_mapper.dart';
import 'package:evasion/core/supabase/supabase_client_provider.dart';
import 'package:evasion/features/connections/domain/connection_qr.dart';
import 'package:evasion/features/connections/domain/connections_repository.dart';
import 'package:evasion/features/connections/domain/friend.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'supabase_connections_repository.g.dart';

@Riverpod(keepAlive: true)
ConnectionsRepository connectionsRepository(Ref ref) =>
    SupabaseConnectionsRepository(ref.watch(supabaseClientProvider));

class SupabaseConnectionsRepository implements ConnectionsRepository {
  SupabaseConnectionsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<ConnectionToken> createToken() => guard(() async {
    final rows = await _client.rpc<List<dynamic>>('create_connection_token');
    final row = rows.single as Map<String, dynamic>;
    return (
      token: row['token'] as String,
      expiresAt: DateTime.parse(row['expires_at'] as String),
    );
  });

  @override
  Future<ConnectionResult> scan(String qrPayload) => guard(() async {
    final token = tokenFromQrPayload(qrPayload);
    if (token == null) throw const InvalidInputFailure();
    final rows = await _client.rpc<List<dynamic>>(
      'scan_connection_token',
      params: {'token': token},
    );
    final row = rows.single as Map<String, dynamic>;
    return (
      friendId: row['friend_id'] as String,
      alreadyFriends: row['already_friends'] as bool,
    );
  });

  @override
  Future<Friend?> whoScanned(String token) => guard(() async {
    final rows = await _client.rpc<List<dynamic>>(
      'connection_token_scan',
      params: {'token': token},
    );
    return rows.isEmpty
        ? null
        : friendFromRow(rows.first as Map<String, dynamic>);
  });

  @override
  Future<List<Friend>> fetchFriends() => guard(() async {
    final rows = await _client.rpc<List<dynamic>>('my_friends');
    // Already sorted by the server, most recent first.
    return [
      for (final row in rows.cast<Map<String, dynamic>>()) ?friendFromRow(row),
    ];
  });

  @override
  Future<void> removeFriend(String friendId) => guard(
    () => _client.rpc<void>('remove_friend', params: {'friend_id': friendId}),
  );
}
