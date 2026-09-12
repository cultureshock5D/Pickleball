import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_app/core/constants/paymongo_config.dart';
import 'package:pickleball_app/data/mock_data.dart';
import 'package:pickleball_app/services/booking_service.dart';
import 'package:pickleball_app/services/paymongo_webhook_service.dart';
import 'package:pickleball_app/services/paymongo_webhook_simulator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PayMongoConfig Webhook Configuration', () {
    test('PayMongoConfig exposes webhookSecretKey and isWebhookConfigured', () {
      expect(PayMongoConfig.webhookSecretKey, isA<String>());
      expect(PayMongoConfig.isWebhookConfigured, isA<bool>());
    });
  });

  group('Cryptographic Hash & HMAC-SHA256 Verification', () {
    test('SHA-256 matches standard FIPS 180-4 test vectors', () {
      // Vector 1: Empty string
      final emptyHash = PayMongoWebhookService.bytesToHex(
        PayMongoWebhookService.sha256(utf8.encode('')),
      );
      expect(
        emptyHash,
        equals('e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'),
      );

      // Vector 2: 'abc'
      final abcHash = PayMongoWebhookService.bytesToHex(
        PayMongoWebhookService.sha256(utf8.encode('abc')),
      );
      expect(
        abcHash,
        equals('ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'),
      );
    });

    test('HMAC-SHA256 matches RFC 4231 standard test vector', () {
      const key = 'key';
      const data = 'The quick brown fox jumps over the lazy dog';
      final hmac = PayMongoWebhookService.computeHmacSha256Hex(
        key: key,
        data: data,
      );
      expect(
        hmac,
        equals('f7bc83f430538424b13298e6aa6fb143ef4d59a14946175997479dbc2d1a3cd8'),
      );
    });

    test('timingSafeEqual behaves correctly for matching and non-matching strings', () {
      expect(PayMongoWebhookService.timingSafeEqual('abcdef', 'abcdef'), isTrue);
      expect(PayMongoWebhookService.timingSafeEqual('abcdef', 'abcdeg'), isFalse);
      expect(PayMongoWebhookService.timingSafeEqual('abcdef', 'abcde'), isFalse);
      expect(PayMongoWebhookService.timingSafeEqual('', ''), isTrue);
    });

    test('parseSignatureHeader correctly parses t, te, and li components', () {
      const header = 't=1747071097,te=aabbccdd1122,li=eeff00112233';
      final parsed = PayMongoWebhookService.parseSignatureHeader(header);
      expect(parsed['t'], equals('1747071097'));
      expect(parsed['te'], equals('aabbccdd1122'));
      expect(parsed['li'], equals('eeff00112233'));
    });

    test('verifySignature succeeds on authentic signatures within 300s tolerance', () {
      const secret = 'whsk_test_secret_abc123';
      const rawBody = '{"data":{"id":"evt_001"}}';
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final sig = PayMongoWebhookService.computeHmacSha256Hex(
        key: secret,
        data: '$now.$rawBody',
      );
      final header = 't=$now,te=$sig,li=$sig';

      final valid = PayMongoWebhookService.verifySignature(
        rawBody: rawBody,
        signatureHeader: header,
        secret: secret,
        currentTimestampSeconds: now,
      );
      expect(valid, isTrue);
    });

    test('verifySignature rejects replay attacks older than 300 seconds', () {
      const secret = 'whsk_test_secret_abc123';
      const rawBody = '{"data":{"id":"evt_001"}}';
      const now = 1747071097;
      const oldTime = now - 301; // 301 seconds ago
      final sig = PayMongoWebhookService.computeHmacSha256Hex(
        key: secret,
        data: '$oldTime.$rawBody',
      );
      final header = 't=$oldTime,te=$sig';

      final valid = PayMongoWebhookService.verifySignature(
        rawBody: rawBody,
        signatureHeader: header,
        secret: secret,
        currentTimestampSeconds: now,
      );
      expect(valid, isFalse);
    });

    test('verifySignature rejects invalid or tampered signatures', () {
      const secret = 'whsk_test_secret_abc123';
      const rawBody = '{"data":{"id":"evt_001"}}';
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      const header = 't=1747071097,te=tampered_signature_hex';

      final valid = PayMongoWebhookService.verifySignature(
        rawBody: rawBody,
        signatureHeader: header,
        secret: secret,
        currentTimestampSeconds: now,
      );
      expect(valid, isFalse);
    });
  });

  group('PayMongoWebhookSimulator Tests', () {
    test('createSignedPayload produces valid authentic signature', () {
      const secret = 'whsk_test_custom_key';
      final payload = PayMongoWebhookSimulator.createSignedPayload(
        eventData: const {
          'data': {
            'id': 'evt_sim_1',
            'type': 'event',
            'attributes': {'type': 'checkout_session.payment.paid'},
          },
        },
        secret: secret,
        timestamp: 1747071000,
      );

      expect(payload.eventId, equals('evt_sim_1'));
      expect(payload.eventType, equals('checkout_session.payment.paid'));
      expect(payload.signatureHeader, contains('t=1747071000'));
      expect(payload.signatureHeader, contains('te='));

      final verified = PayMongoWebhookService.verifySignature(
        rawBody: payload.rawBody,
        signatureHeader: payload.signatureHeader,
        secret: secret,
        currentTimestampSeconds: 1747071000,
      );
      expect(verified, isTrue);
    });

    test('simulatePaymentPaid produces correctly structured JSON:API event', () {
      final signed = PayMongoWebhookSimulator.simulatePaymentPaid(
        checkoutSessionId: 'cs_test_session_101',
        bookingId: 'bk_test_booking_101',
        amountCentavos: 45000,
      );

      final map = jsonDecode(signed.rawBody) as Map<String, dynamic>;
      final data = map['data'] as Map<String, dynamic>;
      expect(data['type'], equals('event'));
      expect(data['attributes']['type'], equals('checkout_session.payment.paid'));
      expect(data['attributes']['data']['id'], equals('cs_test_session_101'));
      expect(
        data['attributes']['data']['attributes']['reference_number'],
        equals('bk_test_booking_101'),
      );
      expect(
        data['attributes']['data']['attributes']['metadata']['booking_id'],
        equals('bk_test_booking_101'),
      );
      expect(
        data['attributes']['data']['attributes']['amount'],
        equals(45000),
      );
    });

    test('simulatePaymentFailed produces correctly structured failure event', () {
      final signed = PayMongoWebhookSimulator.simulatePaymentFailed(
        checkoutSessionId: 'cs_test_session_102',
        bookingId: 'bk_test_booking_102',
        failureMessage: 'Card declined: insufficient funds',
      );

      final map = jsonDecode(signed.rawBody) as Map<String, dynamic>;
      final data = map['data'] as Map<String, dynamic>;
      expect(data['type'], equals('event'));
      expect(data['attributes']['type'], equals('payment.failed'));
      expect(
        data['attributes']['data']['attributes']['failed_code'],
        equals('insufficient_funds'),
      );
      expect(
        data['attributes']['data']['attributes']['reference_number'],
        equals('bk_test_booking_102'),
      );
    });
  });

  group('PayMongoWebhookService Processing & Idempotency Tests', () {
    setUp(() {
      PayMongoWebhookService.instance.clearProcessedEvents();
    });

    test('Transitions pending booking to confirmed on checkout_session.payment.paid', () async {
      final testBooking = MockData.createMockBooking(
        courtId: 'court-1-indoor-cushion',
        startTime: DateTime.now().add(const Duration(days: 3, hours: 10)),
        endTime: DateTime.now().add(const Duration(days: 3, hours: 11)),
        totalAmount: 300.0,
        status: 'pending_payment',
        paymongoCheckoutSessionId: 'cs_hook_test_001',
      );

      final signed = PayMongoWebhookSimulator.simulatePaymentPaid(
        checkoutSessionId: 'cs_hook_test_001',
        bookingId: testBooking.id,
        secret: 'whsk_test_secret_suite',
      );

      final result = await PayMongoWebhookService.instance.processWebhookPayload(
        rawBody: signed.rawBody,
        signatureHeader: signed.signatureHeader,
        secret: 'whsk_test_secret_suite',
        currentTimestampSeconds: signed.timestamp,
      );

      expect(result.success, isTrue);
      expect(result.status, equals('confirmed'));
      expect(result.isDuplicate, isFalse);
      expect(result.bookingId, equals(testBooking.id));

      // Verify mock store was updated
      final updated = MockData.mockBookings.firstWhere((b) => b.id == testBooking.id);
      expect(updated.isPaid, isTrue);
    });

    test('Enforces idempotency: Duplicate event returns success with isDuplicate: true', () async {
      final testBooking = MockData.createMockBooking(
        courtId: 'court-1-indoor-cushion',
        startTime: DateTime.now().add(const Duration(days: 4, hours: 14)),
        endTime: DateTime.now().add(const Duration(days: 4, hours: 15)),
        totalAmount: 300.0,
        status: 'pending_payment',
        paymongoCheckoutSessionId: 'cs_hook_test_dup',
      );

      final signed = PayMongoWebhookSimulator.simulatePaymentPaid(
        checkoutSessionId: 'cs_hook_test_dup',
        bookingId: testBooking.id,
        eventId: 'evt_idempotent_unique_999',
        secret: 'whsk_test_secret_suite',
      );

      // First run: processes mutation
      final res1 = await PayMongoWebhookService.instance.processWebhookPayload(
        rawBody: signed.rawBody,
        signatureHeader: signed.signatureHeader,
        secret: 'whsk_test_secret_suite',
        currentTimestampSeconds: signed.timestamp,
      );
      expect(res1.success, isTrue);
      expect(res1.isDuplicate, isFalse);

      // Second run: exact same event ID arrives (replay)
      final res2 = await PayMongoWebhookService.instance.processWebhookPayload(
        rawBody: signed.rawBody,
        signatureHeader: signed.signatureHeader,
        secret: 'whsk_test_secret_suite',
        currentTimestampSeconds: signed.timestamp,
      );
      expect(res2.success, isTrue);
      expect(res2.isDuplicate, isTrue);
      expect(res2.status, equals('duplicate'));
    });

    test('Transitions pending booking to cancelled on payment.failed', () async {
      final testBooking = MockData.createMockBooking(
        courtId: 'court-2-indoor-tourspec',
        startTime: DateTime.now().add(const Duration(days: 5, hours: 9)),
        endTime: DateTime.now().add(const Duration(days: 5, hours: 10)),
        totalAmount: 350.0,
        status: 'pending_payment',
        paymongoCheckoutSessionId: 'cs_hook_test_fail',
      );

      final signed = PayMongoWebhookSimulator.simulatePaymentFailed(
        checkoutSessionId: 'cs_hook_test_fail',
        bookingId: testBooking.id,
        secret: 'whsk_test_secret_suite',
      );

      final result = await PayMongoWebhookService.instance.processWebhookPayload(
        rawBody: signed.rawBody,
        signatureHeader: signed.signatureHeader,
        secret: 'whsk_test_secret_suite',
        currentTimestampSeconds: signed.timestamp,
      );

      expect(result.success, isTrue);
      expect(result.status, equals('cancelled'));

      final updated = MockData.mockBookings.firstWhere((b) => b.id == testBooking.id);
      expect(updated.status, equals('cancelled'));
    });

    test('Preserves confirmed state: payment.failed does NOT cancel already confirmed booking', () async {
      final confirmedBooking = MockData.createMockBooking(
        courtId: 'court-3-outdoor-lighted',
        startTime: DateTime.now().add(const Duration(days: 6, hours: 16)),
        endTime: DateTime.now().add(const Duration(days: 6, hours: 17)),
        totalAmount: 280.0,
        paymongoCheckoutSessionId: 'cs_hook_already_confirmed',
      );

      final signedFailed = PayMongoWebhookSimulator.simulatePaymentFailed(
        checkoutSessionId: 'cs_hook_already_confirmed',
        bookingId: confirmedBooking.id,
        secret: 'whsk_test_secret_suite',
      );

      final result = await PayMongoWebhookService.instance.processWebhookPayload(
        rawBody: signedFailed.rawBody,
        signatureHeader: signedFailed.signatureHeader,
        secret: 'whsk_test_secret_suite',
        currentTimestampSeconds: signedFailed.timestamp,
      );

      expect(result.success, isTrue);
      expect(result.status, equals('confirmed'));
      expect(result.message, contains('Ignored payment.failed'));

      final stillConfirmed = MockData.mockBookings.firstWhere((b) => b.id == confirmedBooking.id);
      expect(stillConfirmed.isPaid, isTrue);
      expect(stillConfirmed.isCancelled, isFalse);
    });

    test('Dispatches BookingRealtimeEvent to BookingService.instance stream', () async {
      final testBooking = MockData.createMockBooking(
        courtId: 'court-4-outdoor-acrylic',
        startTime: DateTime.now().add(const Duration(days: 7, hours: 18)),
        endTime: DateTime.now().add(const Duration(days: 7, hours: 19)),
        totalAmount: 320.0,
        status: 'pending_payment',
        paymongoCheckoutSessionId: 'cs_realtime_stream_test',
      );

      final eventsReceived = <BookingRealtimeEvent>[];
      final subscription = BookingService.instance.bookingRealtimeEvents.listen((e) {
        eventsReceived.add(e);
      });

      await PayMongoWebhookSimulator.dispatchPaymentPaid(
        checkoutSessionId: 'cs_realtime_stream_test',
        bookingId: testBooking.id,
        secret: 'whsk_test_secret_suite',
      );

      // Allow microtask queue to deliver broadcast event
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(eventsReceived.isNotEmpty, isTrue);
      expect(eventsReceived.last.type, equals(BookingRealtimeEventType.updated));
      expect(eventsReceived.last.courtId, equals('court-4-outdoor-acrylic'));

      await subscription.cancel();
    });
  });

  group('Challenger 2 Empirical Adversarial Security & Idempotency Stress Tests', () {
    setUp(() {
      PayMongoWebhookService.instance.clearProcessedEvents();
    });

    // 1. Single-byte mutation stress testing
    test('Challenge 1A: Rejects single-byte mutation at beginning of signature', () {
      const secret = 'whsk_test_secret_suite';
      const rawBody = '{"data":{"id":"evt_mut_1"}}';
      const now = 1747071000;
      final authenticSig = PayMongoWebhookService.computeHmacSha256Hex(
        key: secret,
        data: '$now.$rawBody',
      );
      final mutatedFirstChar = authenticSig[0] == 'a' ? 'b' : 'a';
      final mutatedSig = mutatedFirstChar + authenticSig.substring(1);

      final valid = PayMongoWebhookService.verifySignature(
        rawBody: rawBody,
        signatureHeader: 't=$now,te=$mutatedSig',
        secret: secret,
        currentTimestampSeconds: now,
      );
      expect(valid, isFalse);
    });

    test('Challenge 1B: Rejects single-byte mutation at midpoint of signature', () {
      const secret = 'whsk_test_secret_suite';
      const rawBody = '{"data":{"id":"evt_mut_2"}}';
      const now = 1747071000;
      final authenticSig = PayMongoWebhookService.computeHmacSha256Hex(
        key: secret,
        data: '$now.$rawBody',
      );
      final midChar = authenticSig[32] == '0' ? '1' : '0';
      final mutatedSig = authenticSig.substring(0, 32) + midChar + authenticSig.substring(33);

      final valid = PayMongoWebhookService.verifySignature(
        rawBody: rawBody,
        signatureHeader: 't=$now,te=$mutatedSig',
        secret: secret,
        currentTimestampSeconds: now,
      );
      expect(valid, isFalse);
    });

    test('Challenge 1C: Rejects single-byte mutation at end of signature', () {
      const secret = 'whsk_test_secret_suite';
      const rawBody = '{"data":{"id":"evt_mut_3"}}';
      const now = 1747071000;
      final authenticSig = PayMongoWebhookService.computeHmacSha256Hex(
        key: secret,
        data: '$now.$rawBody',
      );
      final endChar = authenticSig[63] == 'f' ? 'e' : 'f';
      final mutatedSig = authenticSig.substring(0, 63) + endChar;

      final valid = PayMongoWebhookService.verifySignature(
        rawBody: rawBody,
        signatureHeader: 't=$now,te=$mutatedSig',
        secret: secret,
        currentTimestampSeconds: now,
      );
      expect(valid, isFalse);
    });

    test('Challenge 1D: Rejects single-byte alteration in raw JSON body', () async {
      final signed = PayMongoWebhookSimulator.simulatePaymentPaid(
        checkoutSessionId: 'cs_hook_body_tamper',
        bookingId: 'bk_tamper_001',
        amountCentavos: 10000,
        secret: 'whsk_test_secret_suite',
      );

      final tamperedBody = signed.rawBody.replaceFirst('"amount":10000', '"amount":90000');

      final result = await PayMongoWebhookService.instance.processWebhookPayload(
        rawBody: tamperedBody,
        signatureHeader: signed.signatureHeader,
        secret: 'whsk_test_secret_suite',
        currentTimestampSeconds: signed.timestamp,
      );

      expect(result.success, isFalse);
      expect(result.status, equals('invalid_signature'));
      expect(result.message, contains('Cryptographic signature mismatch'));
    });

    test('Challenge 1E: Rejects missing timestamp component t in signature header', () async {
      const secret = 'whsk_test_secret_suite';
      final signed = PayMongoWebhookSimulator.simulatePaymentPaid(
        checkoutSessionId: 'cs_hook_no_t',
        bookingId: 'bk_no_t_001',
        secret: secret,
      );

      const headerWithoutT = 'te=abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890';

      final result = await PayMongoWebhookService.instance.processWebhookPayload(
        rawBody: signed.rawBody,
        signatureHeader: headerWithoutT,
        secret: secret,
      );

      expect(result.success, isFalse);
      expect(result.status, equals('invalid_header'));
      expect(result.message, contains('Missing timestamp t'));
    });

    test('Challenge 1F: Rejects malformed non-integer timestamp t', () async {
      const secret = 'whsk_test_secret_suite';
      final signed = PayMongoWebhookSimulator.simulatePaymentPaid(
        checkoutSessionId: 'cs_hook_bad_t',
        bookingId: 'bk_bad_t_001',
        secret: secret,
      );

      const headerBadT = 't=not_a_unix_timestamp,te=abcdef1234567890';

      final result = await PayMongoWebhookService.instance.processWebhookPayload(
        rawBody: signed.rawBody,
        signatureHeader: headerBadT,
        secret: secret,
      );

      expect(result.success, isFalse);
      expect(result.status, equals('invalid_timestamp'));
      expect(result.message, contains('Invalid timestamp format'));
    });

    test('Challenge 1G: Rejects missing signature digest component', () async {
      const secret = 'whsk_test_secret_suite';
      final signed = PayMongoWebhookSimulator.simulatePaymentPaid(
        checkoutSessionId: 'cs_hook_no_sig',
        bookingId: 'bk_no_sig_001',
        secret: secret,
      );

      const headerNoSig = 't=1747071000';

      final result = await PayMongoWebhookService.instance.processWebhookPayload(
        rawBody: signed.rawBody,
        signatureHeader: headerNoSig,
        secret: secret,
      );

      expect(result.success, isFalse);
      expect(result.status, equals('missing_signature'));
    });

    // 2. Replay attack window stress testing (+301s, -301s, exact boundaries)
    test('Challenge 2A: Rejects timestamp exactly 301 seconds in the past', () async {
      const secret = 'whsk_test_secret_suite';
      const now = 1747071000;
      const pastTime = now - 301;

      final signed = PayMongoWebhookSimulator.createSignedPayload(
        eventData: const {
          'data': {
            'id': 'evt_past_301',
            'type': 'event',
            'attributes': {'type': 'checkout_session.payment.paid'},
          },
        },
        secret: secret,
        timestamp: pastTime,
      );

      final result = await PayMongoWebhookService.instance.processWebhookPayload(
        rawBody: signed.rawBody,
        signatureHeader: signed.signatureHeader,
        secret: secret,
        currentTimestampSeconds: now,
      );

      expect(result.success, isFalse);
      expect(result.status, equals('replay_rejected'));
      expect(result.message, contains('outside 300-second freshness tolerance window'));
    });

    test('Challenge 2B: Rejects timestamp exactly 301 seconds in the future', () async {
      const secret = 'whsk_test_secret_suite';
      const now = 1747071000;
      const futureTime = now + 301;

      final signed = PayMongoWebhookSimulator.createSignedPayload(
        eventData: const {
          'data': {
            'id': 'evt_future_301',
            'type': 'event',
            'attributes': {'type': 'checkout_session.payment.paid'},
          },
        },
        secret: secret,
        timestamp: futureTime,
      );

      final result = await PayMongoWebhookService.instance.processWebhookPayload(
        rawBody: signed.rawBody,
        signatureHeader: signed.signatureHeader,
        secret: secret,
        currentTimestampSeconds: now,
      );

      expect(result.success, isFalse);
      expect(result.status, equals('replay_rejected'));
      expect(result.message, contains('outside 300-second freshness tolerance window'));
    });

    test('Challenge 2C: Accepts timestamps exactly on the 300-second boundary (+300s, -300s)', () {
      const secret = 'whsk_test_secret_suite';
      const now = 1747071000;
      const rawBody = '{"data":{"id":"evt_boundary"}}';

      // Past boundary: exactly 300s ago
      const tPast300 = now - 300;
      final sigPast = PayMongoWebhookService.computeHmacSha256Hex(
        key: secret,
        data: '$tPast300.$rawBody',
      );
      final validPast = PayMongoWebhookService.verifySignature(
        rawBody: rawBody,
        signatureHeader: 't=$tPast300,te=$sigPast',
        secret: secret,
        currentTimestampSeconds: now,
      );
      expect(validPast, isTrue, reason: 'Exactly 300s in the past must be accepted');

      // Future boundary: exactly 300s in the future
      const tFuture300 = now + 300;
      final sigFuture = PayMongoWebhookService.computeHmacSha256Hex(
        key: secret,
        data: '$tFuture300.$rawBody',
      );
      final validFuture = PayMongoWebhookService.verifySignature(
        rawBody: rawBody,
        signatureHeader: 't=$tFuture300,te=$sigFuture',
        secret: secret,
        currentTimestampSeconds: now,
      );
      expect(validFuture, isTrue, reason: 'Exactly 300s in the future must be accepted');
    });

    // 3. Parallel duplicate firing and out-of-order state corruption challenge
    test('Challenge 3: Firing 5 identical payment.paid events in parallel, then payment.failed on confirmed booking', () async {
      final testBooking = MockData.createMockBooking(
        courtId: 'court-1-indoor-cushion',
        startTime: DateTime.now().add(const Duration(days: 10, hours: 9)),
        endTime: DateTime.now().add(const Duration(days: 10, hours: 10)),
        totalAmount: 350.0,
        status: 'pending_payment',
        paymongoCheckoutSessionId: 'cs_parallel_stress_test',
      );

      final signedPaid = PayMongoWebhookSimulator.simulatePaymentPaid(
        checkoutSessionId: 'cs_parallel_stress_test',
        bookingId: testBooking.id,
        eventId: 'evt_parallel_paid_burst_555',
        amountCentavos: 35000,
        secret: 'whsk_test_secret_suite',
      );

      // Fire 5 identical payment.paid events concurrently
      final futures = List.generate(5, (_) => PayMongoWebhookService.instance.processWebhookPayload(
        rawBody: signedPaid.rawBody,
        signatureHeader: signedPaid.signatureHeader,
        secret: 'whsk_test_secret_suite',
        currentTimestampSeconds: signedPaid.timestamp,
      ));

      final results = await Future.wait(futures);

      expect(results.length, equals(5));
      final originalResults = results.where((r) => !r.isDuplicate).toList();
      final duplicateResults = results.where((r) => r.isDuplicate).toList();

      expect(originalResults.length, equals(1), reason: 'Exactly 1 request should be processed as non-duplicate');
      expect(originalResults.first.status, equals('confirmed'));
      expect(originalResults.first.success, isTrue);

      expect(duplicateResults.length, equals(4), reason: 'Exactly 4 concurrent requests must be flagged as duplicates');
      for (final dup in duplicateResults) {
        expect(dup.success, isTrue);
        expect(dup.status, equals('duplicate'));
      }

      // Verify booking state in store
      final bookingAfterPaid = MockData.mockBookings.firstWhere((b) => b.id == testBooking.id);
      expect(bookingAfterPaid.status, equals('confirmed'));
      expect(bookingAfterPaid.isPaid, isTrue);
      expect(bookingAfterPaid.isCancelled, isFalse);

      // NOW: Fire an out-of-order / delayed payment.failed event for this already confirmed booking
      final signedFailed = PayMongoWebhookSimulator.simulatePaymentFailed(
        checkoutSessionId: 'cs_parallel_stress_test',
        bookingId: testBooking.id,
        eventId: 'evt_delayed_failure_burst_666',
        secret: 'whsk_test_secret_suite',
      );

      final failResult = await PayMongoWebhookService.instance.processWebhookPayload(
        rawBody: signedFailed.rawBody,
        signatureHeader: signedFailed.signatureHeader,
        secret: 'whsk_test_secret_suite',
        currentTimestampSeconds: signedFailed.timestamp,
      );

      expect(failResult.success, isTrue);
      expect(failResult.status, equals('confirmed'));
      expect(failResult.message, contains('Ignored payment.failed for already confirmed booking'));

      // Verify booking remains confirmed and was NOT corrupted or cancelled
      final bookingAfterFail = MockData.mockBookings.firstWhere((b) => b.id == testBooking.id);
      expect(bookingAfterFail.status, equals('confirmed'));
      expect(bookingAfterFail.isPaid, isTrue);
      expect(bookingAfterFail.isCancelled, isFalse);
    });

    // 4. Repeated Delayed Failure Events & Unsettled Booking Isolation
    test('Challenge 4: Multiple delayed failures never corrupt confirmed bookings', () async {
      final confirmedBooking = MockData.createMockBooking(
        courtId: 'court-2-indoor-tourspec',
        startTime: DateTime.now().add(const Duration(days: 11, hours: 14)),
        endTime: DateTime.now().add(const Duration(days: 11, hours: 15)),
        totalAmount: 400.0,
        paymongoCheckoutSessionId: 'cs_multi_fail_test',
      );

      for (int i = 1; i <= 3; i++) {
        final delayedFail = PayMongoWebhookSimulator.simulatePaymentFailed(
          checkoutSessionId: 'cs_multi_fail_test',
          bookingId: confirmedBooking.id,
          eventId: 'evt_multi_delayed_fail_$i',
          secret: 'whsk_test_secret_suite',
        );

        final res = await PayMongoWebhookService.instance.processWebhookPayload(
          rawBody: delayedFail.rawBody,
          signatureHeader: delayedFail.signatureHeader,
          secret: 'whsk_test_secret_suite',
          currentTimestampSeconds: delayedFail.timestamp,
        );

        expect(res.success, isTrue);
        expect(res.status, equals('confirmed'));
      }

      final check = MockData.mockBookings.firstWhere((b) => b.id == confirmedBooking.id);
      expect(check.status, equals('confirmed'));
      expect(check.isPaid, isTrue);
      expect(check.isCancelled, isFalse);
    });
  });
}

