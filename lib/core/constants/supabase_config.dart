import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  SupabaseConfig._();

  static const String _defaultUrl = 'https://zqvpydrrmololjkvlzan.supabase.co';
  static const String _defaultAnonKey =
      'sb_publishable_iSXHHAyFAJJ6Vjsz3fAlZA_0asyUj5H';

  /// Supabase project URL loaded from .env, --dart-define, or fallback constant.
  static String get url {
    try {
      if (dotenv.isInitialized) {
        final val = dotenv.maybeGet('SUPABASE_URL');
        if (val != null && val.trim().isNotEmpty) {
          return val.trim();
        }
      }
    } catch (_) {}

    const envVal = String.fromEnvironment('SUPABASE_URL');
    if (envVal.isNotEmpty) {
      return envVal.trim();
    }

    return _defaultUrl;
  }

  /// Supabase publishable / anon key loaded from .env, --dart-define, or fallback constant.
  static String get anonKey {
    try {
      if (dotenv.isInitialized) {
        final val = dotenv.maybeGet('SUPABASE_PUB_KEY') ??
            dotenv.maybeGet('SUPABASE_ANON_KEY');
        if (val != null && val.trim().isNotEmpty) {
          return val.trim();
        }
      }
    } catch (_) {}

    const envPubKey = String.fromEnvironment('SUPABASE_PUB_KEY');
    if (envPubKey.isNotEmpty) {
      return envPubKey.trim();
    }

    const envAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (envAnonKey.isNotEmpty) {
      return envAnonKey.trim();
    }

    return _defaultAnonKey;
  }

  /// Whether Supabase configuration is present and valid
  static bool get isConfigured {
    final currentUrl = url;
    final currentKey = anonKey;
    final parsedUri = Uri.tryParse(currentUrl);
    final isValidUrl = parsedUri != null &&
        parsedUri.hasScheme &&
        parsedUri.host.isNotEmpty &&
        !currentUrl.contains('your-project');

    return isValidUrl &&
        currentKey.isNotEmpty &&
        !currentKey.contains('your-anon-key');
  }
}
