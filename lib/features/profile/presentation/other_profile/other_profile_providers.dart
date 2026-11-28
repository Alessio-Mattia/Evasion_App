import 'package:evasion/features/profile/data/supabase_profile_repository.dart';
import 'package:evasion/features/profile/domain/profile_page.dart';
import 'package:evasion/features/profile/domain/public_profile.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'other_profile_providers.g.dart';

/// The profile of [userId], someone else, as the signed-in user sees it.
@riverpod
Future<PublicProfile> publicProfile(Ref ref, String userId) =>
    ref.watch(profileRepositoryProvider).fetchPublicProfile(userId);

/// The carousel pages of [userId], someone else, in their order.
@riverpod
Future<List<ProfilePage>> otherPages(Ref ref, String userId) =>
    ref.watch(profileRepositoryProvider).fetchPages(userId);
