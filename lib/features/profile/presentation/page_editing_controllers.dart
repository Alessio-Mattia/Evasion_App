import 'dart:async';

import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/features/profile/data/supabase_profile_repository.dart';
import 'package:evasion/features/profile/domain/page_draft.dart';
import 'package:evasion/features/profile/domain/page_positions.dart';
import 'package:evasion/features/profile/domain/profile_page.dart';
import 'package:evasion/features/profile/presentation/own_profile.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'page_editing_controllers.g.dart';

/// Adds a page at the end of the carousel of [userId]. The state is loading
/// during the save, then an error holding an `AppFailure`, or data.
@riverpod
class AddPageController extends _$AddPageController {
  @override
  FutureOr<void> build(String userId) {}

  /// Returns whether the page was added.
  Future<bool> add(PageDraft draft) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    final repository = ref.read(profileRepositoryProvider);
    final result = await AsyncValue.guard(() async {
      // Fresh positions: the carousel shown may be out of date.
      final slots = await repository.fetchOwnPageSlots(userId);
      switch (placeNewPage(slots)) {
        case PagesFull():
          throw const LimitReachedFailure();
        case AppendPage(:final position):
          await repository.addPage(userId, draft, position: position);
        case CompactThenAppend(:final order, :final position):
          await repository.reorderPages(order);
          await repository.addPage(userId, draft, position: position);
      }
    });
    if (!ref.mounted) return false;
    ref.invalidate(ownPagesProvider(userId));
    state = result;
    return !result.hasError;
  }
}

/// Deletes a page of [userId]. The state is loading during the deletion, then
/// an error holding an `AppFailure`, or data.
@riverpod
class DeletePageController extends _$DeletePageController {
  @override
  FutureOr<void> build(String userId) {}

  /// Returns whether the page was deleted.
  Future<bool> delete(ProfilePage page) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    final repository = ref.read(profileRepositoryProvider);
    final result = await AsyncValue.guard(() => repository.deletePage(page));
    if (!result.hasError) {
      // Closing the gap only tidies up: the page is deleted even if this
      // fails, and the next addition closes it anyway.
      try {
        final order = compactedOrder(
          await repository.fetchOwnPageSlots(userId),
        );
        if (order != null) await repository.reorderPages(order);
      } on AppFailure {
        // Ignored, see above.
      }
    }
    if (!ref.mounted) return false;
    ref.invalidate(ownPagesProvider(userId));
    state = result;
    return !result.hasError;
  }
}

/// Changes the content of a page of [userId]. The state is loading during the
/// save, then an error holding an `AppFailure`, or data.
@riverpod
class UpdatePageController extends _$UpdatePageController {
  @override
  FutureOr<void> build(String userId) {}

  /// Returns whether the page was saved.
  Future<bool> save(ProfilePage page, PageDraft draft) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(profileRepositoryProvider).updatePage(userId, page, draft),
    );
    if (!ref.mounted) return false;
    ref.invalidate(ownPagesProvider(userId));
    state = result;
    return !result.hasError;
  }
}

/// Saves a new order of the pages of [userId]. The state is loading during the
/// save, then an error holding an `AppFailure`, or data.
@riverpod
class ReorderPagesController extends _$ReorderPagesController {
  @override
  FutureOr<void> build(String userId) {}

  /// Returns whether the order was saved. [pages] are the pages shown, in
  /// their new order.
  Future<bool> reorder(List<ProfilePage> pages) async {
    // One order at a time, so that an older one cannot finish last.
    if (state.isLoading) return false;
    state = const AsyncLoading();
    final repository = ref.read(profileRepositoryProvider);
    final result = await AsyncValue.guard(() async {
      final slots = await repository.fetchOwnPageSlots(userId);
      await repository.reorderPages(
        reorderedIds([for (final page in pages) page.id], slots),
      );
    });
    if (!ref.mounted) return false;
    ref.invalidate(ownPagesProvider(userId));
    state = result;
    return !result.hasError;
  }
}
