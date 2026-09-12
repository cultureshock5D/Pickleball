import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'supabase_config.dart';

/// Application data source flavors.
enum AppDataFlavor {
  /// Pure local mock data repository. Used for offline development, preview, and tests.
  mock,

  /// Live Supabase Postgres backend with Realtime channel subscriptions.
  supabase,
}

/// Configuration manager for determining the current [AppDataFlavor].
class AppFlavorConfig {
  AppFlavorConfig._();

  static AppDataFlavor? _overrideFlavor;

  /// Sets an explicit runtime override for [AppDataFlavor].
  /// Pass null to revert to automatic environment/config detection.
  static void setFlavorOverride(AppDataFlavor? flavor) {
    _overrideFlavor = flavor;
  }

  /// Determines the active data flavor with the following precedence:
  /// 1. Runtime override via [setFlavorOverride]
  /// 2. Dart compile-time define `--dart-define=APP_FLAVOR=mock|supabase`
  /// 3. Environment variable `APP_FLAVOR` in `.env`
  /// 4. Auto-detection via [SupabaseConfig.isConfigured]
  static AppDataFlavor get currentFlavor {
    if (_overrideFlavor != null) {
      return _overrideFlavor!;
    }

    const dartDefineFlavor = String.fromEnvironment('APP_FLAVOR');
    if (dartDefineFlavor.isNotEmpty) {
      if (dartDefineFlavor.trim().toLowerCase() == 'supabase') {
        return AppDataFlavor.supabase;
      }
      return AppDataFlavor.mock;
    }

    try {
      if (dotenv.isInitialized) {
        final envFlavor = dotenv.maybeGet('APP_FLAVOR');
        if (envFlavor != null && envFlavor.trim().isNotEmpty) {
          if (envFlavor.trim().toLowerCase() == 'supabase') {
            return AppDataFlavor.supabase;
          }
          return AppDataFlavor.mock;
        }
      }
    } catch (_) {}

    return SupabaseConfig.isConfigured ? AppDataFlavor.supabase : AppDataFlavor.mock;
  }

  /// Helper indicating if the app is currently running in mock data mode.
  static bool get isMock => currentFlavor == AppDataFlavor.mock;

  /// Helper indicating if the app is currently running in live Supabase mode.
  static bool get isSupabase => currentFlavor == AppDataFlavor.supabase;
}
