import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_user.freezed.dart';

/// The signed-in user, as seen by the app.
///
/// Only identifies the account: the public profile lives in the profile
/// feature.
@freezed
abstract class AppUser with _$AppUser {
  const factory AppUser({required String id, String? email}) = _AppUser;
}
