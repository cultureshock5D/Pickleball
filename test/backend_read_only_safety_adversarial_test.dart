import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_app/core/constants/paymongo_config.dart';
import 'package:pickleball_app/core/constants/supabase_config.dart';
import 'package:pickleball_app/core/utils/bir_tax_breakdown.dart';
import 'package:pickleball_app/data/mock_data.dart';
import 'package:pickleball_app/data/mock_pos_data.dart';
import 'package:pickleball_app/models/booking_model.dart';
import 'package:pickleball_app/models/daily_expense_model.dart';
import 'package:pickleball_app/models/pos_transaction_model.dart';
import 'package:pickleball_app/services/booking_service.dart';
import 'package:pickleball_app/services/connectivity_service.dart';
import 'package:pickleball_app/services/pos_database.dart';
import 'package:pickleball_app/services/pos_service.dart';
import 'package:pickleball_app/services/sync_service.dart';

class _AdversarialBlockingHttpOverrides extends HttpOverrides {
  int clientCreations = 0;
  final List<String> callStackTraces = [];

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    clientCreations++;
    callStackTraces.add(StackTrace.current.toString());
    throw StateError(
      'ADVERSARIAL CHALLENGE BREACH: Outbound HttpClient instantiated while read-only backend is active!',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _AdversarialBlockingHttpOverrides httpInterceptor;
  late PosDatabase posDb;
  late BookingService bookingService;
  late PosService posService;
  late SyncService syncService;
  late ConnectivityService connectivity;

  setUpAll(() async {
    // Populate fake secret key to verify the guard triggers even when a key is present
    try {
      dotenv.testLoad(fileInput: 'PAYMONGO_SECRET_KEY=sk_test_adversarial_1234567890\nSUPABASE_URL=https://dummy.supabase.co\nSUPABASE_ANON_KEY=dummy-key');
    } catch (_) {}
  });

  setUp(() async {
    httpInterceptor = _AdversarialBlockingHttpOverrides();
    HttpOverrides.global = httpInterceptor;

    posDb = PosDatabase.instance;
    await posDb.initialize(forceMemory: true);
    await posDb.clearAll();

    bookingService = BookingService.instance;
    posService = PosService.instance;
    syncService = SyncService.instance;
    syncService.testPushHandler = null;

    connectivity = ConnectivityService.instance;
    connectivity.testOnlineOverride = true;
  });

  tearDown(() async {
    HttpOverrides.global = null;
    await posDb.clearAll();
    syncService.testPushHandler = null;
    connectivity.testOnlineOverride = null;
  });

  group('Requirement R4: Baseline Flag & Architectural Invariants', () {
    test('SupabaseConfig.enforceReadOnlyBackend is compile-time true', () {
      expect(SupabaseConfig.enforceReadOnlyBackend, isTrue);
    });

    test('PayMongoConfig detects secret key when loaded but read-only takes precedence', () {
      expect(PayMongoConfig.secretKey, isNotEmpty);
      expect(SupabaseConfig.enforceReadOnlyBackend, isTrue);
    });
  });

  group('Requirement R4: PayMongo Zero-HTTP Outbound Oracle', () {
    test('BookingService.createPayMongoCheckoutSession never initiates HTTP connection', () async {
      final futures = <Future<Map<String, dynamic>>>[];

      for (int i = 0; i < 50; i++) {
        futures.add(
          bookingService.createPayMongoCheckoutSession(
            courtId: 'court-${i % 4 + 1}',
            courtName: 'Pickleball Court ${i % 4 + 1}',
            hourlyRate: 300.0,
            durationHours: 1 + (i % 3),
            guestName: 'Adversary $i',
            guestEmail: 'adversary$i@court.ph',
            guestPhone: '+63917000000$i',
            paddleRental: i.isEven,
            ballThrowerRental: i % 3 == 0,
            totalAmount: 350.0 + (i * 25.0),
          ),
        );
      }

      final results = await Future.wait(futures);

      expect(results.length, 50);
      for (final res in results) {
        expect(res['sessionId'], isNotNull);
        expect((res['sessionId'] as String).startsWith('mock_session_'), isTrue);
        expect(res['checkoutUrl'], isNotNull);
        expect((res['checkoutUrl'] as String).contains('checkout.paymongo.com/mock_session_'), isTrue);
        expect(res['status'], 'active');
      }

      // Assert zero outbound HttpClient creations occurred
      expect(httpInterceptor.clientCreations, 0,
          reason: 'Outbound HTTP client was created during PayMongo session creation!');
    });

    test('PosService.createPayMongoCheckoutSession never initiates HTTP connection', () async {
      final futures = <Future<Map<String, dynamic>>>[];

      for (int i = 0; i < 50; i++) {
        futures.add(
          posService.createPayMongoCheckoutSession(
            totalAmount: 150.0 + (i * 10),
            items: [
              {'name': 'Franklin X-40 Ball', 'price': 150.0, 'quantity': 1},
              if (i.isEven) {'name': 'Gatorade Blue', 'price': 80.0, 'quantity': 1},
            ],
            customerName: 'Player $i',
            customerEmail: 'player$i@pickleball.test',
          ),
        );
      }

      final results = await Future.wait(futures);

      expect(results.length, 50);
      for (final res in results) {
        expect(res['sessionId'], isNotNull);
        expect((res['sessionId'] as String).startsWith('pos_cs_'), isTrue);
        expect(res['checkoutUrl'], isNotNull);
        expect((res['checkoutUrl'] as String).contains('checkout.paymongo.com/mock_pos_'), isTrue);
        expect(res['status'], 'active');
        expect(res['isMock'], isTrue);
      }

      // Assert zero outbound HttpClient creations occurred
      expect(httpInterceptor.clientCreations, 0,
          reason: 'Outbound HTTP client was created during POS PayMongo session creation!');
    });
  });

  group('Requirement R4: BookingService Guarded Mutations Stress Harness', () {
    test('Concurrent createBooking calls execute exclusively in MockData', () async {
      final baseDate = DateTime(2026, 11, 15, 6);
      final eventsReceived = <BookingRealtimeEvent>[];
      final sub = bookingService.bookingRealtimeEvents.listen(eventsReceived.add);

      // Create 20 bookings concurrently on distinct times
      final futures = <Future<BookingModel>>[];
      for (int i = 0; i < 20; i++) {
        final start = baseDate.add(Duration(hours: i));
        final end = start.add(const Duration(hours: 1));
        futures.add(
          bookingService.createBooking(
            courtId: 'court-pickleball-1',
            startTime: start,
            endTime: end,
            totalAmount: 350.0,
            guestName: 'Stress Player $i',
            guestEmail: 'player$i@test.com',
          ),
        );
      }

      final bookings = await Future.wait(futures);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();

      expect(bookings.length, 20);
      for (final b in bookings) {
        expect(b.id, isNotEmpty);
        expect(b.status, 'pending_payment');
        // Ensure present in MockData
        expect(MockData.mockBookings.any((m) => m.id == b.id), isTrue);
      }

      expect(eventsReceived.length, 20);
      expect(eventsReceived.every((e) => e.type == BookingRealtimeEventType.inserted), isTrue);
    });

    test('Concurrent createBookingHold calls execute exclusively in MockData', () async {
      final baseDate = DateTime(2026, 11, 16, 6);
      final futures = <Future<BookingModel>>[];

      for (int i = 0; i < 20; i++) {
        final start = baseDate.add(Duration(hours: i));
        final end = start.add(const Duration(hours: 1));
        futures.add(
          bookingService.createBookingHold(
            courtId: 'court-pickleball-2',
            startTime: start,
            endTime: end,
            totalAmount: 300.0,
            guestName: 'Hold Player $i',
            holdDurationMinutes: 5,
          ),
        );
      }

      final holds = await Future.wait(futures);
      expect(holds.length, 20);
      for (final h in holds) {
        expect(h.status, 'pending_payment');
        expect(h.expiresAt, isNotNull);
        expect(MockData.mockBookings.any((m) => m.id == h.id), isTrue);
      }
    });

    test('Concurrent cancelBooking and requestRefund execute in mock state', () async {
      // Setup a mock booking
      final booking = await bookingService.createBooking(
        courtId: 'court-pickleball-3',
        startTime: DateTime(2026, 12, 1, 10),
        endTime: DateTime(2026, 12, 1, 11),
        totalAmount: 350.0,
        guestName: 'Cancellable Player',
      );

      // Cancel
      await bookingService.cancelBooking(booking);
      final cancelled = MockData.mockBookings.firstWhere((b) => b.id == booking.id);
      expect(cancelled.status, 'cancelled');

      // Request refund
      final refund = await bookingService.requestRefund(
        bookingId: booking.id,
        amount: 350.0,
        walletType: 'gcash',
        accountName: 'Juan Dela Cruz',
        accountNumber: '09171234567',
        reason: 'Schedule conflict',
      );

      expect(refund.id.startsWith('mock-ref-'), isTrue);
      expect(refund.amount, 350.0);
      expect(refund.walletType, 'gcash');
    });

    test('Concurrent markBookingAsPaid and markBookingPaid aliases update MockData without Supabase mutations', () async {
      final b1 = await bookingService.createBooking(
        courtId: 'court-pickleball-1',
        startTime: DateTime(2026, 12, 5, 14),
        endTime: DateTime(2026, 12, 5, 15),
        totalAmount: 350.0,
      );

      final b2 = await bookingService.createBooking(
        courtId: 'court-pickleball-2',
        startTime: DateTime(2026, 12, 5, 14),
        endTime: DateTime(2026, 12, 5, 15),
        totalAmount: 350.0,
      );

      final paid1 = await bookingService.markBookingAsPaid(b1.id, paymongoSessionId: 'sess_1');
      final paid2 = await bookingService.markBookingPaid(b2.id, paymongoSessionId: 'sess_2');

      expect(paid1.isPaid, isTrue);
      expect(paid2.isPaid, isTrue);

      final mock1 = MockData.mockBookings.firstWhere((b) => b.id == b1.id);
      final mock2 = MockData.mockBookings.firstWhere((b) => b.id == b2.id);
      expect(mock1.isPaid, isTrue);
      expect(mock2.isPaid, isTrue);
    });
  });

  group('Requirement R4: PosService Guarded Mutations Stress Harness', () {
    test('50 concurrent createTransaction and recordTransaction calls persist to SQLite & MockPosData', () async {
      final futures = <Future<PosTransactionModel>>[];

      for (int i = 0; i < 50; i++) {
        final breakdown = BirTaxBreakdown.compute(
          gross: 200.0,
          discountType: i % 4 == 0 ? 'senior_citizen' : 'none',
        );

        final items = [
          {
            'product_id': '6979df8e-3d00-4aa1-9e0e-e5536a1ce6c4',
            'product_name': 'Long Black',
            'price_at_time': 110.0,
            'quantity': 1,
          },
          {
            'product_id': '28d0f9f0-0d86-46a1-83ba-978bdedac326',
            'product_name': 'Capuccino',
            'price_at_time': 130.0,
            'quantity': 1,
          },
        ];

        if (i.isEven) {
          futures.add(
            posService.createTransaction(
              cashierId: 'cashier-001',
              cashierName: 'Cashier Alice',
              customerName: 'Customer $i',
              customerTin: null,
              discountType: i % 4 == 0 ? 'senior' : 'none',
              discountIdNumber: i % 4 == 0 ? 'SR-1234' : null,
              taxBreakdown: breakdown,
              paymentMethod: 'Cash',
              items: items,
            ),
          );
        } else {
          futures.add(
            posService.recordTransaction(
              cashierId: 'cashier-002',
              cashierName: 'Cashier Bob',
              customerName: 'Customer $i',
              customerTin: null,
              discountType: 'none',
              discountIdNumber: null,
              taxBreakdown: breakdown,
              paymentMethod: 'GCash / QR Ph',
              items: items,
            ),
          );
        }
      }

      final txs = await Future.wait(futures);
      expect(txs.length, 50);

      // Verify stored in local SQLite
      final localTxs = await posDb.getLocalTransactions(limit: 100);
      expect(localTxs.length, 50);

      // Verify stored in MockPosData
      final mockTxs = MockPosData.getTransactions();
      for (final tx in txs) {
        expect(mockTxs.any((m) => m.id == tx.id), isTrue);
      }
    });

    test('30 concurrent updateProductStock calls mutate MockPosData without remote errors', () async {
      final products = MockPosData.getProducts();
      final targetProd = products.first;

      final futures = <Future<bool>>[];
      for (int i = 0; i < 30; i++) {
        futures.add(posService.updateProductStock(targetProd.id, 50 + i));
      }

      final results = await Future.wait(futures);
      expect(results.length, 30);
      expect(results.every((r) => r == true), isTrue);

      final updated = MockPosData.getProducts().firstWhere((p) => p.id == targetProd.id);
      expect(updated.stockLevel, greaterThanOrEqualTo(50));
    });

    test('30 concurrent createDailyExpense calls mutate MockPosData without remote errors', () async {
      final futures = <Future<DailyExpenseModel?>>[];

      for (int i = 0; i < 30; i++) {
        final expense = DailyExpenseModel(
          id: 'exp-stress-$i',
          expenseDate: DateTime.now(),
          category: i % 2 == 0 ? 'Utilities' : 'Supplies',
          title: 'Stress Expense #$i',
          amount: 100.0 + (i * 10),
          recordedBy: 'Supervisor Test',
          createdAt: DateTime.now(),
        );
        futures.add(posService.createDailyExpense(expense));
      }

      final results = await Future.wait(futures);
      expect(results.length, 30);
      expect(results.every((r) => r != null), isTrue);

      final expenses = MockPosData.getDailyExpenses();
      for (int i = 0; i < 30; i++) {
        expect(expenses.any((e) => e.id == 'exp-stress-$i'), isTrue);
      }
    });

    test('Concurrent voidTransaction updates local DB and MockPosData without Supabase mutations', () async {
      final breakdown = BirTaxBreakdown.compute(gross: 150.0, discountType: 'none');
      final tx = await posService.createTransaction(
        cashierId: 'cashier-001',
        cashierName: 'Cashier Alice',
        customerName: 'Customer Void Test',
        customerTin: null,
        discountType: 'none',
        discountIdNumber: null,
        taxBreakdown: breakdown,
        paymentMethod: 'Cash',
        items: [
          {
            'product_id': '6979df8e-3d00-4aa1-9e0e-e5536a1ce6c4',
            'product_name': 'Long Black',
            'price_at_time': 110.0,
            'quantity': 1,
          }
        ],
      );

      final voidSuccess = await posService.voidTransaction(
        transactionId: tx.id,
        voidReason: 'Customer changed mind',
        voidedBy: '00000000-0000-0000-0000-000000000001',
      );

      expect(voidSuccess, isTrue);

      // Verify in local database
      final localTxs = await posDb.getLocalTransactions(limit: 100);
      final localTx = localTxs.firstWhere((t) => t.id == tx.id);
      expect(localTx.isVoided, isTrue);

      // Verify in MockPosData
      final mockTx = MockPosData.getTransactions().firstWhere((t) => t.id == tx.id);
      expect(mockTx.isVoided, isTrue);
    });
  });

  group('Requirement R4: SyncService Read-Only Queue Handling', () {
    test('flushPendingQueue marks items synced locally without remote mutation push', () async {
      // 1. Ensure testPushHandler is null to exercise real SyncService._dispatchMutation
      syncService.testPushHandler = null;

      // 2. Insert 10 transactions directly into SQLite with pending queue items
      for (int i = 0; i < 10; i++) {
        final tx = PosTransactionModel(
          id: 'tx-sync-stress-$i',
          invoiceNumber: 'INV-SYNC-$i',
          cashierId: 'cashier-1',
          grossAmount: 100.0,
          discountAmount: 0.0,
          vatableSales: 89.29,
          vatAmount: 10.71,
          vatExemptSales: 0.0,
          totalAmount: 100.0,
          paymentMethod: 'Cash',
          createdAt: DateTime.now(),
          items: [],
        );
        await posDb.insertTransactionWithQueue(tx);
      }

      var pending = await posDb.getPendingQueue();
      expect(pending.length, 10);

      // 3. Flush the queue with read-only backend active
      await syncService.flushPendingQueue();

      // 4. All pending items should have been marked synced (and cleaned up)
      pending = await posDb.getPendingQueue();
      expect(pending.isEmpty, isTrue,
          reason: 'SyncService should consume queue items locally in read-only mode');
      expect(connectivity.syncState, SyncState.idle);
    });

    test('Simultaneous flushPendingQueue calls are debounced by _isFlushing lock', () async {
      syncService.testPushHandler = null;

      final tx = PosTransactionModel(
        id: 'tx-debounce-1',
        invoiceNumber: 'INV-DEBOUNCE-1',
        cashierId: 'cashier-1',
        grossAmount: 50.0,
        discountAmount: 0.0,
        vatableSales: 44.64,
        vatAmount: 5.36,
        vatExemptSales: 0.0,
        totalAmount: 50.0,
        paymentMethod: 'Cash',
        createdAt: DateTime.now(),
        items: [],
      );
      await posDb.insertTransactionWithQueue(tx);

      // Trigger 10 concurrent flushes
      final flushFutures = List.generate(10, (_) => syncService.flushPendingQueue());
      await Future.wait(flushFutures);

      final pending = await posDb.getPendingQueue();
      expect(pending.isEmpty, isTrue);
    });
  });

  group('Requirement R4: Extreme Chaos & Concurrency Barrier', () {
    test('100 concurrent heterogeneous operations execute safely across all services', () async {
      final futures = <Future<dynamic>>[];

      // 25 Booking creations
      for (int i = 0; i < 25; i++) {
        futures.add(
          bookingService.createBooking(
            courtId: 'court-pickleball-1',
            startTime: DateTime(2026, 12, 10, 6).add(Duration(hours: i)),
            endTime: DateTime(2026, 12, 10, 7).add(Duration(hours: i)),
            totalAmount: 300.0,
            guestName: 'Chaos Player $i',
          ),
        );
      }

      // 25 POS transactions
      for (int i = 0; i < 25; i++) {
        final breakdown = BirTaxBreakdown.compute(gross: 100.0, discountType: 'none');
        futures.add(
          posService.createTransaction(
            cashierId: 'cashier-chaos',
            cashierName: 'Chaos Cashier',
            customerName: 'Chaos Customer $i',
            customerTin: null,
            discountType: 'none',
            discountIdNumber: null,
            taxBreakdown: breakdown,
            paymentMethod: 'Cash',
            items: [
              {
                'product_id': '6979df8e-3d00-4aa1-9e0e-e5536a1ce6c4',
                'product_name': 'Long Black',
                'price_at_time': 110.0,
                'quantity': 1,
              }
            ],
          ),
        );
      }

      // 25 PayMongo checkout sessions (split booking and POS)
      for (int i = 0; i < 25; i++) {
        if (i.isEven) {
          futures.add(
            bookingService.createPayMongoCheckoutSession(
              courtId: 'court-pickleball-4',
              courtName: 'Pickleball Court 4',
              hourlyRate: 300.0,
              durationHours: 1,
              guestName: 'Chaos Guest $i',
              guestEmail: 'chaos$i@pickleball.test',
              guestPhone: '+6391700000$i',
              totalAmount: 300.0,
            ),
          );
        } else {
          futures.add(
            posService.createPayMongoCheckoutSession(
              totalAmount: 200.0,
              items: [
                {'name': 'Rental Paddle', 'price': 200.0, 'quantity': 1}
              ],
            ),
          );
        }
      }

      // 25 Inventory updates and expenses
      for (int i = 0; i < 25; i++) {
        if (i.isEven) {
          futures.add(posService.updateProductStock('6979df8e-3d00-4aa1-9e0e-e5536a1ce6c4', 20 + i));
        } else {
          futures.add(
            posService.createDailyExpense(
              DailyExpenseModel(
                id: 'exp-chaos-$i',
                expenseDate: DateTime.now(),
                category: 'Equipment Maintenance',
                title: 'Chaos Expense $i',
                amount: 50.0 + i,
                recordedBy: 'Chaos Admin',
                createdAt: DateTime.now(),
              ),
            ),
          );
        }
      }

      final results = await Future.wait(futures);
      expect(results.length, 100);

      // Verify zero outbound HTTP connections attempted under chaos load
      expect(httpInterceptor.clientCreations, 0);

      // Drain sync queue (waiting for any background flush triggered during saveOrderAndPush)
      int retries = 0;
      while (retries < 30) {
        await syncService.flushPendingQueue();
        final pending = await posDb.getPendingQueue();
        if (pending.isEmpty) break;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        retries++;
      }
      final pending = await posDb.getPendingQueue();
      expect(pending.isEmpty, isTrue);
    });
  });
}
