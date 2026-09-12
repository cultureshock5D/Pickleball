// ignore_for_file: avoid_redundant_argument_values
import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_app/core/network/network_connectivity_watcher.dart';
import 'package:pickleball_app/core/pagination/keyset_cursor.dart';
import 'package:pickleball_app/core/pagination/pagination_controller.dart';
import 'package:pickleball_app/core/pagination/pagination_state.dart';

class MockRecord {
  final String id;
  final String title;
  final DateTime createdAt;

  const MockRecord({
    required this.id,
    required this.title,
    required this.createdAt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MockRecord && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final baseTime = DateTime.utc(2026, 9, 12, 10);

  group('Empirical Challenge 1: Full 6-State Graph Transitions', () {
    test('Traverse full 6-state lifecycle in a single session', () async {
      final stateHistory = <String>[];
      bool failInitial = true;
      bool failChunk2 = true;

      final item1 = MockRecord(id: 'item-1', title: 'Court A', createdAt: baseTime);
      final item2 = MockRecord(id: 'item-2', title: 'Court B', createdAt: baseTime.subtract(const Duration(minutes: 5)));
      final item3 = MockRecord(id: 'item-3', title: 'Court C', createdAt: baseTime.subtract(const Duration(minutes: 10)));

      final cursor1 = KeysetCursor(createdAt: item1.createdAt, id: item1.id);
      final cursor2 = KeysetCursor(createdAt: item2.createdAt, id: item2.id);

      final controller = PaginationController<MockRecord>(
        fetchPageChunk: (cursor, pageSize) async {
          if (cursor == null) {
            if (failInitial) {
              throw const SocketException('Initial connection failed');
            }
            return PageChunk<MockRecord>(
              items: [item1],
              nextCursor: cursor1,
              hasMore: true,
            );
          } else if (cursor.id == 'item-1') {
            if (failChunk2) {
              throw const SocketException('Chunk 2 network dropped');
            }
            return PageChunk<MockRecord>(
              items: [item2],
              nextCursor: cursor2,
              hasMore: true,
            );
          } else {
            return PageChunk<MockRecord>(
              items: [item3],
              nextCursor: null,
              hasMore: false,
            );
          }
        },
        idExtractor: (item) => item.id,
        autoLoad: false,
      );

      controller.addListener(() {
        stateHistory.add(controller.state.runtimeType.toString());
      });

      // 1. Initial State: InitialLoading
      expect(controller.state.isInitialLoading, isTrue);

      // 2. Initial load fails -> FullScreenError
      await controller.initialLoad();
      expect(controller.state.isFullScreenError, isTrue);
      expect(controller.items, isEmpty);

      // 3. Retry initial load -> ContentLoaded
      failInitial = false;
      await controller.retry();
      expect(controller.state.isContentLoaded, isTrue);
      expect(controller.items, [item1]);

      // 4. Fetch next chunk fails -> InlineChunkError (preserves item1)
      await controller.fetchNextChunk();
      expect(controller.state.isInlineChunkError, isTrue);
      expect(controller.items, [item1]);

      // 5. Retry chunk 2 -> ContentLoaded (contains item1, item2)
      failChunk2 = false;
      await controller.retry();
      expect(controller.state.isContentLoaded, isTrue);
      expect(controller.items, [item1, item2]);

      // 6. Fetch next chunk -> Exhausted (contains item1, item2, item3)
      await controller.fetchNextChunk();
      expect(controller.state.isExhausted, isTrue);
      expect(controller.items, [item1, item2, item3]);

      // Verify all 6 states were visited
      expect(stateHistory, contains('PaginationFullScreenError<MockRecord>'));
      expect(stateHistory, contains('PaginationContentLoaded<MockRecord>'));
      expect(stateHistory, contains('PaginationFetchingNextChunk<MockRecord>'));
      expect(stateHistory, contains('PaginationInlineChunkError<MockRecord>'));
      expect(stateHistory, contains('PaginationExhausted<MockRecord>'));

      controller.dispose();
    });
  });

  group('Empirical Challenge 2: Memory Retention on Inline Chunk Error', () {
    test('100 loaded items strictly preserved across consecutive chunk errors', () async {
      final initial100Items = <MockRecord>[];
      for (int i = 0; i < 100; i++) {
        initial100Items.add(MockRecord(
          id: 'record-$i',
          title: 'Court Slot $i',
          createdAt: baseTime.subtract(Duration(seconds: i)),
        ));
      }

      final lastItem = initial100Items.last;
      final cursor = KeysetCursor(createdAt: lastItem.createdAt, id: lastItem.id);

      int chunkAttempts = 0;
      final controller = PaginationController<MockRecord>(
        fetchPageChunk: (c, pageSize) async {
          if (c == null) {
            return PageChunk<MockRecord>(
              items: initial100Items,
              nextCursor: cursor,
              hasMore: true,
            );
          }
          chunkAttempts++;
          throw SocketException('Simulated failure #$chunkAttempts');
        },
        idExtractor: (item) => item.id,
        autoLoad: false,
      );

      await controller.initialLoad();
      expect(controller.items.length, 100);

      // Attempt 1 fails
      await controller.fetchNextChunk();
      expect(controller.state.isInlineChunkError, isTrue);
      expect(controller.items.length, 100, reason: 'Memory must not drop items');
      expect(controller.items.first.id, 'record-0');
      expect(controller.items.last.id, 'record-99');

      // Consecutive retry attempt fails
      await controller.retry();
      expect(controller.state.isInlineChunkError, isTrue);
      expect(controller.items.length, 100, reason: 'Consecutive error must not wipe memory');
      expect(controller.items.first.id, 'record-0');
      expect(controller.items.last.id, 'record-99');

      controller.dispose();
    });
  });

  group('Empirical Challenge 3: Offline Drop Mid-Scroll & Auto-Resume', () {
    test('Offline drop mid-scroll triggers InlineChunkError and auto-resumes on reconnect', () async {
      final fakeWatcher = FakeNetworkConnectivityWatcher(initialConnected: true);
      final item1 = MockRecord(id: '1', title: 'Court 1', createdAt: baseTime);
      final item2 = MockRecord(id: '2', title: 'Court 2', createdAt: baseTime.subtract(const Duration(minutes: 1)));
      final cursor1 = KeysetCursor(createdAt: item1.createdAt, id: item1.id);

      bool isOffline = false;

      final controller = PaginationController<MockRecord>(
        fetchPageChunk: (cursor, pageSize) async {
          if (cursor == null) {
            return PageChunk<MockRecord>(items: [item1], nextCursor: cursor1, hasMore: true);
          }
          if (isOffline) {
            throw const SocketException('No Internet Connection');
          }
          return PageChunk<MockRecord>(items: [item2], nextCursor: null, hasMore: false);
        },
        idExtractor: (item) => item.id,
        connectivityWatcher: fakeWatcher,
        autoLoad: false,
      );

      await controller.initialLoad();
      expect(controller.items.length, 1);

      // Mid-scroll drop
      isOffline = true;
      fakeWatcher.setConnected(false);
      await Future.delayed(const Duration(milliseconds: 10));

      await controller.fetchNextChunk();
      expect(controller.state.isInlineChunkError, isTrue);
      final inlineErr = controller.state as PaginationInlineChunkError<MockRecord>;
      expect(inlineErr.isNetworkError, isTrue);
      expect(controller.items, [item1]);

      // Reconnect
      isOffline = false;
      fakeWatcher.setConnected(true);

      // Await auto-resume
      await Future.delayed(const Duration(milliseconds: 50));

      expect(controller.state.isExhausted, isTrue);
      expect(controller.items.length, 2);
      expect(controller.items, [item1, item2]);

      controller.dispose();
      fakeWatcher.dispose();
    });
  });

  group('Empirical Challenge 4: Concurrency Guard Stress Harness', () {
    test('100 concurrent fetchNextChunk() calls trigger exactly ONE fetch', () async {
      final item1 = MockRecord(id: '1', title: 'Court 1', createdAt: baseTime);
      final item2 = MockRecord(id: '2', title: 'Court 2', createdAt: baseTime.subtract(const Duration(minutes: 1)));
      final cursor1 = KeysetCursor(createdAt: item1.createdAt, id: item1.id);

      int fetchCalls = 0;
      final completer = Completer<PageChunk<MockRecord>>();

      final controller = PaginationController<MockRecord>(
        fetchPageChunk: (cursor, pageSize) async {
          fetchCalls++;
          if (cursor == null) {
            return PageChunk<MockRecord>(items: [item1], nextCursor: cursor1, hasMore: true);
          }
          return completer.future;
        },
        idExtractor: (item) => item.id,
        autoLoad: false,
      );

      await controller.initialLoad();
      expect(fetchCalls, 1);
      expect(controller.state.isContentLoaded, isTrue);

      // Fire 100 concurrent fetchNextChunk calls simultaneously
      final futures = <Future<void>>[];
      for (int i = 0; i < 100; i++) {
        futures.add(controller.fetchNextChunk());
      }

      // Concurrency guard must ensure fetchCalls is 2 (1 initial + 1 next chunk)
      expect(fetchCalls, 2);
      expect(controller.isFetching, isTrue);

      // Complete the pending chunk
      completer.complete(PageChunk<MockRecord>(
        items: [item2],
        nextCursor: null,
        hasMore: false,
      ));

      await Future.wait(futures);

      expect(fetchCalls, 2, reason: 'Concurrency guard must reject 99 redundant calls');
      expect(controller.state.isExhausted, isTrue);
      expect(controller.items.length, 2);

      controller.dispose();
    });

    test('100 concurrent initialLoad() calls during boot execute safely', () async {
      final completer = Completer<PageChunk<MockRecord>>();

      final controller = PaginationController<MockRecord>(
        fetchPageChunk: (cursor, pageSize) async {
          return completer.future;
        },
        idExtractor: (item) => item.id,
        autoLoad: false,
      );

      final futures = <Future<void>>[];
      for (int i = 0; i < 100; i++) {
        futures.add(controller.initialLoad());
      }

      expect(controller.isFetching, isTrue);

      completer.complete(PageChunk<MockRecord>(
        items: [MockRecord(id: 'root', title: 'Root Court', createdAt: baseTime)],
        nextCursor: null,
        hasMore: false,
      ));

      await Future.wait(futures);
      expect(controller.state.isExhausted, isTrue);
      expect(controller.items.length, 1);

      controller.dispose();
    });

    test('Interleaved realtime mutations during active chunk fetch are preserved', () async {
      final item1 = MockRecord(id: '1', title: 'Court 1', createdAt: baseTime);
      final item2 = MockRecord(id: '2', title: 'Court 2', createdAt: baseTime.subtract(const Duration(minutes: 1)));
      final cursor1 = KeysetCursor(createdAt: item1.createdAt, id: item1.id);

      final completer = Completer<PageChunk<MockRecord>>();

      final controller = PaginationController<MockRecord>(
        fetchPageChunk: (cursor, pageSize) async {
          if (cursor == null) {
            return PageChunk<MockRecord>(items: [item1], nextCursor: cursor1, hasMore: true);
          }
          return completer.future;
        },
        idExtractor: (item) => item.id,
        autoLoad: false,
      );

      await controller.initialLoad();
      expect(controller.items.length, 1);

      final fetchFuture = controller.fetchNextChunk();
      expect(controller.state.isFetchingNextChunk, isTrue);

      final realtimeItem = MockRecord(id: '3', title: 'Realtime Court 3', createdAt: DateTime.now());
      controller.insertItem(realtimeItem, prepend: true);
      expect(controller.items.first.id, '3');
      expect(controller.state.isFetchingNextChunk, isTrue);

      completer.complete(PageChunk<MockRecord>(
        items: [item2],
        nextCursor: null,
        hasMore: false,
      ));
      await fetchFuture;

      expect(controller.state.isExhausted, isTrue);

      controller.dispose();
    });
  });

  group('Empirical Verification 1: Disposed Controller In-Flight Guard', () {
    test('Resolving in-flight fetch after dispose() completes safely without FlutterError', () async {
      final item1 = MockRecord(id: '1', title: 'Court 1', createdAt: baseTime);
      final cursor1 = KeysetCursor(createdAt: item1.createdAt, id: item1.id);

      final completer = Completer<PageChunk<MockRecord>>();

      final controller = PaginationController<MockRecord>(
        fetchPageChunk: (cursor, pageSize) async {
          if (cursor == null) {
            return PageChunk<MockRecord>(items: [item1], nextCursor: cursor1, hasMore: true);
          }
          return completer.future;
        },
        idExtractor: (item) => item.id,
        autoLoad: false,
      );

      await controller.initialLoad();
      expect(controller.items.length, 1);

      // Start fetching
      final fetchFuture = controller.fetchNextChunk();

      // Dispose while in flight!
      controller.dispose();
      expect(controller.isDisposed, isTrue);

      // Resolve the fetch
      completer.complete(PageChunk<MockRecord>(
        items: [MockRecord(id: '2', title: 'Court 2', createdAt: baseTime)],
        nextCursor: null,
        hasMore: false,
      ));

      // Disposed controller completes future without throwing FlutterError
      await expectLater(fetchFuture, completes);
      expect(controller.isDisposed, isTrue);
    });
  });

  group('Empirical Verification 2: Cold Boot Offline Recovery', () {
    test('Cold boot offline auto-recovers on reconnect because initial connectivity is checked', () async {
      // Device is already offline before app starts
      final fakeWatcher = FakeNetworkConnectivityWatcher(initialConnected: false);
      bool isOnline = false;
      int attempts = 0;

      final controller = PaginationController<MockRecord>(
        fetchPageChunk: (cursor, pageSize) async {
          attempts++;
          if (!isOnline) {
            throw const SocketException('Device booted in airplane mode');
          }
          return PageChunk<MockRecord>(
            items: [MockRecord(id: '1', title: 'Court 1', createdAt: baseTime)],
            nextCursor: null,
            hasMore: false,
          );
        },
        idExtractor: (item) => item.id,
        connectivityWatcher: fakeWatcher,
        autoLoad: false,
      );

      // 1. Initial load while already offline (1 initial + 3 retries = 4 attempts)
      await controller.initialLoad();
      expect(controller.state.isFullScreenError, isTrue);
      expect(attempts, 4);

      // 2. Device connects to WiFi (comes online)
      isOnline = true;
      fakeWatcher.setConnected(true);

      // Wait for auto-resume trigger
      await Future.delayed(const Duration(milliseconds: 60));

      // Verifies controller automatically re-triggered initial load and recovered
      expect(controller.state.isExhausted, isTrue);
      expect(controller.items.length, 1);
      expect(attempts, 5);

      controller.dispose();
      fakeWatcher.dispose();
    });
  });
}
