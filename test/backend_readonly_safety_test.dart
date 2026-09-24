import 'dart:convert';
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
import 'package:pickleball_app/services/paymongo_webhook_service.dart';
import 'package:pickleball_app/services/pos_database.dart';
import 'package:pickleball_app/services/pos_service.dart';
import 'package:pickleball_app/services/sync_service.dart';

/// Adversarial HttpOverrides implementation that records and aggressively blocks
/// any outbound HTTP socket or client instantiation during test execution.
class _StrictZeroEgressHttpOverrides extends HttpOverrides {
  int clientInstantiations = 0;
  final List<String> capturedCallSites = [];

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    clientInstantiations++;
    capturedCallSites.add(StackTrace.current.toString());
    throw StateError(
      'ADVERSARIAL SECURITY BREACH: Outbound HttpClient instantiated during read-only test! '
      'Stack trace: ${StackTrace.current}',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _StrictZeroEgressHttpOverrides egressInterceptor;
  late PosDatabase posDatabase;
  late BookingService bookingService;
  late PosService posService;
  late SyncService syncService;
  late ConnectivityService connectivityService;

  setUpAll(() async {
    // Populate fake credentials in dotenv to verify read-only guard takes absolute precedence
    try {
      dotenv.testLoad(fileInput: '''
PAYMONGO_SECRET_KEY=sk_test_mock_readonly_key_0123456789
PAYMONGO_PUBLIC_KEY=pk_test_mock_public_key_0123456789
PAYMONGO_WEBHOOK_SECRET=whsec_mock_readonly_webhook_secret_9876543210
SUPABASE_URL=https://mock-readonly-project.supabase.co
SUPABASE_ANON_KEY=mock-readonly-anon-jwt-token-for-testing
''');
    } catch (_) {}
  });

  setUp(() async {
    egressInterceptor = _StrictZeroEgressHttpOverrides();
    HttpOverrides.global = egressInterceptor;

    posDatabase = PosDatabase.instance;
    await posDatabase.initialize(forceMemory: true);
    await posDatabase.clearAll();

    bookingService = BookingService.instance;
    posService = PosService.instance;
    syncService = SyncService.instance;
    syncService.testPushHandler = null;

    connectivityService = ConnectivityService.instance;
    connectivityService.testOnlineOverride = true;

    MockData.resetToDefault();
    MockPosData.resetProducts();
  });

  tearDown(() async {
    HttpOverrides.global = null;
    await posDatabase.clearAll();
    syncService.testPushHandler = null;
    connectivityService.testOnlineOverride = null;
    PayMongoWebhookService.instance.clearProcessedEvents();
  });

  group('1. Requirement R4: Compile-Time Baseline Invariants', () {
    test('SupabaseConfig.enforceReadOnlyBackend is compile-time true', () {
      expect(SupabaseConfig.enforceReadOnlyBackend, isTrue,
          reason: 'Read-only backend policy flag must be permanently enabled.');
    });

    test('Environment credentials do not circumvent read-only enforcement', () {
      expect(PayMongoConfig.secretKey, isNotEmpty);
      expect(PayMongoConfig.publicKey, isNotEmpty);
      expect(SupabaseConfig.enforceReadOnlyBackend, isTrue);
    });
  });

  group('2. Requirement R4: Zero-Egress PayMongo Checkout Simulation Oracle', () {
    test('BookingService.createPayMongoCheckoutSession yields mock session with 0 network egress', () async {
      final futures = <Future<Map<String, dynamic>>>[];

      for (int i = 0; i < 30; i++) {
        futures.add(
          bookingService.createPayMongoCheckoutSession(
            courtId: 'court-pickleball-${i % 4 + 1}',
            courtName: 'Pickleball Court ${i % 4 + 1}',
            hourlyRate: 300.0,
            durationHours: 1 + (i % 3),
            guestName: 'Safe Player $i',
            guestEmail: 'player$i@court.ph',
            guestPhone: '+6391700000$i',
            paddleRental: i.isEven,
            ballThrowerRental: i % 3 == 0,
            totalAmount: 300.0 + (i * 20.0),
          ),
        );
      }

      final sessions = await Future.wait(futures);

      expect(sessions.length, equals(30));
      for (final s in sessions) {
        expect(s['sessionId'], isNotNull);
        final sessionId = s['sessionId'] as String;
        expect(sessionId.startsWith('mock_session_'), isTrue);
        expect(s['checkoutUrl'], isNotNull);
        final checkoutUrl = s['checkoutUrl'] as String;
        expect(checkoutUrl.contains('checkout.paymongo.com/mock_session_'), isTrue);
        expect(s['status'], equals('active'));
      }

      expect(egressInterceptor.clientInstantiations, equals(0),
          reason: 'Zero outbound HttpClient creations must occur across all checkout sessions.');
    });

    test('PosService.createPayMongoCheckoutSession yields simulated session with 0 network egress', () async {
      final futures = <Future<Map<String, dynamic>>>[];

      for (int i = 0; i < 30; i++) {
        futures.add(
          posService.createPayMongoCheckoutSession(
            totalAmount: 200.0 + (i * 15.0),
            items: [
              {'name': 'Pickleball Ball Pack', 'price': 150.0, 'quantity': 1},
              if (i.isOdd) {'name': 'Mineral Water', 'price': 50.0, 'quantity': 1},
            ],
            customerName: 'POS Patron $i',
            customerEmail: 'patron$i@pickleball.test',
          ),
        );
      }

      final sessions = await Future.wait(futures);

      expect(sessions.length, equals(30));
      for (final s in sessions) {
        expect(s['sessionId'], isNotNull);
        final sessionId = s['sessionId'] as String;
        expect(sessionId.startsWith('pos_cs_'), isTrue);
        expect(s['checkoutUrl'], isNotNull);
        final checkoutUrl = s['checkoutUrl'] as String;
        expect(checkoutUrl.contains('checkout.paymongo.com/mock_pos_'), isTrue);
        expect(s['status'], equals('active'));
        expect(s['isMock'], isTrue);
      }

      expect(egressInterceptor.clientInstantiations, equals(0),
          reason: 'Zero outbound HttpClient creations must occur across POS checkout requests.');
    });
  });

  group('3. Requirement R4: BookingService Local Mutation Concurrency & Stream Lifecycle', () {
    test('Concurrent createBooking calls execute exclusively in MockData with realtime events', () async {
      final baseDate = DateTime(2026, 12, 1, 6);
      final events = <BookingRealtimeEvent>[];
      final subscription = bookingService.bookingRealtimeEvents.listen(events.add);

      final futures = <Future<BookingModel>>[];
      for (int i = 0; i < 25; i++) {
        final start = baseDate.add(Duration(hours: i));
        final end = start.add(const Duration(hours: 1));
        futures.add(
          bookingService.createBooking(
            courtId: 'court-pickleball-1',
            startTime: start,
            endTime: end,
            totalAmount: 350.0,
            guestName: 'Concurrent Booker $i',
            guestEmail: 'booker$i@pickleball.test',
            guestPhone: '+6391800000$i',
          ),
        );
      }

      final createdBookings = await Future.wait(futures);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await subscription.cancel();

      expect(createdBookings.length, equals(25));
      for (final b in createdBookings) {
        expect(b.id, isNotEmpty);
        expect(b.status, equals('pending_payment'));
        // Verify in-memory presence in MockData
        expect(MockData.mockBookings.any((m) => m.id == b.id), isTrue);
      }

      expect(events.length, equals(25));
      expect(events.every((e) => e.type == BookingRealtimeEventType.inserted), isTrue);
      expect(egressInterceptor.clientInstantiations, equals(0));
    });

    test('Concurrent createBookingHold sets temporary hold and expiration in MockData', () async {
      final baseDate = DateTime(2026, 12, 2, 6);
      final futures = <Future<BookingModel>>[];

      for (int i = 0; i < 25; i++) {
        final start = baseDate.add(Duration(hours: i));
        final end = start.add(const Duration(hours: 1));
        futures.add(
          bookingService.createBookingHold(
            courtId: 'court-pickleball-2',
            startTime: start,
            endTime: end,
            totalAmount: 300.0,
            guestName: 'Hold Applicant $i',
            holdDurationMinutes: 5,
          ),
        );
      }

      final holds = await Future.wait(futures);
      expect(holds.length, equals(25));
      for (final h in holds) {
        expect(h.status, equals('pending_payment'));
        expect(h.expiresAt, isNotNull);
        expect(h.expiresAt!.isAfter(DateTime.now()), isTrue);
        expect(MockData.mockBookings.any((m) => m.id == h.id), isTrue);
      }
      expect(egressInterceptor.clientInstantiations, equals(0));
    });

    test('markBookingAsPaid transitions state to confirmed in MockData with zero remote writes', () async {
      // 1. Create booking
      final booking = await bookingService.createBooking(
        courtId: 'court-pickleball-1',
        startTime: DateTime(2026, 12, 3, 14),
        endTime: DateTime(2026, 12, 3, 15),
        totalAmount: 350.0,
        guestName: 'Pre-Pay Player',
      );
      expect(booking.status, equals('pending_payment'));

      final events = <BookingRealtimeEvent>[];
      final subscription = bookingService.bookingRealtimeEvents.listen(events.add);

      // 2. Mark as paid
      await bookingService.markBookingAsPaid(
        booking.id,
        paymongoSessionId: 'PAY-MOCK-SESSION-12345',
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await subscription.cancel();

      // Verify in-memory state updated
      final updated = MockData.mockBookings.firstWhere((b) => b.id == booking.id);
      expect(updated.status, equals('paid'));
      expect(updated.isPaid, isTrue);
      expect(updated.paymongoCheckoutSessionId, equals('PAY-MOCK-SESSION-12345'));

      // Realtime event emitted
      expect(events.any((e) => e.type == BookingRealtimeEventType.updated && e.booking?.id == booking.id), isTrue);
      expect(egressInterceptor.clientInstantiations, equals(0));
    });

    test('cancelBooking updates status to cancelled without remote writes', () async {
      final booking = await bookingService.createBooking(
        courtId: 'court-pickleball-3',
        startTime: DateTime(2026, 12, 4, 10),
        endTime: DateTime(2026, 12, 4, 11),
        totalAmount: 350.0,
        guestName: 'Cancel Candidate',
      );

      await bookingService.cancelBooking(booking);

      final cancelled = MockData.mockBookings.firstWhere((b) => b.id == booking.id);
      expect(cancelled.status, equals('cancelled'));
      expect(egressInterceptor.clientInstantiations, equals(0));
    });

    test('requestRefund generates mock refund record and cancels slot without remote writes', () async {
      final booking = await bookingService.createBooking(
        courtId: 'court-pickleball-4',
        startTime: DateTime(2026, 12, 5, 16),
        endTime: DateTime(2026, 12, 5, 17),
        totalAmount: 400.0,
        guestName: 'Refund Candidate',
      );

      final refund = await bookingService.requestRefund(
        bookingId: booking.id,
        amount: 400.0,
        walletType: 'gcash',
        accountName: 'Maria Santos',
        accountNumber: '09179876543',
        reason: 'Emergency cancellation',
      );

      expect(refund.id.startsWith('mock-ref-'), isTrue);
      expect(refund.bookingId, equals(booking.id));
      expect(refund.amount, equals(400.0));
      expect(refund.walletType, equals('gcash'));
      expect(refund.accountName, equals('Maria Santos'));

      final stored = MockData.mockBookings.firstWhere((b) => b.id == booking.id);
      expect(stored.status, equals('cancelled'));
      expect(egressInterceptor.clientInstantiations, equals(0));
    });
  });

  group('4. Requirement R4: PosService Local Mutations & SQLite Persistence', () {
    test('Concurrent createTransaction records in MockPosData and SQLite without remote writes', () async {
      final sampleProduct = MockPosData.getProducts().first;
      final initialStock = sampleProduct.stockLevel;

      final futures = <Future<PosTransactionModel>>[];
      for (int i = 0; i < 25; i++) {
        final breakdown = BirTaxBreakdown.compute(
          gross: sampleProduct.price,
          discountType: 'none',
        );

        final itemMap = {
          'product_id': sampleProduct.id,
          'product_name': sampleProduct.name,
          'quantity': 1,
          'price_at_time': sampleProduct.price,
        };

        futures.add(
          posService.createTransaction(
            cashierId: 'cashier-safe-01',
            cashierName: 'Juan Dela Cruz',
            customerName: 'Customer $i',
            customerTin: null,
            discountType: 'none',
            discountIdNumber: null,
            taxBreakdown: breakdown,
            paymentMethod: i.isEven ? 'Cash' : 'GCash',
            items: [itemMap],
          ),
        );
      }

      final transactions = await Future.wait(futures);

      expect(transactions.length, equals(25));
      for (final tx in transactions) {
        expect(tx.id, isNotEmpty);
        expect(tx.status, equals('completed'));
        // Verified in MockPosData
        expect(MockPosData.getTransactions().any((t) => t.id == tx.id), isTrue);
      }

      // Verify stock was decremented safely in local memory
      final updatedProduct = MockPosData.getProducts().firstWhere((p) => p.id == sampleProduct.id);
      expect(updatedProduct.stockLevel, equals(initialStock - 25));

      // Verify persisted to local SQLite database
      final sqliteTransactions = await posDatabase.getLocalTransactions();
      expect(sqliteTransactions.length, equals(25));

      expect(egressInterceptor.clientInstantiations, equals(0));
    });

    test('updateProductStock mutates in-memory catalog without remote PostgREST write', () async {
      final product = MockPosData.getProducts().first;
      final newStock = product.stockLevel + 15;

      final success = await posService.updateProductStock(product.id, newStock);
      expect(success, isTrue);

      final reloaded = MockPosData.getProducts().firstWhere((p) => p.id == product.id);
      expect(reloaded.stockLevel, equals(newStock));
      expect(egressInterceptor.clientInstantiations, equals(0));
    });

    test('createDailyExpense stores in MockPosData and computes totals locally', () async {
      final expenseModel = DailyExpenseModel(
        id: 'de-test-01',
        expenseDate: DateTime.now(),
        category: 'Supplies',
        title: 'Grip Tape & Overgrips Restock',
        amount: 850.0,
        receiptReference: 'RCP-8899',
        notes: 'Cashier supplies purchase',
        recordedBy: 'cashier-safe-01',
        createdAt: DateTime.now(),
      );

      final expense = await posService.createDailyExpense(expenseModel);

      expect(expense, isNotNull);
      expect(expense!.id, equals('de-test-01'));
      expect(expense.amount, equals(850.0));
      expect(expense.category, equals('Supplies'));

      final allExpenses = await posService.fetchDailyExpenses();
      expect(allExpenses.any((e) => e.id == expense.id), isTrue);
      expect(egressInterceptor.clientInstantiations, equals(0));
    });

    test('voidTransaction voids transaction and restores inventory stock locally', () async {
      final product = MockPosData.getProducts().first;
      final startStock = product.stockLevel;

      final tax = BirTaxBreakdown.compute(gross: product.price * 2, discountType: 'none');
      final itemMap = {
        'product_id': product.id,
        'product_name': product.name,
        'quantity': 2,
        'price_at_time': product.price,
      };

      final tx = await posService.createTransaction(
        cashierId: 'cashier-safe-01',
        cashierName: 'Juan Dela Cruz',
        customerName: 'Void Target Customer',
        customerTin: null,
        discountType: 'none',
        discountIdNumber: null,
        items: [itemMap],
        taxBreakdown: tax,
        paymentMethod: 'Cash',
      );

      expect(MockPosData.getProducts().firstWhere((p) => p.id == product.id).stockLevel,
          equals(startStock - 2));

      final voidSuccess = await posService.voidTransaction(
        transactionId: tx.id,
        voidReason: 'Customer cancelled at register',
        voidedBy: '00000000-0000-0000-0000-000000000001',
      );

      expect(voidSuccess, isTrue);

      final voidedTx = MockPosData.getTransactions().firstWhere((t) => t.id == tx.id);
      expect(voidedTx.status, equals('voided'));
      expect(voidedTx.voidReason, equals('Customer cancelled at register'));

      // Verify inventory returned
      expect(MockPosData.getProducts().firstWhere((p) => p.id == product.id).stockLevel,
          equals(startStock));

      expect(egressInterceptor.clientInstantiations, equals(0));
    });
  });

  group('5. Requirement R4: SyncService Local-Only Preservation', () {
    test('SyncService operations preserve local queue without remote PostgREST push', () async {
      final sampleProduct = MockPosData.getProducts().first;
      final item = PosTransactionItemModel(
        id: 'item-sync-01',
        transactionId: 'tx-sync-test-01',
        productId: sampleProduct.id,
        productName: sampleProduct.name,
        quantity: 1,
        priceAtTime: sampleProduct.price,
      );
      final tax = BirTaxBreakdown.compute(gross: sampleProduct.price, discountType: 'none');

      final tx = PosTransactionModel(
        id: 'tx-sync-test-01',
        invoiceNumber: 'SI-SYNC-001',
        cashierId: 'cashier-safe-01',
        cashierName: 'Sync Tester',
        items: [item],
        grossAmount: tax.grossSubtotal,
        discountAmount: tax.discountAmount,
        vatableSales: tax.vatableSales,
        vatAmount: tax.vatAmount,
        vatExemptSales: tax.vatExemptSales,
        totalAmount: tax.netPayable,
        paymentMethod: 'Cash',
        createdAt: DateTime.now(),
      );

      // Save order into SQLite sync queue
      await syncService.saveOrderAndPush(tx);

      // Verify order persisted in SQLite
      final pendingQueue = await posDatabase.getPendingQueue();
      expect(pendingQueue.any((q) => q['mutation_type'] == 'CREATE_TRANSACTION'), isTrue);

      // Trigger flushPendingQueue with online override
      await syncService.flushPendingQueue();

      // Read-only backend safely completes the queue without throwing or making HTTP calls
      expect(egressInterceptor.clientInstantiations, equals(0));
    });
  });

  group('6. Requirement R4: PayMongoWebhookService Read-Only DB Mutation Guard', () {
    test('Webhook processes confirmed state in MockData with 0 remote PostgREST writes', () async {
      // Create a mock pending booking
      final booking = await bookingService.createBooking(
        courtId: 'court-pickleball-1',
        startTime: DateTime(2026, 12, 10, 8),
        endTime: DateTime(2026, 12, 10, 9),
        totalAmount: 300.0,
        guestName: 'Webhook Recipient',
        guestEmail: 'webhook@pickleball.test',
      );
      expect(booking.status, equals('pending_payment'));

      final eventId = 'evt_test_mock_safe_${DateTime.now().millisecondsSinceEpoch}';
      final payload = jsonEncode({
        'data': {
          'id': eventId,
          'type': 'event',
          'attributes': {
            'type': 'payment.paid',
            'livemode': false,
            'data': {
              'id': 'pay_mock_safe_123',
              'type': 'payment',
              'attributes': {
                'amount': 30000, // ₱300.00 in centavos
                'status': 'paid',
                'description': 'Booking ${booking.id}',
                'metadata': {
                  'booking_id': booking.id,
                },
              },
            },
          },
        },
      });

      // Generate valid HMAC-SHA256 signature
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final signature = PayMongoWebhookService.computeHmacSha256Hex(
        key: PayMongoConfig.webhookSecretKey,
        data: '$timestamp.$payload',
      );
      final signatureHeader = 't=$timestamp,te=,li=$signature';

      final result = await PayMongoWebhookService.instance.processWebhookPayload(
        rawBody: payload,
        signatureHeader: signatureHeader,
      );

      expect(result.success, isTrue);
      expect(result.eventId, equals(eventId));
      expect(result.bookingId, equals(booking.id));
      expect(result.isDuplicate, isFalse);

      // Verify updated in MockData
      final updated = MockData.mockBookings.firstWhere((b) => b.id == booking.id);
      expect(updated.status, equals('confirmed'));

      // Verify zero outbound HTTP requests made
      expect(egressInterceptor.clientInstantiations, equals(0));

      // Replaying the exact same webhook event must be idempotent and duplicate-flagged
      final replayResult = await PayMongoWebhookService.instance.processWebhookPayload(
        rawBody: payload,
        signatureHeader: signatureHeader,
      );

      expect(replayResult.success, isTrue);
      expect(replayResult.isDuplicate, isTrue);
      expect(egressInterceptor.clientInstantiations, equals(0));
    });
  });

  group('7. Requirement R4: Heterogeneous Concurrency Stress Barrier', () {
    test('60 mixed operations execute concurrently with zero exceptions and zero HTTP egress', () async {
      final operations = <Future<dynamic>>[];

      for (int i = 0; i < 20; i++) {
        // 1. Checkout session simulation
        operations.add(
          bookingService.createPayMongoCheckoutSession(
            courtId: 'court-pickleball-1',
            courtName: 'Court 1',
            hourlyRate: 300.0,
            durationHours: 1,
            guestName: 'Chaos Player $i',
            guestEmail: 'chaos$i@test.com',
            guestPhone: '+6391700000$i',
            totalAmount: 300.0,
          ),
        );

        // 2. Booking creation
        operations.add(
          bookingService.createBooking(
            courtId: 'court-pickleball-2',
            startTime: DateTime(2026, 12, 20, 6 + (i % 14)),
            endTime: DateTime(2026, 12, 20, 7 + (i % 14)),
            totalAmount: 300.0,
            guestName: 'Chaos Booker $i',
          ),
        );

        // 3. POS Transaction creation
        final prod = MockPosData.getProducts()[i % MockPosData.getProducts().length];
        operations.add(
          posService.createTransaction(
            cashierId: 'cashier-chaos',
            cashierName: 'Chaos Cashier',
            customerName: 'Chaos Customer $i',
            customerTin: null,
            discountType: 'none',
            discountIdNumber: null,
            items: [
              {
                'product_id': prod.id,
                'product_name': prod.name,
                'quantity': 1,
                'price_at_time': prod.price,
              }
            ],
            taxBreakdown: BirTaxBreakdown.compute(gross: prod.price, discountType: 'none'),
            paymentMethod: 'Cash',
          ),
        );
      }

      expect(operations.length, equals(60));
      final results = await Future.wait(operations);
      expect(results.length, equals(60));

      // Assert complete absence of any outbound HTTP socket connection
      expect(egressInterceptor.clientInstantiations, equals(0),
          reason: 'Zero HTTP requests must be initiated across heterogeneous concurrent stress.');
    });
  });
}
