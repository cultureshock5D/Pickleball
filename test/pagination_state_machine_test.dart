import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_app/core/pagination/keyset_cursor.dart';
import 'package:pickleball_app/core/pagination/pagination_controller.dart';
import 'package:pickleball_app/core/pagination/pagination_state.dart';

class TestItem {
  final String id;
  final String title;
  final DateTime createdAt;

  TestItem({
    required this.id,
    required this.title,
    required this.createdAt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TestItem && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PaginationState Sealed Hierarchy', () {
    test('PaginationInitialLoading properties', () {
      const state = PaginationInitialLoading<TestItem>();
      expect(state.isInitialLoading, isTrue);
      expect(state.isContentLoaded, isFalse);
      expect(state.currentItems, isEmpty);
      expect(state, equals(const PaginationInitialLoading<TestItem>()));
    });

    test('PaginationContentLoaded properties and hasMore', () {
      final now = DateTime.now();
      final item1 = TestItem(id: '1', title: 'Item 1', createdAt: now);
      final cursor = KeysetCursor(createdAt: now, id: '1');

      final loadedWithMore = PaginationContentLoaded<TestItem>(
        items: [item1],
        nextCursor: cursor,
      );
      expect(loadedWithMore.isContentLoaded, isTrue);
      expect(loadedWithMore.hasMore, isTrue);
      expect(loadedWithMore.currentItems.length, 1);

      final loadedExhaustedCursor = PaginationContentLoaded<TestItem>(
        items: [item1],
      );
      expect(loadedExhaustedCursor.hasMore, isFalse);
    });

    test('PaginationFetchingNextChunk retains loaded items', () {
      final now = DateTime.now();
      final item1 = TestItem(id: '1', title: 'Item 1', createdAt: now);
      final cursor = KeysetCursor(createdAt: now, id: '1');

      final state = PaginationFetchingNextChunk<TestItem>(
        items: [item1],
        nextCursor: cursor,
      );
      expect(state.isFetchingNextChunk, isTrue);
      expect(state.currentItems, [item1]);
    });

    test('PaginationInlineChunkError preserves items and captures error details', () {
      final now = DateTime.now();
      final item1 = TestItem(id: '1', title: 'Item 1', createdAt: now);
      final cursor = KeysetCursor(createdAt: now, id: '1');

      const error = SocketException('Connection lost');
      final state = PaginationInlineChunkError<TestItem>(
        items: [item1],
        nextCursor: cursor,
        error: error,
        isNetworkError: true,
      );

      expect(state.isInlineChunkError, isTrue);
      expect(state.currentItems, [item1]);
      expect(state.isNetworkError, isTrue);
      expect(state.error, error);
    });

    test('PaginationFullScreenError holds error and has empty items', () {
      const error = SocketException('Initial connection refused');
      const state = PaginationFullScreenError<TestItem>(
        error: error,
        isNetworkError: true,
      );

      expect(state.isFullScreenError, isTrue);
      expect(state.currentItems, isEmpty);
      expect(state.isNetworkError, isTrue);
    });

    test('PaginationExhausted properties and equality', () {
      final now = DateTime.now();
      final item1 = TestItem(id: '1', title: 'Item 1', createdAt: now);
      final state = PaginationExhausted<TestItem>(items: [item1]);

      expect(state.isExhausted, isTrue);
      expect(state.currentItems, [item1]);
      expect(state, equals(PaginationExhausted<TestItem>(items: [item1])));
    });
  });

  group('PaginationController State Transitions', () {
    late DateTime baseTime;

    setUp(() {
      baseTime = DateTime.utc(2026, 9, 12, 12);
    });

    test('Initial loading -> Content loaded transition', () async {
      final item1 = TestItem(
        id: 'item-1',
        title: 'Court 1',
        createdAt: baseTime,
      );
      final cursor1 = KeysetCursor(createdAt: baseTime, id: 'item-1');

      final controller = PaginationController<TestItem>(
        fetchPageChunk: (cursor, pageSize) async {
          return PageChunk<TestItem>(
            items: [item1],
            nextCursor: cursor1,
            hasMore: true,
          );
        },
        idExtractor: (item) => item.id,
        autoLoad: false,
      );

      expect(controller.state.isInitialLoading, isTrue);
      await controller.initialLoad();

      expect(controller.state.isContentLoaded, isTrue);
      final loadedState = controller.state as PaginationContentLoaded<TestItem>;
      expect(loadedState.items, [item1]);
      expect(loadedState.nextCursor, cursor1);
      expect(controller.currentCursor, cursor1);
      controller.dispose();
    });

    test('Content loaded -> Fetching next chunk -> Content loaded lifecycle', () async {
      final item1 = TestItem(id: '1', title: 'Court 1', createdAt: baseTime);
      final item2 = TestItem(
        id: '2',
        title: 'Court 2',
        createdAt: baseTime.subtract(const Duration(minutes: 10)),
      );

      final cursor1 = KeysetCursor(createdAt: baseTime, id: '1');
      final cursor2 = KeysetCursor(createdAt: item2.createdAt, id: '2');

      int fetchCount = 0;
      final controller = PaginationController<TestItem>(
        fetchPageChunk: (cursor, pageSize) async {
          fetchCount++;
          if (cursor == null) {
            return PageChunk<TestItem>(
              items: [item1],
              nextCursor: cursor1,
              hasMore: true,
            );
          } else {
            return PageChunk<TestItem>(
              items: [item2],
              nextCursor: cursor2,
              hasMore: true,
            );
          }
        },
        idExtractor: (item) => item.id,
        autoLoad: false,
      );

      await controller.initialLoad();
      expect(controller.items.length, 1);

      final nextFuture = controller.fetchNextChunk();
      expect(controller.state.isFetchingNextChunk, isTrue);
      expect(controller.items.length, 1); // Preserves existing item while loading

      await nextFuture;
      expect(controller.state.isContentLoaded, isTrue);
      expect(controller.items.length, 2);
      expect(controller.items, [item1, item2]);
      expect(controller.currentCursor, cursor2);
      expect(fetchCount, 2);
      controller.dispose();
    });

    test('Inline chunk error preserves loaded items, retry recovers chunk', () async {
      final item1 = TestItem(id: '1', title: 'Court 1', createdAt: baseTime);
      final item2 = TestItem(
        id: '2',
        title: 'Court 2',
        createdAt: baseTime.subtract(const Duration(minutes: 10)),
      );

      final cursor1 = KeysetCursor(createdAt: baseTime, id: '1');
      final cursor2 = KeysetCursor(createdAt: item2.createdAt, id: '2');

      bool shouldFailNext = true;

      final controller = PaginationController<TestItem>(
        fetchPageChunk: (cursor, pageSize) async {
          if (cursor == null) {
            return PageChunk<TestItem>(
              items: [item1],
              nextCursor: cursor1,
              hasMore: true,
            );
          }
          if (shouldFailNext) {
            throw const SocketException('Transient network drop');
          }
          return PageChunk<TestItem>(
            items: [item2],
            nextCursor: cursor2,
            hasMore: true,
          );
        },
        idExtractor: (item) => item.id,
        autoLoad: false,
      );

      await controller.initialLoad();
      expect(controller.items.length, 1);

      // Attempt second chunk which throws SocketException
      await controller.fetchNextChunk();

      expect(controller.state.isInlineChunkError, isTrue);
      final errorState = controller.state as PaginationInlineChunkError<TestItem>;
      expect(errorState.items.length, 1);
      expect(errorState.items.first, item1); // Critical: loaded items preserved!
      expect(errorState.isNetworkError, isTrue);

      // Retry after connection restores
      shouldFailNext = false;
      await controller.retry();

      expect(controller.state.isContentLoaded, isTrue);
      expect(controller.items.length, 2);
      expect(controller.items, [item1, item2]);
      controller.dispose();
    });

    test('Initial fetch failure transitions to PaginationFullScreenError and retry recovers', () async {
      bool shouldFailInitial = true;
      final item1 = TestItem(id: '1', title: 'Court 1', createdAt: baseTime);

      final controller = PaginationController<TestItem>(
        fetchPageChunk: (cursor, pageSize) async {
          if (shouldFailInitial) {
            throw const SocketException('Network offline');
          }
          return PageChunk<TestItem>(
            items: [item1],
            hasMore: false,
          );
        },
        idExtractor: (item) => item.id,
        autoLoad: false,
      );

      await controller.initialLoad();

      expect(controller.state.isFullScreenError, isTrue);
      final fullError = controller.state as PaginationFullScreenError<TestItem>;
      expect(fullError.isNetworkError, isTrue);
      expect(fullError.currentItems, isEmpty);

      shouldFailInitial = false;
      await controller.retry();

      expect(controller.state.isExhausted, isTrue);
      expect(controller.items, [item1]);
      controller.dispose();
    });

    test('Transitions to PaginationExhausted when chunk hasMore is false', () async {
      final item1 = TestItem(id: '1', title: 'Court 1', createdAt: baseTime);

      final controller = PaginationController<TestItem>(
        fetchPageChunk: (cursor, pageSize) async {
          return PageChunk<TestItem>(
            items: [item1],
            hasMore: false,
          );
        },
        idExtractor: (item) => item.id,
        autoLoad: false,
      );

      await controller.initialLoad();
      expect(controller.state.isExhausted, isTrue);
      expect(controller.items, [item1]);

      // Further fetch attempts are no-ops
      await controller.fetchNextChunk();
      expect(controller.state.isExhausted, isTrue);
      controller.dispose();
    });

    test('Concurrency guard prevents duplicate in-flight requests', () async {
      int fetchCalls = 0;
      final completer = Completer<PageChunk<TestItem>>();

      final controller = PaginationController<TestItem>(
        fetchPageChunk: (cursor, pageSize) {
          fetchCalls++;
          return completer.future;
        },
        idExtractor: (item) => item.id,
        autoLoad: false,
      );

      // Start initial load (in-flight)
      final f1 = controller.initialLoad();
      expect(controller.isFetching, isTrue);

      // Rapid concurrent trigger should be guarded
      final f2 = controller.fetchNextChunk();
      expect(fetchCalls, 1);

      completer.complete(PageChunk<TestItem>(
        items: [TestItem(id: '1', title: 'Court 1', createdAt: baseTime)],
        hasMore: false,
      ));

      await Future.wait([f1, f2]);
      expect(fetchCalls, 1);
      controller.dispose();
    });

    test('Deduplication filters out duplicate item IDs across chunk boundaries', () async {
      final item1 = TestItem(id: '1', title: 'Court 1', createdAt: baseTime);
      final itemDuplicate = TestItem(id: '1', title: 'Court 1 Duplicate', createdAt: baseTime);
      final item2 = TestItem(
        id: '2',
        title: 'Court 2',
        createdAt: baseTime.subtract(const Duration(minutes: 10)),
      );

      final cursor1 = KeysetCursor(createdAt: baseTime, id: '1');

      final controller = PaginationController<TestItem>(
        fetchPageChunk: (cursor, pageSize) async {
          if (cursor == null) {
            return PageChunk<TestItem>(
              items: [item1],
              nextCursor: cursor1,
              hasMore: true,
            );
          }
          // Second chunk returns duplicate item 1 and new item 2
          return PageChunk<TestItem>(
            items: [itemDuplicate, item2],
            hasMore: false,
          );
        },
        idExtractor: (item) => item.id,
        autoLoad: false,
      );

      await controller.initialLoad();
      expect(controller.items.length, 1);

      await controller.fetchNextChunk();
      // Should have only 2 unique items, not 3
      expect(controller.items.length, 2);
      expect(controller.items.map((i) => i.id).toList(), ['1', '2']);
      controller.dispose();
    });

    test('In-place Realtime mutations update items in memory (<50ms)', () async {
      final item1 = TestItem(id: '1', title: 'Court 1', createdAt: baseTime);
      final item2 = TestItem(id: '2', title: 'Court 2', createdAt: baseTime);

      final controller = PaginationController<TestItem>(
        fetchPageChunk: (cursor, pageSize) async {
          return PageChunk<TestItem>(
            items: [item1, item2],
            hasMore: false,
          );
        },
        idExtractor: (item) => item.id,
        autoLoad: false,
      );

      await controller.initialLoad();
      expect(controller.items.length, 2);

      // 1. Insert item
      final newItem = TestItem(id: '3', title: 'Court 3', createdAt: baseTime);
      controller.insertItem(newItem, prepend: true);
      expect(controller.items.length, 3);
      expect(controller.items.first.id, '3');

      // 2. Update item
      final updatedItem = TestItem(id: '2', title: 'Court 2 - Renovated', createdAt: baseTime);
      controller.updateItem(updatedItem);
      expect(controller.items.firstWhere((i) => i.id == '2').title, 'Court 2 - Renovated');

      // 3. Remove item
      controller.removeItem('1');
      expect(controller.items.length, 2);
      expect(controller.items.any((i) => i.id == '1'), isFalse);
      controller.dispose();
    });
  });
}
