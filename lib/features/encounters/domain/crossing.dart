import 'package:freezed_annotation/freezed_annotation.dart';

part 'crossing.freezed.dart';

/// Someone the signed-in user crossed: around when and where, never more.
///
/// The server rounds the time to `BusinessRules.crossingTimeRounding` and
/// places the crossing at the centre of a cell at least
/// `BusinessRules.crossingZoneCellSizeMeters` wide: show an area, never a
/// pin.
@freezed
abstract class Crossing with _$Crossing {
  const factory Crossing({
    required String id,

    /// The person crossed.
    required String userId,
    required String displayName,
    required int age,
    required bool isStudentVerified,

    /// Rounded by the server.
    required DateTime crossedAt,

    /// Centre of the zone of the crossing.
    required double latitude,
    required double longitude,

    /// Path in the `avatars` bucket.
    String? avatarPath,
  }) = _Crossing;
}

/// Reads a row of `my_crossings`, or returns null for a row this version of
/// the app cannot show, such as one without a name: an older app then shows
/// one crossing less instead of failing.
Crossing? crossingFromRow(Map<String, dynamic> row) {
  final displayName = row['display_name'];
  final age = row['age'];
  if (displayName is! String || age is! int) return null;
  return Crossing(
    id: row['id'] as String,
    userId: row['user_id'] as String,
    displayName: displayName,
    age: age,
    isStudentVerified: row['is_student_verified'] as bool? ?? false,
    crossedAt: DateTime.parse(row['crossed_at'] as String),
    latitude: (row['latitude'] as num).toDouble(),
    longitude: (row['longitude'] as num).toDouble(),
    avatarPath: row['avatar_path'] as String?,
  );
}
