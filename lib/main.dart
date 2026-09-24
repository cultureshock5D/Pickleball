import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/supabase_config.dart';
import 'core/services/theme_service.dart';
import 'core/theme/app_theme.dart';
import 'services/connectivity_service.dart';
import 'services/pos_database.dart';
import 'services/sync_service.dart';
import 'widgets/auth_gate.dart';
import 'widgets/network_status_banner.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env file safely
  try {
    await dotenv.load();
    debugPrint('.env file loaded successfully.');
  } catch (e) {
    debugPrint('.env load notice: $e (using environment/default config fallback)');
  }

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Supabase safely
  try {
    if (SupabaseConfig.isConfigured) {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.publishableKey,
        debug: kDebugMode,
      );
      debugPrint('Supabase successfully initialized with URL: ${SupabaseConfig.url}');
    } else {
      debugPrint(
        'Supabase is not configured with valid credentials.',
      );
    }
  } catch (e) {
    debugPrint('Supabase initialization notice: $e');
  }

  // Initialize offline SQLite POS database, immediate sync pipeline, and connectivity watcher
  try {
    await PosDatabase.instance.initialize();
    SyncService.instance.initialize();
    await ConnectivityService.instance.initialize();
  } catch (e) {
    debugPrint('Offline POS & Connectivity init notice: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeService.instance,
      builder: (context, _) {
        final isDark = ThemeService.instance.isDarkMode(context);

        // Update system chrome overlay style based on current theme mode
        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarColor: isDark ? AppTheme.darkPalette.background : AppTheme.lightPalette.background,
            systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          ),
        );

        return MaterialApp(
          title: 'C&J',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeService.instance.themeMode,
          scrollBehavior: const MaterialScrollBehavior().copyWith(
            dragDevices: {
              PointerDeviceKind.mouse,
              PointerDeviceKind.touch,
              PointerDeviceKind.trackpad,
              PointerDeviceKind.stylus,
            },
          ),
          builder: (context, child) => NetworkStatusOverlay(
            child: child ?? const SizedBox.shrink(),
          ),
          home: const AuthGate(),
        );
      },
    );
  }
}
