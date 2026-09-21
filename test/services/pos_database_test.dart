import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_app/models/pos_transaction_model.dart';
import 'package:pickleball_app/services/pos_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PosDatabase db;

  setUp(() async {
    db = PosDatabase.instance;
    await db.initialize(forceMemory: true);
    await db.clearAll();
  });

  tearDown(() async {
    await db.clearAll();
  });

  PosTransactionModel makeSampleTransaction({
    String id = 'tx-test-1',
    String invoice = 'INV-2026-0001',
  }) {
    return PosTransactionModel(
      id: id,
      invoiceNumber: invoice,
      cashierId: 'cashier-101',
      customerName: 'Juan Dela Cruz',
      customerTin: '123-456-789-000',
      discountType: 'senior_citizen',
      discountIdNumber: 'OSCA-9988',
      grossAmount: 300.0,
      discountAmount: 60.0,
      vatableSales: 0.0,
      vatAmount: 0.0,
      vatExemptSales: 240.0,
      totalAmount: 240.0,
      paymentMethod: 'Cash',
      createdAt: DateTime.now(),
      items: [
        PosTransactionItemModel(
          id: 'item-1',
          transactionId: id,
          productId: 'prod-coffee-1',
          productName: 'Long Black',
          quantity: 2,
          priceAtTime: 120.0,
        ),
      ],
    );
  }

  group('PosDatabase & Sync Queue Tests', () {
    test('Atomically records transaction and sync queue entry', () async {
      final tx = makeSampleTransaction();
      await db.insertTransactionWithQueue(tx);

      final localList = await db.getLocalTransactions();
      expect(localList.length, 1);
      expect(localList.first.id, tx.id);
      expect(localList.first.invoiceNumber, tx.invoiceNumber);
      expect(localList.first.items.length, 1);
      expect(localList.first.items.first.productName, 'Long Black');

      final queue = await db.getPendingQueue();
      expect(queue.length, 1);
      expect(queue.first['mutation_type'], 'CREATE_TRANSACTION');
      expect(queue.first['status'], 'pending');
      expect(queue.first['attempts'], 0);

      final count = await db.getPendingQueueCount();
      expect(count, 1);
    });

    test('Preserves FIFO ordering for multiple pending transactions', () async {
      final tx1 = makeSampleTransaction(id: 'tx-1', invoice: 'INV-001');
      final tx2 = makeSampleTransaction(id: 'tx-2', invoice: 'INV-002');
      final tx3 = makeSampleTransaction(id: 'tx-3', invoice: 'INV-003');

      await db.insertTransactionWithQueue(tx1);
      await db.insertTransactionWithQueue(tx2);
      await db.insertTransactionWithQueue(tx3);

      final queue = await db.getPendingQueue();
      expect(queue.length, 3);
      expect(queue[0]['id'], lessThan(queue[1]['id'] as int));
      expect(queue[1]['id'], lessThan(queue[2]['id'] as int));
    });

    test('Updates item status to syncing and deletes on completion', () async {
      final tx = makeSampleTransaction();
      await db.insertTransactionWithQueue(tx);

      var queue = await db.getPendingQueue();
      final qId = queue.first['id'] as int;

      await db.markQueueItemSyncing(qId);
      // Item is still counted in pending count while in flight
      expect(await db.getPendingQueueCount(), 1);

      await db.deleteQueueItem(qId);
      queue = await db.getPendingQueue();
      expect(queue.isEmpty, isTrue);
      expect(await db.getPendingQueueCount(), 0);
    });

    test('Marks item as failed with error message and increments attempts', () async {
      final tx = makeSampleTransaction();
      await db.insertTransactionWithQueue(tx);

      var queue = await db.getPendingQueue();
      final qId = queue.first['id'] as int;

      await db.markQueueItemFailed(qId, 'Network handshake timeout');
      queue = await db.getPendingQueue();
      expect(queue.first['status'], 'failed');
      expect(queue.first['attempts'], 1);
      expect(queue.first['error_message'], 'Network handshake timeout');

      // Second failure increments again
      await db.markQueueItemFailed(qId, '500 Internal Server Error');
      queue = await db.getPendingQueue();
      expect(queue.first['attempts'], 2);
      expect(queue.first['error_message'], '500 Internal Server Error');
    });
  });
}
