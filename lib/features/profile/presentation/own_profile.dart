import 'package:evasion/features/profile/data/supabase_profile_repository.dart';
import 'package:evasion/features/profile/domain/profile.dart';
import 'package:evasion/features/profile/domain/profile_page.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'own_profile.g.dart';

/// The profile of the signed-in user [userId].
///
/// Keyed by user so that signing in with another account loads a fresh one.
/// Invalidate it after changing the profile to read it again.
@Riverpod(keepAlive: true)
Future<Profile> ownProfile(Ref ref, String userId) =>
    ref.watch(profileRepositoryProvider).fetchOwnProfile(userId);

/// The carousel pages of the signed-in user [userId], in their order.
@riverpod
Future<List<ProfilePage>> ownPages(Ref ref, String userId) =>
    ref.watch(profileRepositoryProvider).fetchPages(userId);
