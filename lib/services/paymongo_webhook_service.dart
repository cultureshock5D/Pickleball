import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/paymongo_config.dart';
import '../data/mock_data.dart';
import '../models/booking_model.dart';
import 'booking_service.dart';

// ============================================================================
// Realtime Event Contracts (PROJECT.md Interface Specification)
// Canonical types defined in booking_service.dart are re-exported here
// ============================================================================

export 'booking_service.dart'
    show BookingRealtimeEventType, BookingRealtimeEvent;

/// Extension equipping BookingService with realtime event dispatch alias
extension BookingServiceRealtimeExtension on BookingService {
  /// Dispatch a realtime booking event to UI listeners and invalidate availability cache
  void dispatchRealtimeEvent(BookingRealtimeEvent event) {
    broadcastMockBookingEvent(event);
  }
}

// ============================================================================
// Webhook Processing Result
// ============================================================================

class WebhookProcessResult {
  final bool success;
  final String eventId;
  final String? bookingId;
  final String status;
  final String message;
  final bool isDuplicate;
  final String? eventType;

  const WebhookProcessResult({
    required this.success,
    required this.eventId,
    this.bookingId,
    required this.status,
    required this.message,
    this.isDuplicate = false,
    this.eventType,
  });

  @override
  String toString() =>
      'WebhookProcessResult(success: $success, eventId: $eventId, bookingId: $bookingId, status: $status, isDuplicate: $isDuplicate, message: $message)';
}

// ============================================================================
// PayMongo Webhook Service
// ============================================================================

class PayMongoWebhookService {
  PayMongoWebhookService._internal();
  static final PayMongoWebhookService instance = PayMongoWebhookService._internal();

  /// In-memory deduplication set tracking processed PayMongo event IDs (e.g. 'evt_...')
  final Set<String> _processedEventIds = <String>{};

  /// Check whether an event ID has already been recorded/processed
  bool isEventProcessed(String eventId) => _processedEventIds.contains(eventId);

  /// Mark an event ID as processed
  void markEventProcessed(String eventId) => _processedEventIds.add(eventId);

  /// Clear in-memory deduplication cache (useful for test resets)
  void clearProcessedEvents() => _processedEventIds.clear();

  /// Get the number of currently tracked processed events
  int get processedEventsCount => _processedEventIds.length;

  SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  // ==========================================================================
  // Cryptographic Operations: Pure Dart SHA-256 and HMAC-SHA256 (FIPS 180-4)
  // ==========================================================================

  static const List<int> _k = <int>[
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
    0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
    0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
    0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
  ];

  static int _rotr32(int x, int n) =>
      (((x & 0xFFFFFFFF) >>> n) | ((x << (32 - n)) & 0xFFFFFFFF)) & 0xFFFFFFFF;

  static int _shr32(int x, int n) => (x & 0xFFFFFFFF) >>> n;

  /// Pure Dart SHA-256 implementation conforming to FIPS 180-4
  static Uint8List sha256(List<int> message) {
    int h0 = 0x6a09e667;
    int h1 = 0xbb67ae85;
    int h2 = 0x3c6ef372;
    int h3 = 0xa54ff53a;
    int h4 = 0x510e527f;
    int h5 = 0x9b05688c;
    int h6 = 0x1f83d9ab;
    int h7 = 0x5be0cd19;

    final msgLen = message.length;
    final bitLen = msgLen * 8;
    final padZeros = (56 - ((msgLen + 1) % 64)) % 64;
    final totalLen = msgLen + 1 + padZeros + 8;

    final padded = Uint8List(totalLen);
    padded.setRange(0, msgLen, message);
    padded[msgLen] = 0x80;

    final byteData = ByteData.sublistView(padded);
    final highBits = (bitLen ~/ 0x100000000) & 0xFFFFFFFF;
    final lowBits = bitLen & 0xFFFFFFFF;
    byteData.setUint32(totalLen - 8, highBits);
    byteData.setUint32(totalLen - 4, lowBits);

    final w = Uint32List(64);

    for (int offset = 0; offset < totalLen; offset += 64) {
      for (int t = 0; t < 16; t++) {
        w[t] = byteData.getUint32(offset + (t * 4));
      }
      for (int t = 16; t < 64; t++) {
        final s0 = _rotr32(w[t - 15], 7) ^
            _rotr32(w[t - 15], 18) ^
            _shr32(w[t - 15], 3);
        final s1 = _rotr32(w[t - 2], 17) ^
            _rotr32(w[t - 2], 19) ^
            _shr32(w[t - 2], 10);
        w[t] = (w[t - 16] + s0 + w[t - 7] + s1) & 0xFFFFFFFF;
      }

      int a = h0;
      int b = h1;
      int c = h2;
      int d = h3;
      int e = h4;
      int f = h5;
      int g = h6;
      int h = h7;

      for (int t = 0; t < 64; t++) {
        final s1 = _rotr32(e, 6) ^ _rotr32(e, 11) ^ _rotr32(e, 25);
        final ch = (e & f) ^ ((~e) & g);
        final temp1 = (h + s1 + ch + _k[t] + w[t]) & 0xFFFFFFFF;
        final s0 = _rotr32(a, 2) ^ _rotr32(a, 13) ^ _rotr32(a, 22);
        final maj = (a & b) ^ (a & c) ^ (b & c);
        final temp2 = (s0 + maj) & 0xFFFFFFFF;

        h = g;
        g = f;
        f = e;
        e = (d + temp1) & 0xFFFFFFFF;
        d = c;
        c = b;
        b = a;
        a = (temp1 + temp2) & 0xFFFFFFFF;
      }

      h0 = (h0 + a) & 0xFFFFFFFF;
      h1 = (h1 + b) & 0xFFFFFFFF;
      h2 = (h2 + c) & 0xFFFFFFFF;
      h3 = (h3 + d) & 0xFFFFFFFF;
      h4 = (h4 + e) & 0xFFFFFFFF;
      h5 = (h5 + f) & 0xFFFFFFFF;
      h6 = (h6 + g) & 0xFFFFFFFF;
      h7 = (h7 + h) & 0xFFFFFFFF;
    }

    final out = Uint8List(32);
    final outBd = ByteData.sublistView(out);
    outBd.setUint32(0, h0);
    outBd.setUint32(4, h1);
    outBd.setUint32(8, h2);
    outBd.setUint32(12, h3);
    outBd.setUint32(16, h4);
    outBd.setUint32(20, h5);
    outBd.setUint32(24, h6);
    outBd.setUint32(28, h7);

    return out;
  }

  /// Pure Dart HMAC-SHA256 calculation conforming to RFC 2104
  static Uint8List hmacSha256({
    required List<int> key,
    required List<int> data,
  }) {
    Uint8List k = Uint8List.fromList(key);
    if (k.length > 64) {
      k = sha256(k);
    }
    final paddedK = Uint8List(64);
    paddedK.setRange(0, k.length, k);

    final ipad = Uint8List(64);
    final opad = Uint8List(64);
    for (int i = 0; i < 64; i++) {
      ipad[i] = paddedK[i] ^ 0x36;
      opad[i] = paddedK[i] ^ 0x5c;
    }

    final innerMsg = Uint8List(64 + data.length);
    innerMsg.setRange(0, 64, ipad);
    innerMsg.setRange(64, innerMsg.length, data);
    final innerHash = sha256(innerMsg);

    final outerMsg = Uint8List(64 + 32);
    outerMsg.setRange(0, 64, opad);
    outerMsg.setRange(64, outerMsg.length, innerHash);
    return sha256(outerMsg);
  }

  /// Compute HMAC-SHA256 hex string over UTF-8 encoded key and data
  static String computeHmacSha256Hex({
    required String key,
    required String data,
  }) {
    final keyBytes = utf8.encode(key);
    final dataBytes = utf8.encode(data);
    final hash = hmacSha256(key: keyBytes, data: dataBytes);
    return bytesToHex(hash);
  }

  /// Convert bytes into a lowercase hexadecimal string
  static String bytesToHex(List<int> bytes) {
    final buffer = StringBuffer();
    for (final b in bytes) {
      buffer.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  /// Timing-safe string comparison to prevent timing attacks
  static bool timingSafeEqual(String a, String b) {
    if (a.length != b.length) return false;
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  /// Parse the PayMongo-Signature header into its components (`t`, `te`, `li`)
  static Map<String, String> parseSignatureHeader(String header) {
    final result = <String, String>{};
    final parts = header.split(',');
    for (final part in parts) {
      final kv = part.split('=');
      if (kv.length >= 2) {
        final key = kv[0].trim();
        final value = kv.sublist(1).join('=').trim();
        if (key.isNotEmpty && value.isNotEmpty) {
          result[key] = value;
        }
      }
    }
    return result;
  }

  /// Verify HMAC-SHA256 signature and 300s freshness window against PayMongo-Signature header
  static bool verifySignature({
    required String rawBody,
    required String signatureHeader,
    required String secret,
    bool isLiveMode = false,
    int? currentTimestampSeconds,
    int toleranceSeconds = 300,
  }) {
    if (signatureHeader.isEmpty || secret.isEmpty) return false;

    final parsed = parseSignatureHeader(signatureHeader);
    final tStr = parsed['t'];
    if (tStr == null) return false;

    final t = int.tryParse(tStr);
    if (t == null) return false;

    final now = currentTimestampSeconds ??
        (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    if ((now - t).abs() > toleranceSeconds) {
      return false; // Replay prevention: outside tolerance window
    }

    final targetSig = isLiveMode
        ? (parsed['li'] ?? parsed['te'])
        : (parsed['te'] ?? parsed['li']);
    if (targetSig == null || targetSig.isEmpty) return false;

    final stringToSign = '$t.$rawBody';
    final computedSig = computeHmacSha256Hex(key: secret, data: stringToSign);

    return timingSafeEqual(computedSig.toLowerCase(), targetSig.toLowerCase());
  }

  // ==========================================================================
  // Core Webhook Processing Engine
  // ==========================================================================

  /// Process an incoming PayMongo webhook payload with cryptographic verification,
  /// idempotency enforcement, and reactive booking state transitions.
  Future<WebhookProcessResult> processWebhookPayload({
    required String rawBody,
    required String signatureHeader,
    String? secret,
    int? currentTimestampSeconds,
    bool skipSignatureVerificationForTesting = false,
  }) async {
    // 1. JSON parsing
    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(rawBody) as Map<String, dynamic>;
    } catch (e) {
      return WebhookProcessResult(
        success: false,
        eventId: '',
        status: 'malformed_json',
        message: 'Failed to decode JSON body: $e',
      );
    }

    // 2. Extract Event Envelope
    final data = payload['data'] as Map<String, dynamic>? ?? {};
    final eventId = (data['id'] as String?)?.trim() ?? '';
    if (eventId.isEmpty) {
      return const WebhookProcessResult(
        success: false,
        eventId: '',
        status: 'missing_event_id',
        message: 'Webhook payload is missing data.id',
      );
    }

    final attributes = data['attributes'] as Map<String, dynamic>? ?? {};
    final eventType = (attributes['type'] as String?)?.trim() ?? '';
    final isLive = (attributes['livemode'] as bool?) ?? false;
    final innerData = attributes['data'] as Map<String, dynamic>? ?? {};
    final resourceId = (innerData['id'] as String?)?.trim() ?? '';
    final innerAttributes = innerData['attributes'] as Map<String, dynamic>? ?? {};

    // Correlate Target Booking ID early so it is available in idempotency logs and results
    String? targetBookingId;
    final metadata = innerAttributes['metadata'] as Map<String, dynamic>?;
    if (metadata != null && metadata['booking_id'] != null) {
      targetBookingId = metadata['booking_id'].toString().trim();
    }
    if ((targetBookingId == null || targetBookingId.isEmpty) &&
        innerAttributes['reference_number'] != null) {
      targetBookingId = innerAttributes['reference_number'].toString().trim();
    }

    // 3. In-memory Idempotency Check
    if (_processedEventIds.contains(eventId)) {
      return WebhookProcessResult(
        success: true,
        eventId: eventId,
        bookingId: targetBookingId,
        status: 'duplicate',
        message: 'Event $eventId already processed (idempotent duplicate)',
        isDuplicate: true,
        eventType: eventType,
      );
    }

    // 4. Cryptographic Signature & Freshness Verification
    if (!skipSignatureVerificationForTesting) {
      final resolvedSecret = (secret != null && secret.trim().isNotEmpty)
          ? secret.trim()
          : PayMongoConfig.webhookSecretKey;

      if (resolvedSecret.isEmpty) {
        return WebhookProcessResult(
          success: false,
          eventId: eventId,
          status: 'unconfigured_secret',
          message: 'PayMongo webhook secret is unconfigured in environment',
          eventType: eventType,
        );
      }

      final parsedHeader = parseSignatureHeader(signatureHeader);
      final tStr = parsedHeader['t'];
      if (tStr == null) {
        return WebhookProcessResult(
          success: false,
          eventId: eventId,
          status: 'invalid_header',
          message: 'Missing timestamp t in Paymongo-Signature header',
          eventType: eventType,
        );
      }

      final t = int.tryParse(tStr);
      if (t == null) {
        return WebhookProcessResult(
          success: false,
          eventId: eventId,
          status: 'invalid_timestamp',
          message: 'Invalid timestamp format in Paymongo-Signature: $tStr',
          eventType: eventType,
        );
      }

      final now = currentTimestampSeconds ??
          (DateTime.now().millisecondsSinceEpoch ~/ 1000);
      if ((now - t).abs() > 300) {
        return WebhookProcessResult(
          success: false,
          eventId: eventId,
          status: 'replay_rejected',
          message:
              'Timestamp $t outside 300-second freshness tolerance window (now=$now)',
          eventType: eventType,
        );
      }

      final targetSig = isLive
          ? (parsedHeader['li'] ?? parsedHeader['te'])
          : (parsedHeader['te'] ?? parsedHeader['li']);
      if (targetSig == null || targetSig.isEmpty) {
        return WebhookProcessResult(
          success: false,
          eventId: eventId,
          status: 'missing_signature',
          message: 'Missing signature digest in Paymongo-Signature header',
          eventType: eventType,
        );
      }

      final stringToSign = '$t.$rawBody';
      final computedSig =
          computeHmacSha256Hex(key: resolvedSecret, data: stringToSign);
      if (!timingSafeEqual(computedSig.toLowerCase(), targetSig.toLowerCase())) {
        return WebhookProcessResult(
          success: false,
          eventId: eventId,
          status: 'invalid_signature',
          message: 'Cryptographic signature mismatch',
          eventType: eventType,
        );
      }
    }

    // 5. Determine Target State Transition
    String? targetStatus;
    if (eventType == 'checkout_session.payment.paid' ||
        eventType == 'payment.paid') {
      targetStatus = 'confirmed';
    } else if (eventType == 'payment.failed') {
      targetStatus = 'cancelled';
    } else {
      // Non-lifecycle event (e.g. source.chargeable): log as processed without state mutation
      _processedEventIds.add(eventId);
      return WebhookProcessResult(
        success: true,
        eventId: eventId,
        bookingId: targetBookingId,
        status: 'unhandled_event_type',
        message: 'Event $eventType received and acknowledged without mutation',
        eventType: eventType,
      );
    }

    // 7. Resolve Booking State from Supabase or MockData
    BookingModel? targetBooking;
    String? currentBookingStatus;

    if (_supabase != null) {
      try {
        // First try via targetBookingId
        if (targetBookingId != null && targetBookingId.isNotEmpty) {
          final res = await _supabase!
              .from('bookings')
              .select('*, courts(name, type, hourly_rate)')
              .eq('id', targetBookingId)
              .maybeSingle();
          if (res != null) {
            targetBooking = BookingModel.fromJson(res);
            currentBookingStatus = targetBooking.status;
          }
        }
        // If not found, try via paymongo_checkout_session_id
        if (targetBooking == null && resourceId.isNotEmpty) {
          final res = await _supabase!
              .from('bookings')
              .select('*, courts(name, type, hourly_rate)')
              .eq('paymongo_checkout_session_id', resourceId)
              .maybeSingle();
          if (res != null) {
            targetBooking = BookingModel.fromJson(res);
            targetBookingId = targetBooking.id;
            currentBookingStatus = targetBooking.status;
          }
        }
      } catch (e) {
        debugPrint('Note resolving booking from Supabase: $e');
      }
    }

    // Offline / Mock fallback resolution
    if (targetBooking == null) {
      final mocks = MockData.mockBookings;
      if (targetBookingId != null && targetBookingId.isNotEmpty) {
        final match = mocks.where((b) => b.id == targetBookingId);
        if (match.isNotEmpty) targetBooking = match.first;
      }
      if (targetBooking == null && resourceId.isNotEmpty) {
        final match = mocks.where((b) => b.paymongoCheckoutSessionId == resourceId);
        if (match.isNotEmpty) {
          targetBooking = match.first;
          targetBookingId = targetBooking.id;
        }
      }
      if (targetBooking != null) {
        currentBookingStatus = targetBooking.status;
      }
    }

    // 8. Enforce State Preservation Guard
    // If the booking is already confirmed or paid:
    if (currentBookingStatus == 'confirmed' || currentBookingStatus == 'paid') {
      _processedEventIds.add(eventId);
      if (targetStatus == 'cancelled') {
        // Never cancel or void an already confirmed booking due to a subsequent failed event
        return WebhookProcessResult(
          success: true,
          eventId: eventId,
          bookingId: targetBookingId,
          status: 'confirmed',
          message:
              'Ignored payment.failed for already confirmed booking $targetBookingId',
          eventType: eventType,
        );
      } else {
        // Idempotent retry for already confirmed booking
        return WebhookProcessResult(
          success: true,
          eventId: eventId,
          bookingId: targetBookingId,
          status: 'confirmed',
          message: 'Booking $targetBookingId already settled and confirmed',
          isDuplicate: true,
          eventType: eventType,
        );
      }
    }

    // 9. Execute State Transition in Supabase and Mock Store
    BookingModel? updatedBooking;

    // Supabase update
    if (_supabase != null && targetBookingId != null) {
      try {
        // Attempt atomic RPC if available
        try {
          await _supabase!.rpc('process_paymongo_webhook', params: {
            'p_event_id': eventId,
            'p_event_type': eventType,
            'p_resource_id': resourceId,
            'p_booking_id': targetBookingId,
            'p_payload': payload,
          });
        } catch (_) {
          // Direct table update fallback
          await _supabase!.from('bookings').update({
            'status': targetStatus,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', targetBookingId).inFilter('status', ['pending', 'pending_payment']);

          // Audit log insertion
          try {
            await _supabase!.from('payment_webhook_events').insert({
              'event_id': eventId,
              'event_type': eventType,
              'resource_id': resourceId,
              'booking_id': targetBookingId,
              'status': 'processed',
              'payload': payload,
            });
          } catch (_) {}
        }
      } catch (e) {
        debugPrint('Supabase webhook execution error: $e');
      }
    }

    // Update Mock Store for offline synchronization
    if (targetBookingId != null) {
      if (targetStatus == 'confirmed') {
        updatedBooking = MockData.markMockBookingAsPaid(
          targetBookingId,
          paymongoSessionId: resourceId.isNotEmpty ? resourceId : null,
        );
      } else if (targetStatus == 'cancelled') {
        MockData.cancelMockBooking(targetBookingId);
        if (targetBooking != null) {
          updatedBooking = targetBooking.copyWith(
            status: 'cancelled',
            updatedAt: DateTime.now(),
          );
        }
      }
    }

    updatedBooking ??= targetBooking?.copyWith(
      status: targetStatus,
      updatedAt: DateTime.now(),
    );

    // Record event as processed in memory
    _processedEventIds.add(eventId);

    // 10. Dispatch BookingRealtimeEvent to UI Subscribers
    final courtId = updatedBooking?.courtId ?? targetBooking?.courtId;
    final startTime = updatedBooking?.startTime ?? targetBooking?.startTime;

    BookingService.instance.dispatchRealtimeEvent(
      BookingRealtimeEvent(
        type: BookingRealtimeEventType.updated,
        booking: updatedBooking,
        courtId: courtId,
        startTime: startTime,
      ),
    );

    return WebhookProcessResult(
      success: true,
      eventId: eventId,
      bookingId: targetBookingId,
      status: targetStatus,
      message:
          'Successfully transitioned booking $targetBookingId to $targetStatus',
      eventType: eventType,
    );
  }
}
