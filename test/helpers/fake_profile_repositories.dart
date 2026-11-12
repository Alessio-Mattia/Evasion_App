import 'dart:typed_data';

import 'package:evasion/core/config/business_rules.dart';
import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/core/models/gender.dart';
import 'package:evasion/core/photos/photo_file.dart';
import 'package:evasion/features/onboarding/domain/onboarding_progress.dart';
import 'package:evasion/features/onboarding/domain/onboarding_repository.dart';
import 'package:evasion/features/profile/domain/page_draft.dart';
import 'package:evasion/features/profile/domain/page_positions.dart';
import 'package:evasion/features/profile/domain/profile.dart';
import 'package:evasion/features/profile/domain/profile_page.dart';
import 'package:evasion/features/profile/domain/profile_repository.dart';

/// Profile with every required field, as after onboarding.
Profile completeProfile(String userId) => Profile(
  id: userId,
  isComplete: true,
  isStudentVerified: false,
  displayName: 'Alex',
  birthDate: DateTime(2000),
  gender: Gender.other,
  avatarPath: '$userId/avatar.jpg',
);

/// Profile right after sign-up.
Profile emptyProfile(String userId) =>
    Profile(id: userId, isComplete: false, isStudentVerified: false);

/// In-memory `profiles` table holding the profile of a single user.
///
/// [isComplete] is recomputed from the fields, as the server does.
class FakeProfileStore implements ProfileRepository, OnboardingRepository {
  FakeProfileStore(this.profile);

  Profile profile;

  /// Set to make the next profile reads fail.
  AppFailure? fetchFailure;

  /// Set to make the next saves fail.
  AppFailure? saveFailure;

  /// Set to make the next onboarding progress reads fail.
  AppFailure? progressFailure;
  int fetchCount = 0;
  final List<Map<String, Object?>> savedChanges = [];
  final List<PhotoFormat> savedPhotoFormats = [];

  /// Carousel pages of the user, in any order: they are read by position.
  List<ProfilePage> pages = [];

  /// Pages of a type this version of the app cannot show: they take a
  /// position but are not in [pages].
  List<PageSlot> hiddenSlots = [];

  /// Set to make the next page reads fail.
  AppFailure? pagesFailure;

  /// Set to make the next page additions, deletions or reorders fail.
  AppFailure? addFailure;
  AppFailure? deleteFailure;
  AppFailure? reorderFailure;

  /// Page operations, in the order they were made, such as `add 3` or
  /// `reorder p1,p3`.
  final List<String> pageCalls = [];

  /// Content of the last page added, as it would reach the server.
  Map<String, Object>? lastAddedContent;

  /// Photos deleted with their page.
  final List<String> deletedPhotos = [];

  @override
  Future<Profile> fetchOwnProfile(String userId) async {
    fetchCount++;
    if (fetchFailure case final failure?) throw failure;
    return profile;
  }

  @override
  Future<List<ProfilePage>> fetchOwnPages(String userId) async {
    if (pagesFailure case final failure?) throw failure;
    return [...pages]..sort((a, b) => a.position.compareTo(b.position));
  }

  @override
  Future<List<PageSlot>> fetchOwnPageSlots(String userId) async {
    if (pagesFailure case final failure?) throw failure;
    return [
      for (final page in pages) (id: page.id, position: page.position),
      ...hiddenSlots,
    ];
  }

  @override
  Future<void> addPage(
    String userId,
    PageDraft draft, {
    required int position,
  }) async {
    pageCalls.add('add $position');
    if (addFailure case final failure?) throw failure;
    final slots = await fetchOwnPageSlots(profile.id);
    // Same rules as the database.
    if (position < 1 || position > BusinessRules.profilePagesMax) {
      throw const InvalidInputFailure();
    }
    if (slots.any((slot) => slot.position == position)) {
      throw const ConflictFailure();
    }
    final id = 'page-${pageCalls.length}';
    lastAddedContent = draft.content;
    pages.add(switch (draft) {
      TextPageDraft() => ProfilePage.text(
        id: id,
        position: position,
        text: draft.content['text']! as String,
      ),
      PhotoPageDraft(:final format) => ProfilePage.photo(
        id: id,
        position: position,
        imagePath: userPhotoPath(
          userId: profile.id,
          fileName: id,
          format: format,
        ),
        caption: draft.content['caption'] as String?,
      ),
      InterestsPageDraft(:final interests) => ProfilePage.interests(
        id: id,
        position: position,
        interests: interests,
      ),
    });
  }

  @override
  Future<void> deletePage(ProfilePage page) async {
    pageCalls.add('delete ${page.id}');
    if (deleteFailure case final failure?) throw failure;
    pages.removeWhere((existing) => existing.id == page.id);
    if (page case PhotoPage(:final imagePath)) deletedPhotos.add(imagePath);
  }

  @override
  Future<void> reorderPages(List<String> pageIds) async {
    pageCalls.add('reorder ${pageIds.join(',')}');
    if (reorderFailure case final failure?) throw failure;
    final slots = await fetchOwnPageSlots(profile.id);
    // Same check as reorder_profile_pages.
    if (pageIds.length != slots.length ||
        !slots.every((slot) => pageIds.contains(slot.id))) {
      throw const InvalidInputFailure();
    }
    int positionOf(String id) => pageIds.indexOf(id) + 1;
    pages = [
      for (final page in pages) page.copyWith(position: positionOf(page.id)),
    ];
    hiddenSlots = [
      for (final slot in hiddenSlots)
        (id: slot.id, position: positionOf(slot.id)),
    ];
  }

  @override
  Future<OnboardingProgress> fetchProgress() async {
    if (progressFailure case final failure?) throw failure;
    return OnboardingProgress(
      hasDisplayName: profile.displayName != null,
      hasBirthDate: profile.birthDate != null,
      hasGender: profile.gender != null,
      hasPhoto: profile.avatarPath != null,
    );
  }

  @override
  Future<void> saveBasics({
    String? displayName,
    DateTime? birthDate,
    Gender? gender,
  }) async {
    if (saveFailure case final failure?) throw failure;
    savedChanges.add({
      'display_name': ?displayName,
      'birth_date': ?birthDate,
      'gender': ?gender,
    });
    _update(
      profile.copyWith(
        displayName: displayName ?? profile.displayName,
        birthDate: birthDate ?? profile.birthDate,
        gender: gender ?? profile.gender,
      ),
    );
  }

  @override
  Future<void> savePhoto(Uint8List bytes, PhotoFormat format) async {
    if (saveFailure case final failure?) throw failure;
    savedPhotoFormats.add(format);
    _update(
      profile.copyWith(
        avatarPath: userPhotoPath(
          userId: profile.id,
          fileName: 'photo-${savedPhotoFormats.length}',
          format: format,
        ),
      ),
    );
  }

  void _update(Profile updated) {
    profile = updated.copyWith(
      isComplete:
          updated.displayName != null &&
          updated.birthDate != null &&
          updated.gender != null &&
          updated.avatarPath != null,
    );
  }
}
