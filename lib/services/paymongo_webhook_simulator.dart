import 'dart:convert';
import '../core/constants/paymongo_config.dart';
import 'paymongo_webhook_service.dart';

/// Container for an authentically signed PayMongo webhook payload and its matching header
class SignedWebhookPayload {
  final String rawBody;
  final String signatureHeader;
  final String eventId;
  final String eventType;
  final int timestamp;
  final Map<String, dynamic> payloadMap;

  const SignedWebhookPayload({
    required this.rawBody,
    required this.signatureHeader,
    required this.eventId,
    required this.eventType,
    required this.timestamp,
    required this.payloadMap,
  });

  @override
  String toString() =>
      'SignedWebhookPayload(eventId: $eventId, eventType: $eventType, timestamp: $timestamp)';
}

/// Simulator for generating and dispatching signed PayMongo webhook payloads for local,
/// offline, and test verification.
class PayMongoWebhookSimulator {
  PayMongoWebhookSimulator._();

  static const String defaultTestSecret = 'whsk_test_mock_secret_key_12345';

  /// Sign an arbitrary PayMongo event data map into an RFC-compliant JSON payload and header
  static SignedWebhookPayload createSignedPayload({
    required Map<String, dynamic> eventData,
    String? secret,
    int? timestamp,
    bool isLive = false,
  }) {
    final rawBody = jsonEncode(eventData);
    final t = timestamp ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);

    final resolvedSecret = (secret != null && secret.isNotEmpty)
        ? secret
        : (PayMongoConfig.isWebhookConfigured
            ? PayMongoConfig.webhookSecretKey
            : defaultTestSecret);

    final stringToSign = '$t.$rawBody';
    final signature = PayMongoWebhookService.computeHmacSha256Hex(
      key: resolvedSecret,
      data: stringToSign,
    );

    // Format header: te for test mode, li for live mode (provide both for maximum compatibility)
    final signatureHeader = isLive
        ? 't=$t,li=$signature'
        : 't=$t,te=$signature,li=$signature';

    final data = eventData['data'] as Map<String, dynamic>? ?? {};
    final eventId = data['id'] as String? ?? '';
    final attributes = data['attributes'] as Map<String, dynamic>? ?? {};
    final eventType = attributes['type'] as String? ?? '';

    return SignedWebhookPayload(
      rawBody: rawBody,
      signatureHeader: signatureHeader,
      eventId: eventId,
      eventType: eventType,
      timestamp: t,
      payloadMap: eventData,
    );
  }

  /// Generate an authentic signed webhook payload for `checkout_session.payment.paid`
  static SignedWebhookPayload simulatePaymentPaid({
    required String checkoutSessionId,
    required String bookingId,
    int amountCentavos = 30000,
    String paymentMethod = 'gcash',
    String? eventId,
    String? secret,
    int? timestamp,
    bool isLive = false,
  }) {
    final t = timestamp ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    final resolvedEventId = eventId ?? 'evt_${DateTime.now().microsecondsSinceEpoch}';
    final paymentId = 'pay_${DateTime.now().microsecondsSinceEpoch}';

    final eventPayload = {
      'data': {
        'id': resolvedEventId,
        'type': 'event',
        'attributes': {
          'type': 'checkout_session.payment.paid',
          'livemode': isLive,
          'data': {
            'id': checkoutSessionId,
            'type': 'checkout_session',
            'attributes': {
              'status': 'paid',
              'amount': amountCentavos,
              'currency': 'PHP',
              'reference_number': bookingId,
              'metadata': {
                'booking_id': bookingId,
                'checkout_session_id': checkoutSessionId,
              },
              'payments': [
                {
                  'id': paymentId,
                  'type': 'payment',
                  'attributes': {
                    'amount': amountCentavos,
                    'currency': 'PHP',
                    'status': 'paid',
                    'source': {
                      'id': 'src_${DateTime.now().millisecondsSinceEpoch}',
                      'type': paymentMethod,
                    },
                    'paid_at': t,
                  },
                }
              ],
            },
          },
          'previous_data': {},
          'created_at': t,
          'updated_at': t,
        },
      },
    };

    return createSignedPayload(
      eventData: eventPayload,
      secret: secret,
      timestamp: t,
      isLive: isLive,
    );
  }

  /// Generate an authentic signed webhook payload for `payment.failed`
  static SignedWebhookPayload simulatePaymentFailed({
    required String checkoutSessionId,
    required String bookingId,
    int amountCentavos = 30000,
    String failureCode = 'insufficient_funds',
    String failureMessage = 'Payment failed due to insufficient funds',
    String? eventId,
    String? secret,
    int? timestamp,
    bool isLive = false,
  }) {
    final t = timestamp ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    final resolvedEventId = eventId ?? 'evt_fail_${DateTime.now().microsecondsSinceEpoch}';
    final paymentId = 'pay_fail_${DateTime.now().microsecondsSinceEpoch}';

    final eventPayload = {
      'data': {
        'id': resolvedEventId,
        'type': 'event',
        'attributes': {
          'type': 'payment.failed',
          'livemode': isLive,
          'data': {
            'id': paymentId,
            'type': 'payment',
            'attributes': {
              'status': 'failed',
              'amount': amountCentavos,
              'currency': 'PHP',
              'failed_code': failureCode,
              'failed_message': failureMessage,
              'reference_number': bookingId,
              'metadata': {
                'booking_id': bookingId,
                'checkout_session_id': checkoutSessionId,
              },
            },
          },
          'previous_data': {},
          'created_at': t,
          'updated_at': t,
        },
      },
    };

    return createSignedPayload(
      eventData: eventPayload,
      secret: secret,
      timestamp: t,
      isLive: isLive,
    );
  }

  /// Directly dispatch a simulated paid webhook event to PayMongoWebhookService
  static Future<WebhookProcessResult> dispatchPaymentPaid({
    required String checkoutSessionId,
    required String bookingId,
    int amountCentavos = 30000,
    String paymentMethod = 'gcash',
    String? eventId,
    String? secret,
    int? timestamp,
    bool isLive = false,
  }) async {
    final signed = simulatePaymentPaid(
      checkoutSessionId: checkoutSessionId,
      bookingId: bookingId,
      amountCentavos: amountCentavos,
      paymentMethod: paymentMethod,
      eventId: eventId,
      secret: secret,
      timestamp: timestamp,
      isLive: isLive,
    );

    return PayMongoWebhookService.instance.processWebhookPayload(
      rawBody: signed.rawBody,
      signatureHeader: signed.signatureHeader,
      secret: secret ?? defaultTestSecret,
      currentTimestampSeconds: signed.timestamp,
    );
  }

  /// Directly dispatch a simulated failed webhook event to PayMongoWebhookService
  static Future<WebhookProcessResult> dispatchPaymentFailed({
    required String checkoutSessionId,
    required String bookingId,
    int amountCentavos = 30000,
    String failureCode = 'insufficient_funds',
    String failureMessage = 'Payment failed due to insufficient funds',
    String? eventId,
    String? secret,
    int? timestamp,
    bool isLive = false,
  }) async {
    final signed = simulatePaymentFailed(
      checkoutSessionId: checkoutSessionId,
      bookingId: bookingId,
      amountCentavos: amountCentavos,
      failureCode: failureCode,
      failureMessage: failureMessage,
      eventId: eventId,
      secret: secret,
      timestamp: timestamp,
      isLive: isLive,
    );

    return PayMongoWebhookService.instance.processWebhookPayload(
      rawBody: signed.rawBody,
      signatureHeader: signed.signatureHeader,
      secret: secret ?? defaultTestSecret,
      currentTimestampSeconds: signed.timestamp,
    );
  }
}
