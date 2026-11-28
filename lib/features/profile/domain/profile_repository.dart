import 'dart:typed_data';

import 'package:evasion/core/photos/photo_file.dart';
import 'package:evasion/features/profile/domain/page_draft.dart';
import 'package:evasion/features/profile/domain/page_positions.dart';
import 'package:evasion/features/profile/domain/profile.dart';
import 'package:evasion/features/profile/domain/profile_details.dart';
import 'package:evasion/features/profile/domain/profile_page.dart';
import 'package:evasion/features/profile/domain/public_profile.dart';

/// Reads profiles, and edits the signed-in user's profile and pages.
///
/// Every method throws an `AppFailure` on error.
abstract interface class ProfileRepository {
  /// The profile of [userId], who must be the signed-in user.
  Future<Profile> fetchOwnProfile(String userId);

  /// Saves the texts of the profile of [userId], the signed-in user.
  Future<void> updateDetails(String userId, ProfileDetails details);

  /// Makes [bytes] the profile photo of [userId], the signed-in user, then
  /// deletes the previous photo.
  Future<void> replaceAvatar(
    String userId,
    Uint8List bytes,
    PhotoFormat format,
  );

  /// Uses the only birth date correction of [userId], the signed-in user.
  /// Fails with `InvalidInputFailure` if it was already used.
  Future<void> correctBirthDate(String userId, DateTime birthDate);

  /// The profile of [userId] as the signed-in user sees it. Fails with
  /// `NotFoundFailure` when they cannot see it: deleted, not complete yet, or
  /// blocked either way. The user never learns which.
  Future<PublicProfile> fetchPublicProfile(String userId);

  /// The carousel pages of [userId], the signed-in user or someone whose
  /// profile they can see, in their order. Pages this version of the app
  /// cannot show are left out.
  Future<List<ProfilePage>> fetchPages(String userId);

  /// The positions of all the pages of [userId], including those this version
  /// of the app cannot show.
  Future<List<PageSlot>> fetchOwnPageSlots(String userId);

  /// Adds a page of [userId], the signed-in user, at [position]. A photo page
  /// uploads its photo first, and removes it again if the page cannot be
  /// saved.
  Future<void> addPage(String userId, PageDraft draft, {required int position});

  /// Replaces the content of [page], a page of [userId], with [draft], of the
  /// same template. A new photo is uploaded first; the previous one is then
  /// deleted. Fails with `NotFoundFailure` if the page no longer exists.
  Future<void> updatePage(String userId, ProfilePage page, PageDraft draft);

  /// Deletes [page], then its photo if it has one. A page already deleted,
  /// for example from another phone, counts as deleted.
  Future<void> deletePage(ProfilePage page);

  /// Gives the signed-in user's pages the order of [pageIds], which must list
  /// each of them once.
  Future<void> reorderPages(List<String> pageIds);
}
