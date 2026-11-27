import 'package:evasion/core/errors/failure_mapper.dart';
import 'package:evasion/core/supabase/supabase_client_provider.dart';
import 'package:evasion/features/notifications/domain/app_notification.dart';
import 'package:evasion/features/notifications/domain/notifications_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'supabase_notifications_repository.g.dart';

@Riverpod(keepAlive: true)
NotificationsRepository notificationsRepository(Ref ref) =>
    SupabaseNotificationsRepository(ref.watch(supabaseClientProvider));

class SupabaseNotificationsRepository implements NotificationsRepository {
  SupabaseNotificationsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<AppNotification>> fetchNotifications() => guard(() async {
    final rows = await _client.rpc<List<dynamic>>('my_notifications');
    // Already sorted by the server, most recent first.
    return [
      for (final row in rows.cast<Map<String, dynamic>>())
        ?notificationFromRow(row),
    ];
  });

  @override
  Future<void> markRead({List<String>? ids}) => guard(
    () => _client.rpc<void>('mark_notifications_read', params: {'ids': ?ids}),
  );
}
