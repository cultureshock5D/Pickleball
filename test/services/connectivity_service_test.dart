import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_app/services/connectivity_service.dart';
import 'package:pickleball_app/services/pos_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ConnectivityService service;

  setUp(() async {
    service = ConnectivityService.instance;
    service.resetForTesting();
    await PosDatabase.instance.initialize(forceMemory: true);
    await PosDatabase.instance.clearAll();
  });

  tearDown(() {
    service.resetForTesting();
  });

  group('ConnectivityService Tests', () {
    test('Reflects testOnlineOverride and reachability checker', () async {
      service.testReachabilityChecker = () async => true;
      final online = await service.checkReachability();
      expect(online, isTrue);
      expect(service.isOnline, isTrue);

      service.testReachabilityChecker = () async => false;
      final offline = await service.checkReachability();
      expect(offline, isFalse);
      expect(service.isOnline, isFalse);
    });

    test('Emits online/offline changes on stream', () async {
      final statuses = <bool>[];
      final sub = service.isOnlineStream.listen(statuses.add);

      service.testReachabilityChecker = () async => false;
      await service.checkReachability();

      service.testReachabilityChecker = () async => true;
      await service.checkReachability();

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(statuses, containsAllInOrder([false, true]));

      await sub.cancel();
    });

    test('Automatically triggers registered sync engine on offline -> online transition', () async {
      var flushCalled = 0;
      service.registerSyncEngine(() async {
        flushCalled++;
      });

      // Start offline
      service.testReachabilityChecker = () async => false;
      await service.checkReachability();
      expect(service.isOnline, isFalse);
      expect(flushCalled, 0);

      // Reconnect
      service.testReachabilityChecker = () async => true;
      await service.checkReachability();
      expect(service.isOnline, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(flushCalled, 1);
    });

    test('Manages SyncState and error metadata', () {
      expect(service.syncState, SyncState.idle);

      service.setSyncState(SyncState.syncing);
      expect(service.syncState, SyncState.syncing);

      service.setSyncState(SyncState.error, error: 'SocketException: Connection refused');
      expect(service.syncState, SyncState.error);
      expect(service.lastSyncError, 'SocketException: Connection refused');

      service.setSyncState(SyncState.idle);
      expect(service.syncState, SyncState.idle);
      expect(service.lastSyncedAt, isNotNull);
    });

    test('retrySync triggers flush when online or sets error when offline', () async {
      var flushInvoked = false;
      service.registerSyncEngine(() async {
        flushInvoked = true;
      });

      // When offline, retrySync sets error state
      service.testReachabilityChecker = () async => false;
      await service.retrySync();
      expect(service.syncState, SyncState.error);
      expect(flushInvoked, isFalse);

      // When online, retrySync invokes flush
      service.testReachabilityChecker = () async => true;
      await service.retrySync();
      expect(flushInvoked, isTrue);
    });
  });
}
