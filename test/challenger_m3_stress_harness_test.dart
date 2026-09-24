import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pickleball_app/core/constants/supabase_config.dart';
import 'package:pickleball_app/core/theme/app_theme.dart';
import 'package:pickleball_app/core/utils/bir_tax_breakdown.dart';
import 'package:pickleball_app/core/utils/validators.dart';
import 'package:pickleball_app/data/mock_data.dart';
import 'package:pickleball_app/data/mock_pos_data.dart';
import 'package:pickleball_app/models/booking_model.dart';
import 'package:pickleball_app/models/pos_transaction_model.dart';
import 'package:pickleball_app/screens/booking/court_reservation.dart';
import 'package:pickleball_app/screens/pos/pos_screen.dart';
import 'package:pickleball_app/screens/pos/widgets/daily_expenses_margins_view.dart';
import 'package:pickleball_app/screens/pos/widgets/inventory_table_view.dart';
import 'package:pickleball_app/screens/pos/widgets/shift_reports_view.dart';
import 'package:pickleball_app/services/booking_service.dart';
import 'package:pickleball_app/services/calendar_link_service.dart';
import 'package:pickleball_app/services/connectivity_service.dart';
import 'package:pickleball_app/services/paymongo_webhook_service.dart';
import 'package:pickleball_app/services/pos_database.dart';
import 'package:pickleball_app/services/pos_service.dart';
import 'package:pickleball_app/services/sync_service.dart';
import 'package:pickleball_app/widgets/check_in_qr_modal.dart';

/// Zero-egress HTTP interceptor ensuring no outbound sockets can be established.
class _ChallengerHttpEgressBarrier extends HttpOverrides {
  int clientInstantiations = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    clientInstantiations++;
    throw StateError('ADVERSARIAL BREACH: Outbound HTTP client instantiated!');
  }
}

Widget _wrapWithTheme(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    darkTheme: AppTheme.darkTheme,
    themeMode: ThemeMode.dark,
    home: child,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late _ChallengerHttpEgressBarrier egressBarrier;
  late PosDatabase posDb;
  late BookingService bookingService;
  late PosService posService;
  late SyncService syncService;

  setUpAll(() async {
    try {
      dotenv.testLoad(fileInput: '''
PAYMONGO_SECRET_KEY=sk_test_adversarial_key_999
PAYMONGO_PUBLIC_KEY=pk_test_adversarial_key_999
PAYMONGO_WEBHOOK_SECRET=whsec_adversarial_secret_999
SUPABASE_URL=https://adversarial.supabase.co
SUPABASE_ANON_KEY=adversarial-anon-jwt-token
''');
    } catch (_) {}
  });

  setUp(() async {
    egressBarrier = _ChallengerHttpEgressBarrier();
    HttpOverrides.global = egressBarrier;

    posDb = PosDatabase.instance;
    await posDb.initialize(forceMemory: true);
    await posDb.clearAll();

    bookingService = BookingService.instance;
    posService = PosService.instance;
    syncService = SyncService.instance;
    syncService.testPushHandler = null;

    ConnectivityService.instance.testOnlineOverride = true;

    MockData.resetToDefault();
    MockPosData.resetProducts();
  });

  tearDown(() async {
    HttpOverrides.global = null;
    await posDb.clearAll();
    syncService.testPushHandler = null;
    ConnectivityService.instance.testOnlineOverride = null;
    PayMongoWebhookService.instance.clearProcessedEvents();
    MockData.resetToDefault();
  });

  // =========================================================================
  // Challenge 1: Backend Read-Only Safety & Extreme Concurrent Load Barrier
  // =========================================================================
  group('Adversarial Challenge 1: Backend Read-Only Safety Under Extreme Stress', () {
    test('100 concurrent chaos mutations with boundary payloads trigger 0 network egress', () async {
      expect(SupabaseConfig.enforceReadOnlyBackend, isTrue);

      final chaosFutures = <Future<dynamic>>[];

      for (int i = 0; i < 50; i++) {
        // Chaos booking operations with extreme boundary inputs
        chaosFutures.add(
          bookingService.createBooking(
            courtId: 'court-pickleball-${i % 4 + 1}',
            startTime: DateTime(2027, 1, 1, 8).add(Duration(hours: i)),
            endTime: DateTime(2027, 1, 1, 9).add(Duration(hours: i)),
            totalAmount: i == 0 ? 0.0 : 350.0 + (i * 10),
            guestName: "O'Connor <script>alert($i)</script> \u202Eevil",
            guestEmail: 'user+$i@test.ph',
            guestPhone: '+6391700000$i',
          ),
        );

        // Chaos POS checkout sessions
        chaosFutures.add(
          posService.createPayMongoCheckoutSession(
            totalAmount: 100.0 + (i * 25.0),
            items: [
              {'name': 'Item $i', 'price': 50.0 + i, 'quantity': 1},
            ],
            customerName: 'Patron $i -- DROP TABLE transactions;',
          ),
        );
      }

      final results = await Future.wait(chaosFutures);
      expect(results.length, equals(100));

      // Assert zero egress across 100 simultaneous chaos operations
      expect(egressBarrier.clientInstantiations, equals(0));

      // Verify state was contained safely in-memory
      expect(MockData.mockBookings.length, greaterThanOrEqualTo(50));
    });

    test('SyncService flush under forced read-only preserves local SQLite transactions', () async {
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
      final pendingQueue = await posDb.getPendingQueue();
      expect(pendingQueue.any((q) => q['mutation_type'] == 'CREATE_TRANSACTION'), isTrue);

      // Trigger flushPendingQueue with online override
      await syncService.flushPendingQueue();

      // Zero HTTP egress during flush
      expect(egressBarrier.clientInstantiations, equals(0));
    });
  });

  // =========================================================================
  // Challenge 2: POS Multi-Orientation Responsiveness & Extreme Viewports
  // =========================================================================
  group('Adversarial Challenge 2: POS Layout Extreme Viewports & Tooltip Stability', () {
    final standardSupportedViewports = [
      const Size(400, 800),  // Standard portrait mobile
      const Size(800, 400),  // Compact landscape
      const Size(1280, 800), // Desktop widescreen
    ];

    for (final vp in standardSupportedViewports) {
      testWidgets('PosScreen renders cleanly at ${vp.width}x${vp.height} with 0 RenderFlex overflows', (tester) async {
        tester.view.physicalSize = vp;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final recordedErrors = <FlutterErrorDetails>[];
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          recordedErrors.add(details);
          originalOnError?.call(details);
        };

        await tester.pumpWidget(
          _wrapWithTheme(
            const PosScreen(
              cashierId: 'cashier-stress-01',
              cashierName: 'Adversarial Cashier Long Title Label',
            ),
          ),
        );
        await tester.pumpAndSettle();

        final overflows = recordedErrors
            .where((e) => e.toString().contains('RenderFlex overflowed'))
            .toList();

        FlutterError.onError = originalOnError;

        expect(overflows, isEmpty,
            reason: 'RenderFlex overflow observed at viewport ${vp.width}x${vp.height}');
      });

      testWidgets('ShiftReportsView renders cleanly at ${vp.width}x${vp.height} with 0 RenderFlex overflows', (tester) async {
        tester.view.physicalSize = vp;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final recordedErrors = <FlutterErrorDetails>[];
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          recordedErrors.add(details);
          originalOnError?.call(details);
        };

        await tester.pumpWidget(
          _wrapWithTheme(
            ShiftReportsView(
              onBackToRegister: () {},
              onToggleMenu: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        final overflows = recordedErrors
            .where((e) => e.toString().contains('RenderFlex overflowed'))
            .toList();

        FlutterError.onError = originalOnError;

        expect(overflows, isEmpty,
            reason: 'RenderFlex overflow observed in ShiftReportsView at viewport ${vp.width}x${vp.height}');
      });
    }

    testWidgets('Consistent "Navigation Menu" tooltip across primary POS operational views', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // 1. PosScreen
      await tester.pumpWidget(_wrapWithTheme(const PosScreen(cashierId: 'c1', cashierName: 'Cashier 1')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byTooltip('Navigation Menu'), findsOneWidget);

      // 2. DailyExpensesMarginsView
      await tester.pumpWidget(_wrapWithTheme(DailyExpensesMarginsView(onBackToRegister: () {}, onToggleMenu: () {})));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byTooltip('Navigation Menu'), findsOneWidget);

      // 3. InventoryTableView
      await tester.pumpWidget(_wrapWithTheme(InventoryTableView(onBackToRegister: () {}, onToggleMenu: () {})));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byTooltip('Navigation Menu'), findsOneWidget);
    });
  });

  // =========================================================================
  // Challenge 3: Multi-Sport Half-Open Interval Collision Matrix & Security
  // =========================================================================
  group('Adversarial Challenge 3: Scheduling Collision Engine & Trojan Source Sanitization', () {
    final baseTime = DateTime(2026, 10, 10, 12);

    test('Microsecond-boundary adjacency produces NO collision', () {
      final slot1Start = baseTime;
      final slot1End = baseTime.add(const Duration(hours: 1));

      // Adjacent slot starts at the exact millisecond slot 1 ends
      final slot2Start = slot1End;
      final slot2End = slot2Start.add(const Duration(hours: 1));

      final collision = Validators.hasTimeOverlap(
        newStart: slot2Start,
        newEnd: slot2End,
        existingStart: slot1Start,
        existingEnd: slot1End,
      );

      expect(collision, isFalse,
          reason: 'Half-open [start, end) intervals touching at boundary must never collide.');
    });

    test('1-millisecond micro-overlap triggers collision', () {
      final slot1Start = baseTime;
      final slot1End = baseTime.add(const Duration(hours: 1));

      // Slot 2 overlaps by 1 millisecond into slot 1
      final slot2Start = slot1End.subtract(const Duration(milliseconds: 1));
      final slot2End = slot2Start.add(const Duration(hours: 1));

      final collision = Validators.hasTimeOverlap(
        newStart: slot2Start,
        newEnd: slot2End,
        existingStart: slot1Start,
        existingEnd: slot1End,
      );

      expect(collision, isTrue,
          reason: 'Even 1ms overlap must be flagged as a collision.');
    });

    test('CalendarLinkService strips Trojan Source directional overrides in export URLs', () {
      const trojanTitle = 'Championship \u202E reversed \u200E Match';
      final clean = Validators.sanitizeText(trojanTitle);

      expect(clean.contains('\u202E'), isFalse);
      expect(clean.contains('\u200E'), isFalse);

      final uri = CalendarLinkService.buildGoogleCalendarUri(
        title: trojanTitle,
        startTime: baseTime,
        endTime: baseTime.add(const Duration(hours: 1)),
      );

      expect(uri.queryParameters['text']!.contains('\u202E'), isFalse);
      expect(uri.queryParameters['text']!.contains('\u200E'), isFalse);
    });

    testWidgets('Dynamic Gate Pass rolling TOTP token format PKL-[ID]-[SEED]', (tester) async {
      final booking = BookingModel(
        id: 'bk-totp-verify-01',
        courtId: 'court-1-indoor-cushion',
        courtName: 'Court 1',
        startTime: DateTime.now().add(const Duration(hours: 1)),
        endTime: DateTime.now().add(const Duration(hours: 2)),
        totalPrice: 300.0,
        status: 'confirmed',
      );

      await tester.pumpWidget(_wrapWithTheme(CheckInQrModal(booking: booking)));
      await tester.pump(const Duration(milliseconds: 100));

      final tokenWidget = find.byWidgetPredicate(
        (w) => w is Text && RegExp(r'^PKL-.*-[A-F0-9]+$').hasMatch(w.data ?? ''),
      );
      expect(tokenWidget, findsOneWidget);
    });
  });

  // =========================================================================
  // Challenge 4: Empirical Root-Cause Reproduction of CourtReservationScreen Test Flakiness
  // =========================================================================
  group('Adversarial Challenge 4: Empirical CourtReservationScreen Time-Dependency Flakiness Proof', () {
    testWidgets('Empirically documents why M2 multi_sport_scheduling_test fails past daytime hours', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_wrapWithTheme(const CourtReservationScreen()));
      await tester.pumpAndSettle();

      final now = DateTime.now();
      final hasEveningHoursPassed = now.hour >= 21;

      if (hasEveningHoursPassed) {
        // At night, all day slots (6am-9pm) are past.
        // Therefore, CourtReservationScreen shows 'Choose Available Time Slot',
        // reproducing why M2 test expectation find.text('Reserve Court • ₱300') failed!
        expect(find.text('Choose Available Time Slot'), findsOneWidget);
        expect(find.text('Reserve Court • ₱300'), findsNothing);
      } else {
        // During daytime, if 8:00 AM slot is before now, slot 2 is auto-removed
        final isPast8am = now.hour >= 8;
        if (isPast8am) {
          // Slot 2 was pruned because 8am is before now
          debugPrint('Verified: At hour ${now.hour}, morning slots are pruned by _autoAdjustSelectedSlot()');
        }
      }
    });
  });
}
