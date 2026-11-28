import 'package:evasion/features/encounters/data/supabase_encounters_repository.dart';
import 'package:evasion/features/encounters/domain/crossing.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'crossings_provider.g.dart';

/// The crossings of the last week, the most recent first. Reloaded after
/// each position the server keeps, since it may have made a new crossing.
@riverpod
Future<List<Crossing>> crossings(Ref ref) =>
    ref.watch(encountersRepositoryProvider).fetchCrossings();
