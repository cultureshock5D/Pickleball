import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_app/core/network/network_connectivity_watcher.dart';
import 'package:pickleball_app/core/network/network_resilience.dart';
import 'package:pickleball_app/core/pagination/keyset_cursor.dart';
import 'package:pickleball_app/core/pagination/pagination_controller.dart';
import 'package:pickleball_app/core/pagination/pagination_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NetworkResilience Clamped Timeout & Backoff Tests', () {
    test('Verifies clamped timeout constant is 8 seconds', () {
      expect(NetworkResilience.clampedTimeout, const Duration(seconds: 8));
      expect(NetworkResilience.defaultMaxRetries, 3);
      expect(NetworkResilience.defaultBaseDelay, const Duration(milliseconds: 500));
      expect(NetworkResilience.defaultMaxDelay, const Duration(seconds: 4));
    });

    test('isTransientError correctly identifies network and 5xx server errors', () {
      expect(NetworkResilience.isTransientError(const SocketException('Host lookup failed')), isTrue);
      expect(NetworkResilience.isTransientError(TimeoutException('Timed out')), isTrue);
      expect(NetworkResilience.isTransientError(const ClampedTimeoutException()), isTrue);
      expect(NetworkResilience.isTransientError(Exception('HTTP 500 Internal Server Error')), isTrue);
      expect(NetworkResilience.isTransientError(Exception('HTTP 502 Bad Gateway')), isTrue);
      expect(NetworkResilience.isTransientError(Exception('HTTP 503 Service Unavailable')), isTrue);
      expect(NetworkResilience.isTransientError(Exception('HTTP 504 Gateway Timeout')), isTrue);
      expect(NetworkResilience.isTransientError(Exception('ClientException: Connection reset by peer')), isTrue);

      // Non-transient errors should NOT be retried
      expect(NetworkResilience.isTransientError(const FormatException('Invalid JSON')), isFalse);
      expect(NetworkResilience.isTransientError(ArgumentError('Invalid argument')), isFalse);
      expect(NetworkResilience.isTransientError(Exception('HTTP 400 Bad Request')), isFalse);
      expect(NetworkResilience.isTransientError(Exception('HTTP 401 Unauthorized')), isFalse);
      expect(NetworkResilience.isTransientError(Exception('HTTP 404 Not Found')), isFalse);
    });

    test('Clamped timeout aborts long-running request with TimeoutException', () async {
      final sw = Stopwatch()..start();
      expect(
        () => NetworkResilience.executeWithRetry(
          action: () async {
            await Future.delayed(const Duration(milliseconds: 300));
            return 'success';
          },
          timeout: const Duration(milliseconds: 50),
          maxRetries: 0,
        ),
        throwsA(isA<TimeoutException>()),
      );
      sw.stop();
    });

    test('executeWithRetry clamps explicit timeout to clampedTimeout upper bound', () async {
      final result = await NetworkResilience.executeWithRetry(
        action: () async {
          await Future.delayed(const Duration(milliseconds: 20));
          return 'ok';
        },
        timeout: const Duration(seconds: 30),
        maxRetries: 0,
      );
      expect(result, 'ok');
    });

    test('Exponential backoff with jitter retries transient failures up to maxRetries', () async {
      int attempts = 0;
      final recordedDelays = <Duration>[];
      final deterministicRng = Random(42); // Deterministic seed

      expect(
        () => NetworkResilience.executeWithRetry(
          action: () async {
            attempts++;
            throw const SocketException('Persistent network failure');
          },
          baseDelay: const Duration(milliseconds: 10),
          maxDelay: const Duration(milliseconds: 100),
          timeout: const Duration(seconds: 1),
          random: deterministicRng,
          onRetry: (attempt, error, delay) {
            recordedDelays.add(delay);
          },
        ),
        throwsA(isA<SocketException>()),
      );

      // Verify attempts and retry delays
      await Future.delayed(const Duration(milliseconds: 150));
      expect(attempts, 4); // 1 initial + 3 retries
      expect(recordedDelays.length, 3);
      // Delays must be non-negative and capped by maxDelay
      for (final d in recordedDelays) {
        expect(d.inMilliseconds, greaterThanOrEqualTo(0));
        expect(d.inMilliseconds, lessThanOrEqualTo(100));
      }
    });

    test('Recovers successfully when transient error clears before maxRetries', () async {
      int attempts = 0;

      final result = await NetworkResilience.executeWithRetry<String>(
        action: () async {
          attempts++;
          if (attempts <= 2) {
            throw const SocketException('Temporary wifi glitch');
          }
          return 'restored';
        },
        baseDelay: const Duration(milliseconds: 10),
        maxDelay: const Duration(milliseconds: 50),
      );

      expect(result, 'restored');
      expect(attempts, 3); // Failed twice, succeeded on attempt 3
    });

    test('Non-transient error fails immediately without retrying', () async {
      int attempts = 0;

      expect(
        () => NetworkResilience.executeWithRetry(
          action: () async {
            attempts++;
            throw const FormatException('Malformed response body');
          },
          baseDelay: const Duration(milliseconds: 10),
        ),
        throwsA(isA<FormatException>()),
      );

      expect(attempts, 1); // Exact 1 attempt, zero retries
    });
  });

  group('NetworkConnectivityWatcher & Offline Drop / Auto-Resume Tests', () {
    late FakeNetworkConnectivityWatcher fakeWatcher;
    late DateTime baseTime;

    setUp(() {
      fakeWatcher = FakeNetworkConnectivityWatcher();
      baseTime = DateTime.utc(2026, 9, 12, 12);
    });

    tearDown(() {
      fakeWatcher.dispose();
    });

    test('FakeNetworkConnectivityWatcher emits state updates accurately', () async {
      expect(await fakeWatcher.isConnected, isTrue);

      final events = <bool>[];
      final sub = fakeWatcher.onConnectivityChanged.listen(events.add);

      fakeWatcher.setConnected(false);
      fakeWatcher.setConnected(true);
      await Future.delayed(const Duration(milliseconds: 20));

      expect(events, [false, true]);
      expect(await fakeWatcher.isConnected, isTrue);
      await sub.cancel();
    });

    test('Offline drop mid-scroll preserves items, automatic chunk resume on reconnect', () async {
      const item1 = 'court-booking-001';
      const item2 = 'court-booking-002';
      final cursor1 = KeysetCursor(createdAt: baseTime, id: item1);
      final cursor2 = KeysetCursor(createdAt: baseTime.subtract(const Duration(minutes: 5)), id: item2);

      bool networkDropped = false;

      final controller = PaginationController<String>(
        fetchPageChunk: (cursor, pageSize) async {
          if (cursor == null) {
            return PageChunk<String>(
              items: [item1],
              nextCursor: cursor1,
              hasMore: true,
            );
          }

          if (networkDropped) {
            throw const SocketException('Client is offline in arena tunnel');
          }

          return PageChunk<String>(
            items: [item2],
            nextCursor: cursor2,
            hasMore: false,
          );
        },
        idExtractor: (item) => item,
        connectivityWatcher: fakeWatcher,
        autoLoad: false,
      );

      // 1. Initial load while online
      await controller.initialLoad();
      expect(controller.state.isContentLoaded, isTrue);
      expect(controller.items, [item1]);

      // 2. User goes into offline tunnel mid-scroll
      networkDropped = true;
      fakeWatcher.setConnected(false);
      await Future.delayed(const Duration(milliseconds: 10));

      // User triggers fetchNextChunk while offline
      await controller.fetchNextChunk();

      // State is inline error, but item1 is strictly preserved!
      expect(controller.state.isInlineChunkError, isTrue);
      final errorState = controller.state as PaginationInlineChunkError<String>;
      expect(errorState.isNetworkError, isTrue);
      expect(errorState.items, [item1]);

      // 3. User reconnects (comes out of tunnel)
      networkDropped = false;
      fakeWatcher.setConnected(true);

      // Allow auto-resume trigger to fire
      await Future.delayed(const Duration(milliseconds: 50));

      // Verification: State automatically resumed and exhausted second chunk without user manual click
      expect(controller.state.isExhausted, isTrue);
      expect(controller.items, [item1, item2]);

      controller.dispose();
    });

    test('Offline drop on initial load automatically retries when reconnected', () async {
      bool networkAvailable = false;
      const item1 = 'court-booking-001';

      final controller = PaginationController<String>(
        fetchPageChunk: (cursor, pageSize) async {
          if (!networkAvailable) {
            throw const SocketException('No route to host');
          }
          return const PageChunk<String>(
            items: [item1],
            hasMore: false,
          );
        },
        idExtractor: (item) => item,
        connectivityWatcher: fakeWatcher,
        autoLoad: false,
      );

      // Start initial load while offline
      fakeWatcher.setConnected(false);
      await Future.delayed(const Duration(milliseconds: 10));

      await controller.initialLoad();
      expect(controller.state.isFullScreenError, isTrue);
      final fullError = controller.state as PaginationFullScreenError<String>;
      expect(fullError.isNetworkError, isTrue);

      // Reconnect
      networkAvailable = true;
      fakeWatcher.setConnected(true);
      await Future.delayed(const Duration(milliseconds: 50));

      // Verifies automatic initial load recovery
      expect(controller.state.isExhausted, isTrue);
      expect(controller.items, [item1]);

      controller.dispose();
    });
  });
}
