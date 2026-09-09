import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PayMongoConfig {
  PayMongoConfig._();

  /// PayMongo Secret Key (prefers LIVE keys from dotenv or dart-define)
  static String get secretKey {
    try {
      if (dotenv.isInitialized) {
        final val = dotenv.maybeGet('PAYMONGO_LIVE_SECRET_KEY') ??
            dotenv.maybeGet('PAYMONGO_SECRET_KEY') ??
            dotenv.maybeGet('PAYMONGO_TEST_SECRET_KEY');
        if (val != null && val.trim().isNotEmpty) {
          return val.trim();
        }
      }
    } catch (_) {}

    const envLive = String.fromEnvironment('PAYMONGO_LIVE_SECRET_KEY');
    if (envLive.isNotEmpty) return envLive.trim();

    const envSec = String.fromEnvironment('PAYMONGO_SECRET_KEY');
    if (envSec.isNotEmpty) return envSec.trim();

    const envTest = String.fromEnvironment('PAYMONGO_TEST_SECRET_KEY');
    if (envTest.isNotEmpty) return envTest.trim();

    return '';
  }

  /// PayMongo Public Key (prefers LIVE keys from dotenv or dart-define)
  static String get publicKey {
    try {
      if (dotenv.isInitialized) {
        final val = dotenv.maybeGet('PAYMONGO_LIVE_PUBLIC_KEY') ??
            dotenv.maybeGet('PAYMONGO_PUBLIC_KEY') ??
            dotenv.maybeGet('PAYMONGO_TEST_PUBLIC_KEY');
        if (val != null && val.trim().isNotEmpty) {
          return val.trim();
        }
      }
    } catch (_) {}

    const envLive = String.fromEnvironment('PAYMONGO_LIVE_PUBLIC_KEY');
    if (envLive.isNotEmpty) return envLive.trim();

    const envPub = String.fromEnvironment('PAYMONGO_PUBLIC_KEY');
    if (envPub.isNotEmpty) return envPub.trim();

    const envTest = String.fromEnvironment('PAYMONGO_TEST_PUBLIC_KEY');
    if (envTest.isNotEmpty) return envTest.trim();

    return '';
  }

  /// Basic auth header value for PayMongo REST API (`Basic base64(secretKey + ':')`)
  static String get basicAuthHeader {
    final bytes = utf8.encode('$secretKey:');
    return 'Basic ${base64Encode(bytes)}';
  }

  /// Whether PayMongo is configured with a valid key
  static bool get isConfigured => secretKey.isNotEmpty;

  /// Whether current active key is a live production key
  static bool get isLiveMode => secretKey.startsWith('sk_live_');
}
