import 'package:evasion/core/errors/app_failure.dart';
import 'package:evasion/features/profile/data/supabase_profile_repository.dart';
import 'package:evasion/features/profile/domain/page_draft.dart';
import 'package:evasion/features/profile/domain/profile_page.dart';
import 'package:evasion/features/profile/presentation/page_editing_controllers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_profile_repositories.dart';

const userId = 'user-1';

ProfilePage textAt(int position, [String? id]) =>
    ProfilePage.text(id: id ?? 'p$position', position: position, text: 'Salut');

void main() {
  late FakeProfileStore store;
  late ProviderContainer container;

  setUp(() {
    store = FakeProfileStore(completeProfile(userId));
    container = ProviderContainer(
      overrides: [profileRepositoryProvider.overrideWithValue(store)],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
  });

  Future<bool> add(PageDraft draft) {
    final provider = addPageControllerProvider(userId);
    // Keeps the auto-dispose controller alive during the test.
    container.listen(provider, (_, _) {});
    return container.read(provider.notifier).add(draft);
  }

  Future<bool> delete(ProfilePage page) {
    final provider = deletePageControllerProvider(userId);
    container.listen(provider, (_, _) {});
    return container.read(provider.notifier).delete(page);
  }

  group('AddPageController', () {
    test('adds the page after the last one', () async {
      store.pages = [textAt(1), textAt(2)];

      expect(await add(const TextPageDraft('Hello')), isTrue);

      expect(store.pageCalls, ['add 3']);
    });

    test('counts the pages this version cannot show', () async {
      store
        ..pages = [textAt(1)]
        ..hiddenSlots = [(id: 'future', position: 2)];

      await add(const TextPageDraft('Hello'));

      expect(store.pageCalls, ['add 3']);
    });

    test('closes the gaps when the last position is taken', () async {
      store.pages = [textAt(1), textAt(2), textAt(3), textAt(5)];

      expect(await add(const TextPageDraft('Hello')), isTrue);

      expect(store.pageCalls, ['reorder p1,p2,p3,p5', 'add 5']);
    });

    test('refuses a sixth page without calling the server', () async {
      store.pages = [for (var i = 1; i <= 5; i++) textAt(i)];

      expect(await add(const TextPageDraft('Hello')), isFalse);

      expect(store.pageCalls, isEmpty);
      expect(
        container.read(addPageControllerProvider(userId)).error,
        isA<LimitReachedFailure>(),
      );
    });

    test('keeps the failure in its state', () async {
      store.addFailure = const NetworkFailure();

      expect(await add(const TextPageDraft('Hello')), isFalse);

      expect(
        container.read(addPageControllerProvider(userId)).error,
        isA<NetworkFailure>(),
      );
    });
  });

  group('DeletePageController', () {
    test('closes the gap left by a page in the middle', () async {
      store.pages = [textAt(1), textAt(2), textAt(3)];

      expect(await delete(store.pages[1]), isTrue);

      expect(store.pageCalls, ['delete p2', 'reorder p1,p3']);
      expect(store.pages.map((page) => page.position), [1, 2]);
    });

    test('has no gap to close after the last page', () async {
      store.pages = [textAt(1), textAt(2)];

      await delete(store.pages[1]);

      expect(store.pageCalls, ['delete p2']);
    });

    test('a failed tidy-up still counts as deleted', () async {
      store
        ..pages = [textAt(1), textAt(2)]
        ..reorderFailure = const NetworkFailure();

      expect(await delete(store.pages.first), isTrue);

      expect(
        container.read(deletePageControllerProvider(userId)).hasError,
        isFalse,
      );
    });

    test('a failed deletion keeps the page and its failure', () async {
      store
        ..pages = [textAt(1), textAt(2)]
        ..deleteFailure = const NetworkFailure();

      expect(await delete(store.pages.first), isFalse);

      expect(store.pageCalls, ['delete p1']);
      expect(store.pages, hasLength(2));
      expect(
        container.read(deletePageControllerProvider(userId)).error,
        isA<NetworkFailure>(),
      );
    });
  });

  group('UpdatePageController', () {
    Future<bool> save(ProfilePage page, PageDraft draft) {
      final provider = updatePageControllerProvider(userId);
      container.listen(provider, (_, _) {});
      return container.read(provider.notifier).save(page, draft);
    }

    test('saves the new content of the page', () async {
      store.pages = [textAt(1)];

      expect(
        await save(store.pages.single, const TextPageDraft('Hey')),
        isTrue,
      );

      expect(store.pageCalls, ['update p1']);
      expect(
        store.pages.single,
        isA<TextPage>().having((p) => p.text, 'text', 'Hey'),
      );
    });

    test('a page deleted meanwhile fails with its reason', () async {
      expect(await save(textAt(1), const TextPageDraft('Hey')), isFalse);

      expect(
        container.read(updatePageControllerProvider(userId)).error,
        isA<NotFoundFailure>(),
      );
    });
  });

  group('ReorderPagesController', () {
    Future<bool> reorder(List<ProfilePage> pages) {
      final provider = reorderPagesControllerProvider(userId);
      container.listen(provider, (_, _) {});
      return container.read(provider.notifier).reorder(pages);
    }

    test('sends the order chosen, hidden pages included', () async {
      store
        ..pages = [textAt(1), textAt(2)]
        ..hiddenSlots = [(id: 'future', position: 3)];

      expect(await reorder([store.pages[1], store.pages[0]]), isTrue);

      expect(store.pageCalls, ['reorder p2,p1,future']);
      expect(
        {for (final page in store.pages) page.id: page.position},
        {'p2': 1, 'p1': 2},
      );
    });

    test('keeps the failure in its state', () async {
      store
        ..pages = [textAt(1), textAt(2)]
        ..reorderFailure = const NetworkFailure();

      expect(await reorder([store.pages[1], store.pages[0]]), isFalse);

      expect(
        container.read(reorderPagesControllerProvider(userId)).error,
        isA<NetworkFailure>(),
      );
    });
  });
}
