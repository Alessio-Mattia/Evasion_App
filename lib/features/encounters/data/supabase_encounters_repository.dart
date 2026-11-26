import 'package:evasion/core/config/business_rules.dart';
import 'package:evasion/core/errors/failure_mapper.dart';
import 'package:evasion/core/services/location_service.dart';
import 'package:evasion/core/supabase/supabase_client_provider.dart';
import 'package:evasion/features/encounters/domain/crossing.dart';
import 'package:evasion/features/encounters/domain/encounters_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'supabase_encounters_repository.g.dart';

@Riverpod(keepAlive: true)
EncountersRepository encountersRepository(Ref ref) =>
    SupabaseEncountersRepository(ref.watch(supabaseClientProvider));

class SupabaseEncountersRepository implements EncountersRepository {
  SupabaseEncountersRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<bool> reportLocation(LocationFix fix) => guard(() async {
    // The server would ignore it: no need to send it.
    if (fix.accuracyMeters > BusinessRules.locationMaxAccuracyMeters) {
      return false;
    }
    return _client.rpc<bool>(
      'report_location',
      params: {
        'latitude': fix.position.latitude,
        'longitude': fix.position.longitude,
        'accuracy_meters': fix.accuracyMeters,
      },
    );
  });

  @override
  Future<List<Crossing>> fetchCrossings() => guard(() async {
    final rows = await _client.rpc<List<dynamic>>('my_crossings');
    // Already sorted by the server, most recent first.
    return [
      for (final row in rows.cast<Map<String, dynamic>>())
        ?crossingFromRow(row),
    ];
  });
}
