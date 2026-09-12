import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_app/data/mock_data.dart';
import 'package:pickleball_app/models/booking_model.dart';
import 'package:pickleball_app/services/paymongo_webhook_service.dart';

/// Lightweight simulator for supabase/functions/paymongo-webhook/index.ts
/// Validates HTTP status code contracts and payload responses
class EdgeFunctionSimulator {
  final String webhookSecret;
  final Set<String> processedEvents = <String>{};

  EdgeFunctionSimulator({required this.webhookSecret});

  Future<Map<String, dynamic>> handleRequest({
    required String method,
    required Map<String, String> headers,
    required String body,
    int? currentTimestampSeconds,
  }) async {
    // 1. Only accept POST
    if (method != 'POST') {
      return {
        'status': 405,
        'body': {'error': 'Method not allowed'},
      };
    }

    final signatureHeader = headers['Paymongo-Signature'] ?? headers['paymongo-signature'] ?? '';
    if (signatureHeader.isEmpty || webhookSecret.isEmpty) {
      return {
        'status': 400,
        'body': {'error': 'Missing Paymongo-Signature header or webhook secret is unconfigured'},
      };
    }

    final parsedHeader = PayMongoWebhookService.parseSignatureHeader(signatureHeader);
    final tStr = parsedHeader['t'];
    if (tStr == null || tStr.isEmpty) {
      return {
        'status': 400,
        'body': {'error': "Missing timestamp parameter 't' in Paymongo-Signature header"},
      };
    }

    final t = int.tryParse(tStr);
    if (t == null) {
      return {
        'status': 400,
        'body': {'error': 'Invalid timestamp in signature header'},
      };
    }

    // 300s freshness window
    final now = currentTimestampSeconds ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    if ((now - t).abs() > 300) {
      return {
        'status': 400,
        'body': {'error': 'Signature timestamp expired: tolerance window is 300 seconds'},
      };
    }

    dynamic payload;
    try {
      payload = jsonDecode(body);
    } catch (_) {
      return {
        'status': 400,
        'body': {'error': 'Malformed JSON payload in request body'},
      };
    }

    final isLive = payload is Map &&
        payload['data'] is Map &&
        payload['data']['attributes'] is Map &&
        payload['data']['attributes']['livemode'] == true;

    final targetSig = isLive
        ? (parsedHeader['li'] ?? parsedHeader['te'])
        : (parsedHeader['te'] ?? parsedHeader['li']);

    final stringToSign = '$t.$body';
    final computedSig = PayMongoWebhookService.computeHmacSha256Hex(
      key: webhookSecret,
      data: stringToSign,
    );

    if (targetSig == null ||
        targetSig.isEmpty ||
        !PayMongoWebhookService.timingSafeEqual(computedSig.toLowerCase(), targetSig.toLowerCase())) {
      return {
        'status': 401,
        'body': {'error': 'Cryptographic HMAC-SHA256 signature verification failed'},
      };
    }

    // Extract event ID for idempotency check
    final eventId = (payload is Map && payload['data'] is Map)
        ? payload['data']['id']?.toString() ?? ''
        : '';

    final isReplay = processedEvents.contains(eventId);
    if (!isReplay && eventId.isNotEmpty) {
      processedEvents.add(eventId);
    }

    return {
      'status': 200,
      'body': {
        'received': true,
        'result': {
          'success': true,
          'idempotent_replay': isReplay,
          'event_id': eventId,
          'message': isReplay ? 'Event already processed' : 'Processed successfully',
        },
      },
    };
  }
}

void main() {
  setUp(() {
    MockData.resetToDefault();
    PayMongoWebhookService.instance.clearProcessedEvents();
  });

  const testSecret = 'whsk_test_6f8b2d4e9a1c3e5a7b9c1d3e5f7a9b1c';

  group('Adversarial Stress Test: Timestamp Freshness & Clock Skew Boundaries', () {
    test('Boundary: t exactly at now - 300s is ACCEPTED', () {
      const nowSec = 1726135000;
      const t = nowSec - 300; // Exact boundary
      final valid = PayMongoWebhookService.verifySignature(
        rawBody: '{"data":{}}',
        signatureHeader: 't=$t,te=${PayMongoWebhookService.computeHmacSha256Hex(key: testSecret, data: '$t.{"data":{}}')}',
        secret: testSecret,
        currentTimestampSeconds: nowSec,
      );
      expect(valid, isTrue, reason: 'Exact 300s past boundary must be accepted');
    });

    test('Boundary: t at now - 299s is ACCEPTED', () {
      const nowSec = 1726135000;
      const t = nowSec - 299;
      final valid = PayMongoWebhookService.verifySignature(
        rawBody: '{"data":{}}',
        signatureHeader: 't=$t,te=${PayMongoWebhookService.computeHmacSha256Hex(key: testSecret, data: '$t.{"data":{}}')}',
        secret: testSecret,
        currentTimestampSeconds: nowSec,
      );
      expect(valid, isTrue, reason: '299s past must be accepted');
    });

    test('Boundary: t at now - 301s is REJECTED', () {
      const nowSec = 1726135000;
      const t = nowSec - 301; // 1 second past tolerance
      final valid = PayMongoWebhookService.verifySignature(
        rawBody: '{"data":{}}',
        signatureHeader: 't=$t,te=${PayMongoWebhookService.computeHmacSha256Hex(key: testSecret, data: '$t.{"data":{}}')}',
        secret: testSecret,
        currentTimestampSeconds: nowSec,
      );
      expect(valid, isFalse, reason: '301s past must be rejected');
    });

    test('Boundary: t at now + 300s (future clock skew) is ACCEPTED', () {
      const nowSec = 1726135000;
      const t = nowSec + 300;
      final valid = PayMongoWebhookService.verifySignature(
        rawBody: '{"data":{}}',
        signatureHeader: 't=$t,te=${PayMongoWebhookService.computeHmacSha256Hex(key: testSecret, data: '$t.{"data":{}}')}',
        secret: testSecret,
        currentTimestampSeconds: nowSec,
      );
      expect(valid, isTrue, reason: 'Future clock skew within 300s must be accepted');
    });

    test('Boundary: t at now + 301s (future clock skew) is REJECTED', () {
      const nowSec = 1726135000;
      const t = nowSec + 301;
      final valid = PayMongoWebhookService.verifySignature(
        rawBody: '{"data":{}}',
        signatureHeader: 't=$t,te=${PayMongoWebhookService.computeHmacSha256Hex(key: testSecret, data: '$t.{"data":{}}')}',
        secret: testSecret,
        currentTimestampSeconds: nowSec,
      );
      expect(valid, isFalse, reason: 'Future clock skew > 300s must be rejected');
    });

    test('Rejects invalid non-numeric timestamps and missing parameters', () {
      const nowSec = 1726135000;
      expect(
        PayMongoWebhookService.verifySignature(
          rawBody: '{"data":{}}',
          signatureHeader: 't=not_a_number,te=abc',
          secret: testSecret,
          currentTimestampSeconds: nowSec,
        ),
        isFalse,
      );
      expect(
        PayMongoWebhookService.verifySignature(
          rawBody: '{"data":{}}',
          signatureHeader: 'te=abc', // Missing t
          secret: testSecret,
          currentTimestampSeconds: nowSec,
        ),
        isFalse,
      );
      expect(
        PayMongoWebhookService.verifySignature(
          rawBody: '{"data":{}}',
          signatureHeader: '', // Empty header
          secret: testSecret,
          currentTimestampSeconds: nowSec,
        ),
        isFalse,
      );
    });
  });

  group('Adversarial Stress Test: Cryptographic Bit Flips & Signature Corruption', () {
    const rawBody = '{"data":{"id":"evt_adv_001","attributes":{"type":"payment.paid"}}}';
    const nowSec = 1726135000;

    test('Single-bit flip in HMAC hex string is rejected', () {
      final validSig = PayMongoWebhookService.computeHmacSha256Hex(
        key: testSecret,
        data: '$nowSec.$rawBody',
      );

      // Flip the first character
      final corruptedFirstChar = (validSig[0] == 'a') ? 'b' : 'a';
      final flippedSig = '$corruptedFirstChar${validSig.substring(1)}';

      expect(
        PayMongoWebhookService.verifySignature(
          rawBody: rawBody,
          signatureHeader: 't=$nowSec,te=$flippedSig',
          secret: testSecret,
          currentTimestampSeconds: nowSec,
        ),
        isFalse,
        reason: 'Bit-flipped signature must fail verification',
      );
    });

    test('Truncated signature (63 instead of 64 hex chars) is rejected', () {
      final validSig = PayMongoWebhookService.computeHmacSha256Hex(
        key: testSecret,
        data: '$nowSec.$rawBody',
      );
      final truncatedSig = validSig.substring(0, 63);

      expect(
        PayMongoWebhookService.verifySignature(
          rawBody: rawBody,
          signatureHeader: 't=$nowSec,te=$truncatedSig',
          secret: testSecret,
          currentTimestampSeconds: nowSec,
        ),
        isFalse,
        reason: 'Truncated signature must fail verification',
      );
    });

    test('Tampered body with extra space is rejected', () {
      final validSig = PayMongoWebhookService.computeHmacSha256Hex(
        key: testSecret,
        data: '$nowSec.$rawBody',
      );
      const tamperedBody = '{"data":{"id":"evt_adv_001","attributes":{"type":"payment.paid"}}} ';

      expect(
        PayMongoWebhookService.verifySignature(
          rawBody: tamperedBody,
          signatureHeader: 't=$nowSec,te=$validSig',
          secret: testSecret,
          currentTimestampSeconds: nowSec,
        ),
        isFalse,
        reason: 'Tampered body must fail verification',
      );
    });

    test('Wrong secret key is rejected', () {
      const wrongSecret = 'whsk_test_wrong_secret_key_1234567890';
      final wrongSig = PayMongoWebhookService.computeHmacSha256Hex(
        key: wrongSecret,
        data: '$nowSec.$rawBody',
      );

      expect(
        PayMongoWebhookService.verifySignature(
          rawBody: rawBody,
          signatureHeader: 't=$nowSec,te=$wrongSig',
          secret: testSecret,
          currentTimestampSeconds: nowSec,
        ),
        isFalse,
        reason: 'Signature computed with wrong secret must be rejected',
      );
    });
  });

  group('Adversarial Stress Test: Edge Function HTTP Simulator Status Codes', () {
    final simulator = EdgeFunctionSimulator(webhookSecret: testSecret);
    const validBody = '{"data":{"id":"evt_edge_001","attributes":{"livemode":false,"type":"payment.paid"}}}';
    const nowSec = 1726135000;
    final validSig = PayMongoWebhookService.computeHmacSha256Hex(
      key: testSecret,
      data: '$nowSec.$validBody',
    );
    final validHeader = 't=$nowSec,te=$validSig';

    test('Rejects non-POST methods with HTTP 405', () async {
      final getResp = await simulator.handleRequest(
        method: 'GET',
        headers: {'Paymongo-Signature': validHeader},
        body: validBody,
        currentTimestampSeconds: nowSec,
      );
      expect(getResp['status'], equals(405));

      final putResp = await simulator.handleRequest(
        method: 'PUT',
        headers: {'Paymongo-Signature': validHeader},
        body: validBody,
        currentTimestampSeconds: nowSec,
      );
      expect(putResp['status'], equals(405));
    });

    test('Rejects missing Paymongo-Signature header with HTTP 400', () async {
      final resp = await simulator.handleRequest(
        method: 'POST',
        headers: {},
        body: validBody,
        currentTimestampSeconds: nowSec,
      );
      expect(resp['status'], equals(400));
      expect(resp['body']['error'], contains('Missing Paymongo-Signature'));
    });

    test('Rejects missing timestamp t with HTTP 400', () async {
      final resp = await simulator.handleRequest(
        method: 'POST',
        headers: {'Paymongo-Signature': 'te=$validSig'},
        body: validBody,
        currentTimestampSeconds: nowSec,
      );
      expect(resp['status'], equals(400));
      expect(resp['body']['error'], contains("Missing timestamp parameter 't'"));
    });

    test('Rejects expired timestamp (>300s) with HTTP 400', () async {
      const expiredT = nowSec - 305;
      final expiredSig = PayMongoWebhookService.computeHmacSha256Hex(
        key: testSecret,
        data: '$expiredT.$validBody',
      );
      final resp = await simulator.handleRequest(
        method: 'POST',
        headers: {'Paymongo-Signature': 't=$expiredT,te=$expiredSig'},
        body: validBody,
        currentTimestampSeconds: nowSec,
      );
      expect(resp['status'], equals(400));
      expect(resp['body']['error'], contains('expired: tolerance window is 300 seconds'));
    });

    test('Rejects malformed JSON body with HTTP 400', () async {
      const malformedBody = '{"data": { unclosed json...';
      const t = nowSec;
      final sig = PayMongoWebhookService.computeHmacSha256Hex(
        key: testSecret,
        data: '$t.$malformedBody',
      );
      final resp = await simulator.handleRequest(
        method: 'POST',
        headers: {'Paymongo-Signature': 't=$t,te=$sig'},
        body: malformedBody,
        currentTimestampSeconds: nowSec,
      );
      expect(resp['status'], equals(400));
      expect(resp['body']['error'], contains('Malformed JSON payload'));
    });

    test('Rejects corrupted signature with HTTP 401', () async {
      final resp = await simulator.handleRequest(
        method: 'POST',
        headers: {'Paymongo-Signature': 't=$nowSec,te=0000000000000000000000000000000000000000000000000000000000000000'},
        body: validBody,
        currentTimestampSeconds: nowSec,
      );
      expect(resp['status'], equals(401));
      expect(resp['body']['error'], contains('Cryptographic HMAC-SHA256 signature verification failed'));
    });

    test('Accepts valid request with HTTP 200', () async {
      final resp = await simulator.handleRequest(
        method: 'POST',
        headers: {'Paymongo-Signature': validHeader},
        body: validBody,
        currentTimestampSeconds: nowSec,
      );
      expect(resp['status'], equals(200));
      expect(resp['body']['received'], isTrue);
      expect(resp['body']['result']['idempotent_replay'], isFalse);
    });

    test('Replay of same event returns HTTP 200 with idempotent_replay: true', () async {
      final replayResp = await simulator.handleRequest(
        method: 'POST',
        headers: {'Paymongo-Signature': validHeader},
        body: validBody,
        currentTimestampSeconds: nowSec,
      );
      expect(replayResp['status'], equals(200));
      expect(replayResp['body']['received'], isTrue);
      expect(replayResp['body']['result']['idempotent_replay'], isTrue);
      expect(replayResp['body']['result']['message'], equals('Event already processed'));
    });
  });

  group('Adversarial Stress Test: 10x Consecutive Duplicate Replay & State Preservation', () {
    test('10 consecutive duplicate deliveries return HTTP 200 and do not modify state', () async {
      MockData.clearMockBookings();

      final now = DateTime.now();
      final targetBooking = BookingModel(
        id: 'bk-stress-replay-1',
        courtId: 'court-1-indoor-cushion',
        startTime: now.add(const Duration(days: 1, hours: 10)),
        endTime: now.add(const Duration(days: 1, hours: 11)),
        totalPrice: 300.0,
        paymongoCheckoutSessionId: 'cs_stress_10x',
      );
      MockData.addMockBooking(targetBooking);

      const eventId = 'evt_stress_10x_001';
      final eventPayload = {
        'data': {
          'id': eventId,
          'type': 'event',
          'attributes': {
            'type': 'payment.paid',
            'livemode': false,
            'data': {
              'id': 'pay_stress_10x',
              'type': 'payment',
              'attributes': {
                'reference_number': 'bk-stress-replay-1',
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

      // Iteration 1: initial transition
      final res1 = await service.processWebhookPayload(
        rawBody: rawBody,
        signatureHeader: signatureHeader,
        secret: testSecret,
      );
      expect(res1.success, isTrue);
      expect(res1.isDuplicate, isFalse);

      final bookingAfterRes1 = MockData.mockBookings.firstWhere((b) => b.id == 'bk-stress-replay-1');
      expect(bookingAfterRes1.isPaid, isTrue);
      final initialUpdatedAt = bookingAfterRes1.updatedAt;

      // Iterations 2 to 10: duplicate replay suppression
      for (int i = 2; i <= 10; i++) {
        final resI = await service.processWebhookPayload(
          rawBody: rawBody,
          signatureHeader: signatureHeader,
          secret: testSecret,
        );
        expect(resI.success, isTrue, reason: 'Replay $i must return success');
        expect(resI.isDuplicate, isTrue, reason: 'Replay $i must be flagged duplicate');
        expect(resI.status, equals('duplicate'));

        final currentBooking = MockData.mockBookings.firstWhere((b) => b.id == 'bk-stress-replay-1');
        expect(currentBooking.isPaid, isTrue);
        expect(currentBooking.updatedAt, equals(initialUpdatedAt),
            reason: 'Replay $i must not modify booking updatedAt timestamp');
      }

      expect(service.processedEventsCount, equals(1),
          reason: 'Set of processed event IDs must contain exactly 1 entry for evt_stress_10x_001');
    });

    test('Out-of-order race: payment.failed after payment.paid does NOT downgrade confirmed booking', () async {
      MockData.clearMockBookings();

      final now = DateTime.now();
      final targetBooking = BookingModel(
        id: 'bk-out-of-order-1',
        courtId: 'court-2-indoor-cushion',
        startTime: now.add(const Duration(days: 3, hours: 14)),
        endTime: now.add(const Duration(days: 3, hours: 15)),
        totalPrice: 300.0,
        paymongoCheckoutSessionId: 'cs_ooo_123',
      );
      MockData.addMockBooking(targetBooking);

      final service = PayMongoWebhookService.instance;

      // 1. First event: payment.paid arrives and confirms booking
      final paidPayload = {
        'data': {
          'id': 'evt_paid_early',
          'type': 'event',
          'attributes': {
            'type': 'payment.paid',
            'livemode': false,
            'data': {
              'id': 'pay_ooo_123',
              'type': 'payment',
              'attributes': {'reference_number': 'bk-out-of-order-1'},
            },
          },
        },
      };
      final paidBody = jsonEncode(paidPayload);
      final t1 = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final sig1 = PayMongoWebhookService.computeHmacSha256Hex(key: testSecret, data: '$t1.$paidBody');

      final paidResult = await service.processWebhookPayload(
        rawBody: paidBody,
        signatureHeader: 't=$t1,te=$sig1',
        secret: testSecret,
      );
      expect(paidResult.success, isTrue);
      expect(paidResult.status, equals('confirmed'));

      final bookingAfterPaid = MockData.mockBookings.firstWhere((b) => b.id == 'bk-out-of-order-1');
      expect(bookingAfterPaid.status, equals('confirmed'));
      expect(bookingAfterPaid.isPaid, isTrue);

      // 2. Delayed/out-of-order event: payment.failed arrives LATER
      final failedPayload = {
        'data': {
          'id': 'evt_failed_delayed',
          'type': 'event',
          'attributes': {
            'type': 'payment.failed',
            'livemode': false,
            'data': {
              'id': 'pay_ooo_failed',
              'type': 'payment',
              'attributes': {'reference_number': 'bk-out-of-order-1'},
            },
          },
        },
      };
      final failedBody = jsonEncode(failedPayload);
      final t2 = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final sig2 = PayMongoWebhookService.computeHmacSha256Hex(key: testSecret, data: '$t2.$failedBody');

      final failedResult = await service.processWebhookPayload(
        rawBody: failedBody,
        signatureHeader: 't=$t2,te=$sig2',
        secret: testSecret,
      );

      // Must succeed without overwriting confirmed status
      expect(failedResult.success, isTrue);
      expect(failedResult.status, equals('confirmed'),
          reason: 'State preservation guard must keep confirmed status');

      final finalBooking = MockData.mockBookings.firstWhere((b) => b.id == 'bk-out-of-order-1');
      expect(finalBooking.status, equals('confirmed'),
          reason: 'Confirmed booking must NOT be degraded to cancelled by delayed failure event');
      expect(finalBooking.isPaid, isTrue);
    });
  });
}
