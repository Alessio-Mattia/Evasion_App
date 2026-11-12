import 'package:evasion/core/errors/failure_mapper.dart';
import 'package:evasion/core/supabase/supabase_client_provider.dart';
import 'package:evasion/features/profile/domain/profile.dart';
import 'package:evasion/features/profile/domain/profile_page.dart';
import 'package:evasion/features/profile/domain/profile_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'supabase_profile_repository.g.dart';

@Riverpod(keepAlive: true)
ProfileRepository profileRepository(Ref ref) =>
    SupabaseProfileRepository(ref.watch(supabaseClientProvider));

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  static const _columns =
      'id, display_name, birth_date, gender, avatar_path, '
      'occupation, university, bio, is_student_verified, is_complete';

  @override
  Future<Profile> fetchOwnProfile(String userId) => guard(() async {
    final row = await _client
        .from('profiles')
        .select(_columns)
        .eq('id', userId)
        .single();
    return Profile.fromJson(row);
  });

  @override
  Future<List<ProfilePage>> fetchOwnPages(String userId) => guard(() async {
    final rows = await _client
        .from('profile_pages')
        .select('id, position, type, content, image_path')
        .eq('profile_id', userId)
        // Unlike SQL, the client sorts in descending order by default.
        .order('position', ascending: true);
    return [for (final row in rows) ?profilePageFromRow(row)];
  });
}
