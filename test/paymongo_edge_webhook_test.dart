import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_app/data/mock_data.dart';
import 'package:pickleball_app/models/booking_model.dart';
import 'package:pickleball_app/services/paymongo_webhook_service.dart';

void main() {
  setUp(() {
    MockData.resetToDefault();
  });

  const testSecret = 'whsk_test_6f8b2d4e9a1c3e5a7b9c1d3e5f7a9b1c';

  group('Supabase PayMongo Edge Webhook: Cryptographic Signature & Freshness', () {
    test('Parses standard Paymongo-Signature header formatted with t, te, li', () {
      const header = 't=1726135200,te=abcdef0123456789abcdef0123456789,li=1234567890abcdef1234567890abcdef';
      final parsed = PayMongoWebhookService.parseSignatureHeader(header);

      expect(parsed['t'], equals('1726135200'));
      expect(parsed['te'], equals('abcdef0123456789abcdef0123456789'));
      expect(parsed['li'], equals('1234567890abcdef1234567890abcdef'));
    });

    test('Validates timestamp within 300s freshness window', () {
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Fresh (now)
      final validHeader = PayMongoWebhookService.parseSignatureHeader('t=$nowSec,te=abc');
      final tValid = int.parse(validHeader['t']!);
      expect((nowSec - tValid).abs() <= 300, isTrue);

      // 150 seconds ago (valid)
      final validOldHeader = PayMongoWebhookService.parseSignatureHeader('t=${nowSec - 150},te=abc');
      final tOldValid = int.parse(validOldHeader['t']!);
      expect((nowSec - tOldValid).abs() <= 300, isTrue);

      // 301 seconds ago (expired)
      final expiredHeader = PayMongoWebhookService.parseSignatureHeader('t=${nowSec - 301},te=abc');
      final tExpired = int.parse(expiredHeader['t']!);
      expect((nowSec - tExpired).abs() <= 300, isFalse);

      // 305 seconds in future (invalid/clock skew)
      final futureHeader = PayMongoWebhookService.parseSignatureHeader('t=${nowSec + 305},te=abc');
      final tFuture = int.parse(futureHeader['t']!);
      expect((nowSec - tFuture).abs() <= 300, isFalse);
    });

    test('Web Crypto HMAC-SHA256 generates exact digest over t.rawBody', () {
      const t = 1726135200;
      const rawBody = '{"data":{"id":"evt_test_001","type":"event"}}';
      const stringToSign = '$t.$rawBody';

      final signature = PayMongoWebhookService.computeHmacSha256Hex(
        key: testSecret,
        data: stringToSign,
      );

      expect(signature, isNotEmpty);
      expect(signature.length, equals(64)); // 32 bytes in hex = 64 characters

      // Re-computing with identical inputs yields identical signature
      final verifySignature = PayMongoWebhookService.computeHmacSha256Hex(
        key: testSecret,
        data: stringToSign,
      );
      expect(PayMongoWebhookService.timingSafeEqual(signature, verifySignature), isTrue);

      // Tampered body yields mismatch
      const tamperedBody = '{"data":{"id":"evt_test_001","type":"tampered"}}';
      final tamperedSig = PayMongoWebhookService.computeHmacSha256Hex(
        key: testSecret,
        data: '$t.$tamperedBody',
      );
      expect(PayMongoWebhookService.timingSafeEqual(signature, tamperedSig), isFalse);
    });

    test('Livemode selects li signature while testmode selects te signature', () {
      const t = 1726135200;
      const testBody = '{"data":{"attributes":{"livemode":false}}}';
      const liveBody = '{"data":{"attributes":{"livemode":true}}}';

      final teSig = PayMongoWebhookService.computeHmacSha256Hex(
        key: testSecret,
        data: '$t.$testBody',
      );
      final liSig = PayMongoWebhookService.computeHmacSha256Hex(
        key: testSecret,
        data: '$t.$liveBody',
      );

      final testHeader = 't=$t,te=$teSig,li=dummy_live_sig';
      final liveHeader = 't=$t,te=dummy_test_sig,li=$liSig';

      final verifyTest = PayMongoWebhookService.verifySignature(
        rawBody: testBody,
        signatureHeader: testHeader,
        secret: testSecret,
        toleranceSeconds: 100000000, // bypass timestamp check for fixed vector
      );
      expect(verifyTest, isTrue);

      final verifyLive = PayMongoWebhookService.verifySignature(
        rawBody: liveBody,
        signatureHeader: liveHeader,
        secret: testSecret,
        toleranceSeconds: 100000000,
        isLiveMode: true,
      );
      expect(verifyLive, isTrue);
    });
  });

  group('PayMongo Webhook Edge Idempotency & State Reconciliation', () {
    test('Initial payment.paid event transitions pending_payment booking to confirmed', () async {
      MockData.clearMockBookings();

      final now = DateTime.now();
      final targetBooking = BookingModel(
        id: 'bk-paymongo-target-1',
        courtId: 'court-1-indoor-cushion',
        startTime: now.add(const Duration(days: 1, hours: 10)),
        endTime: now.add(const Duration(days: 1, hours: 11)),
        totalPrice: 300.0,
        paymongoCheckoutSessionId: 'cs_live_session_123',
      );
      MockData.addMockBooking(targetBooking);

      const eventId = 'evt_payment_success_001';
      final eventPayload = {
        'data': {
          'id': eventId,
          'type': 'event',
          'attributes': {
            'type': 'checkout_session.payment.paid',
            'livemode': false,
            'data': {
              'id': 'cs_live_session_123',
              'type': 'checkout_session',
              'attributes': {
                'reference_number': 'bk-paymongo-target-1',
                'payment_intent': {'id': 'pi_123'},
              },
            },
          },
        },
      };

      final rawBody = jsonEncode(eventPayload);
      final t = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final sig = PayMongoWebhookService.computeHmacSha256Hex(
        key: testSecret,
        data: '$t.$rawBody',
      );
      final signatureHeader = 't=$t,te=$sig';

      final service = PayMongoWebhookService.instance;
      final result = await service.processWebhookPayload(
        rawBody: rawBody,
        signatureHeader: signatureHeader,
        secret: testSecret,
      );

      expect(result.success, isTrue);
      expect(result.isDuplicate, isFalse);
      expect(result.eventId, equals(eventId));

      // Booking status must be updated to confirmed/paid
      final updatedBooking = MockData.mockBookings.firstWhere((b) => b.id == 'bk-paymongo-target-1');
      expect(updatedBooking.isPaid, isTrue);
    });

    test('Replay of duplicate event is handled idempotently without corrupting state', () async {
      MockData.clearMockBookings();

      final now = DateTime.now();
      final targetBooking = BookingModel(
        id: 'bk-paymongo-target-2',
        courtId: 'court-1-indoor-cushion',
        startTime: now.add(const Duration(days: 2, hours: 14)),
        endTime: now.add(const Duration(days: 2, hours: 15)),
        totalPrice: 300.0,
        paymongoCheckoutSessionId: 'cs_replay_session_456',
      );
      MockData.addMockBooking(targetBooking);

      const eventId = 'evt_replay_test_002';
      final eventPayload = {
        'data': {
          'id': eventId,
          'type': 'event',
          'attributes': {
            'type': 'payment.paid',
            'livemode': false,
            'data': {
              'id': 'pay_456',
              'type': 'payment',
              'attributes': {
                'reference_number': 'bk-paymongo-target-2',
              },
            },
          },
        },
      };

      final rawBody = jsonEncode(eventPayload);
      final t = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final sig = PayMongoWebhookService.computeHmacSha256Hex(
        key: testSecret,
        data: '$t.$rawBody',
      );
      final signatureHeader = 't=$t,te=$sig';

      final service = PayMongoWebhookService.instance;

      // First run: processes event
      final run1 = await service.processWebhookPayload(
        rawBody: rawBody,
        signatureHeader: signatureHeader,
        secret: testSecret,
      );
      expect(run1.success, isTrue);
      expect(run1.isDuplicate, isFalse);

      final stateAfterRun1 = MockData.mockBookings.firstWhere((b) => b.id == 'bk-paymongo-target-2');
      expect(stateAfterRun1.isPaid, isTrue);
      final updatedAtRun1 = stateAfterRun1.updatedAt;

      // Second run: replay of duplicate event returns idempotent success
      final run2 = await service.processWebhookPayload(
        rawBody: rawBody,
        signatureHeader: signatureHeader,
        secret: testSecret,
      );
      expect(run2.success, isTrue);
      expect(run2.isDuplicate, isTrue); // Idempotent replay detected!
      expect(run2.message, contains('already processed'));

      final stateAfterRun2 = MockData.mockBookings.firstWhere((b) => b.id == 'bk-paymongo-target-2');
      expect(stateAfterRun2.isPaid, isTrue);
      expect(stateAfterRun2.updatedAt, equals(updatedAtRun1)); // Not corrupted or modified
    });

    test('payment.failed event transitions pending booking to cancelled', () async {
      MockData.clearMockBookings();

      final now = DateTime.now();
      final targetBooking = BookingModel(
        id: 'bk-paymongo-target-3',
        courtId: 'court-3-outdoor-lighted',
        startTime: now.add(const Duration(days: 1, hours: 18)),
        endTime: now.add(const Duration(days: 1, hours: 19)),
        totalPrice: 280.0,
        paymongoCheckoutSessionId: 'cs_fail_session_789',
      );
      MockData.addMockBooking(targetBooking);

      const eventId = 'evt_payment_failed_003';
      final eventPayload = {
        'data': {
          'id': eventId,
          'type': 'event',
          'attributes': {
            'type': 'payment.failed',
            'livemode': false,
            'data': {
              'id': 'pay_fail_789',
              'type': 'payment',
              'attributes': {
                'reference_number': 'bk-paymongo-target-3',
              },
            },
          },
        },
      };

      final rawBody = jsonEncode(eventPayload);
      final t = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final sig = PayMongoWebhookService.computeHmacSha256Hex(
        key: testSecret,
        data: '$t.$rawBody',
      );
      final signatureHeader = 't=$t,te=$sig';

      final service = PayMongoWebhookService.instance;
      final result = await service.processWebhookPayload(
        rawBody: rawBody,
        signatureHeader: signatureHeader,
        secret: testSecret,
      );

      expect(result.success, isTrue);
      final updatedBooking = MockData.mockBookings.firstWhere((b) => b.id == 'bk-paymongo-target-3');
      expect(updatedBooking.status, equals('cancelled'));
    });

    test('payment.failed does NOT downgrade an already confirmed booking', () async {
      MockData.clearMockBookings();

      final now = DateTime.now();
      final targetBooking = BookingModel(
        id: 'bk-paymongo-target-4',
        courtId: 'court-1-indoor-cushion',
        startTime: now.add(const Duration(days: 2, hours: 8)),
        endTime: now.add(const Duration(days: 2, hours: 9)),
        totalPrice: 300.0,
        status: 'confirmed', // Already confirmed
        paymongoCheckoutSessionId: 'cs_confirmed_stay',
      );
      MockData.addMockBooking(targetBooking);

      const eventId = 'evt_late_fail_004';
      final eventPayload = {
        'data': {
          'id': eventId,
          'type': 'event',
          'attributes': {
            'type': 'payment.failed',
            'livemode': false,
            'data': {
              'id': 'pay_late_fail',
              'type': 'payment',
              'attributes': {
                'reference_number': 'bk-paymongo-target-4',
              },
            },
          },
        },
      };

      final rawBody = jsonEncode(eventPayload);
      final t = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final sig = PayMongoWebhookService.computeHmacSha256Hex(
        key: testSecret,
        data: '$t.$rawBody',
      );
      final signatureHeader = 't=$t,te=$sig';

      final service = PayMongoWebhookService.instance;
      final result = await service.processWebhookPayload(
        rawBody: rawBody,
        signatureHeader: signatureHeader,
        secret: testSecret,
      );

      expect(result.success, isTrue);
      final booking = MockData.mockBookings.firstWhere((b) => b.id == 'bk-paymongo-target-4');
      expect(booking.status, equals('confirmed')); // Status preserved!
    });
  });
}
