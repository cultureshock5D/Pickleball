import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_app/models/pos_transaction_model.dart';
import 'package:pickleball_app/services/connectivity_service.dart';
import 'package:pickleball_app/services/pos_database.dart';
import 'package:pickleball_app/services/sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PosDatabase db;
  late SyncService syncService;
  late ConnectivityService connectivity;

  setUp(() async {
    db = PosDatabase.instance;
    await db.initialize(forceMemory: true);
    await db.clearAll();

    syncService = SyncService.instance;
    syncService.testPushHandler = null;

    connectivity = ConnectivityService.instance;
    connectivity.testOnlineOverride = true;
  });

  tearDown(() async {
    await db.clearAll();
    syncService.testPushHandler = null;
    connectivity.testOnlineOverride = null;
  });

  PosTransactionModel makeTx({required String id, required String invoice}) {
    return PosTransactionModel(
      id: id,
      invoiceNumber: invoice,
      cashierId: 'cashier-1',
      grossAmount: 150.0,
      discountAmount: 0.0,
      vatableSales: 133.93,
      vatAmount: 16.07,
      vatExemptSales: 0.0,
      totalAmount: 150.0,
      paymentMethod: 'Cash',
      createdAt: DateTime.now(),
      items: [
        PosTransactionItemModel(
          id: 'item-$id',
          transactionId: id,
          productId: 'p-1',
          productName: 'Matcha Latte',
          quantity: 1,
          priceAtTime: 150.0,
        ),
      ],
    );
  }

  group('SyncService Tests', () {
    test('saveOrderAndPush stores transaction locally and enqueues mutation', () async {
      final pushedItems = <int>[];
      syncService.testPushHandler = (item) async {
        pushedItems.add(item['id'] as int);
        return true;
      };

      final tx = makeTx(id: 'tx-push-1', invoice: 'INV-101');
      await syncService.saveOrderAndPush(tx);

      // Verify local storage
      final local = await db.getLocalTransactions();
      expect(local.length, 1);
      expect(local.first.id, 'tx-push-1');

      // Wait a microtask for background push
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(pushedItems.length, 1);

      // Queue item should now be processed and deleted
      final queue = await db.getPendingQueue();
      expect(queue.isEmpty, isTrue);
      expect(connectivity.syncState, SyncState.idle);
    });

    test('flushPendingQueue processes multiple items and handles errors gracefully', () async {
      connectivity.testOnlineOverride = false; // Prevent auto-push during creation

      final tx1 = makeTx(id: 'tx-batch-1', invoice: 'INV-201');
      final tx2 = makeTx(id: 'tx-batch-2', invoice: 'INV-202');

      await db.insertTransactionWithQueue(tx1);
      await db.insertTransactionWithQueue(tx2);

      var queue = await db.getPendingQueue();
      expect(queue.length, 2);

      // Set push handler: tx1 succeeds, tx2 throws error
      syncService.testPushHandler = (item) async {
        final qId = item['id'] as int;
        if (qId == queue[0]['id']) {
          return true;
        } else {
          throw Exception('Supabase 503 Service Unavailable');
        }
      };

      await syncService.flushPendingQueue();

      queue = await db.getPendingQueue();
      // tx1 removed, tx2 failed and kept in queue
      expect(queue.length, 1);
      expect(queue.first['status'], 'failed');
      expect(queue.first['attempts'], 1);
      expect(connectivity.syncState, SyncState.error);
    });
  });
}
