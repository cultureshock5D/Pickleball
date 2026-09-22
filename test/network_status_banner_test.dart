import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_app/core/network/network_connectivity_watcher.dart';
import 'package:pickleball_app/services/connectivity_service.dart';
import 'package:pickleball_app/widgets/network_status_banner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NetworkStatusOverlay Widget Tests', () {
    late FakeNetworkConnectivityWatcher fakeWatcher;

    setUp(() {
      fakeWatcher = FakeNetworkConnectivityWatcher();
    });

    tearDown(() {
      fakeWatcher.dispose();
    });

    testWidgets('Renders child content normally when network is online', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NetworkStatusOverlay(
            connectivityWatcher: fakeWatcher,
            child: const Scaffold(
              body: Text('C&J Championship Arena'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('C&J Championship Arena'), findsOneWidget);
      // Banner opacity should be 0.0 when connected initially
      final opacityFinder = find.byType(AnimatedOpacity);
      expect(opacityFinder, findsOneWidget);
      final AnimatedOpacity opacityWidget = tester.widget(opacityFinder);
      expect(opacityWidget.opacity, 0.0);
    });

    testWidgets('Shows offline pill immediately if starting offline', (tester) async {
      final offlineWatcher = FakeNetworkConnectivityWatcher(initialConnected: false);

      await tester.pumpWidget(
        MaterialApp(
          home: NetworkStatusOverlay(
            connectivityWatcher: offlineWatcher,
            child: const Scaffold(
              body: Text('Main Screen'),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text("You're offline • Showing cached data"), findsOneWidget);
      final AnimatedOpacity opacityWidget = tester.widget(find.byType(AnimatedOpacity));
      expect(opacityWidget.opacity, 1.0);

      offlineWatcher.dispose();
    });

    testWidgets('Transitions to offline pill when connection is lost', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NetworkStatusOverlay(
            connectivityWatcher: fakeWatcher,
            child: const Scaffold(
              body: Text('Main Screen'),
            ),
          ),
        ),
      );
      await tester.pump();

      // Drop connection
      fakeWatcher.setConnected(false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text("You're offline • Showing cached data"), findsOneWidget);
      final AnimatedOpacity opacityWidget = tester.widget(find.byType(AnimatedOpacity));
      expect(opacityWidget.opacity, 1.0);
    });

    testWidgets('Shows "Back online" pill and auto-dismisses after reconnect', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NetworkStatusOverlay(
            connectivityWatcher: fakeWatcher,
            autoDismissDelay: const Duration(seconds: 2),
            child: const Scaffold(
              body: Text('Main Screen'),
            ),
          ),
        ),
      );
      await tester.pump();

      // Drop connection
      fakeWatcher.setConnected(false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text("You're offline • Showing cached data"), findsOneWidget);

      // Restore connection
      fakeWatcher.setConnected(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Back online • Syncing data'), findsOneWidget);
      AnimatedOpacity opacityWidget = tester.widget(find.byType(AnimatedOpacity));
      expect(opacityWidget.opacity, 1.0);

      // Fast forward past auto-dismiss delay
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 400));

      opacityWidget = tester.widget(find.byType(AnimatedOpacity));
      expect(opacityWidget.opacity, 0.0);
    });

    testWidgets('NetworkStatusPill renders accessible semantic labels and icons in dark and light modes', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                NetworkStatusPill(isOffline: true),
                NetworkStatusPill(isOffline: false),
              ],
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
      expect(find.byIcon(Icons.wifi_rounded), findsOneWidget);
      expect(find.text("You're offline • Showing cached data"), findsOneWidget);
      expect(find.text('Back online • Syncing data'), findsOneWidget);
    });

    testWidgets('NetworkStatusPill renders 3-state POS sync pills with icons and spinners', (tester) async {
      var retryTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  const NetworkStatusPill(
                    isOffline: true,
                    syncState: SyncState.idle,
                  ),
                  const NetworkStatusPill(
                    isOffline: false,
                    syncState: SyncState.syncing,
                  ),
                  const NetworkStatusPill(
                    isOffline: false,
                    syncState: SyncState.idle,
                  ),
                  NetworkStatusPill(
                    isOffline: false,
                    syncState: SyncState.error,
                    errorMessage: 'Connection timed out',
                    onRetry: () {
                      retryTapped = true;
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // 1. Offline persistent banner
      expect(
        find.text('Offline Mode — Transactions saving locally to SQLite'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);

      // 2. Syncing transient banner with spinner
      expect(
        find.text('Online — Syncing pending records to Supabase...'),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // 3. Synced confirmation banner
      expect(find.text('Connected & Synced'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

      // 4. Sync error with manual retry tap action
      expect(
        find.text('Sync issue: Connection timed out • Tap to retry'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.sync_problem_rounded), findsOneWidget);

      await tester.tap(find.text('Sync issue: Connection timed out • Tap to retry'));
      expect(retryTapped, isTrue);
    });

    testWidgets('NetworkStatusPill renders compact circular logos without text labels', (tester) async {
      var offlineTapped = false;
      var onlineTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                NetworkStatusPill(
                  isOffline: true,
                  isCompact: true,
                  onTap: () => offlineTapped = true,
                ),
                NetworkStatusPill(
                  isOffline: false,
                  isCompact: true,
                  onTap: () => onlineTapped = true,
                ),
              ],
            ),
          ),
        ),
      );

      // Offline compact: only the cloud slash logo, no text
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
      expect(find.text("You're offline • Showing cached data"), findsNothing);

      // Online compact: cloud with green background logo, no text
      expect(find.byIcon(Icons.cloud_rounded), findsOneWidget);
      expect(find.text('Back online • Syncing data'), findsNothing);

      // Verify tap callbacks work on compact badges
      await tester.tap(find.byIcon(Icons.cloud_off_rounded));
      expect(offlineTapped, isTrue);

      await tester.tap(find.byIcon(Icons.cloud_rounded));
      expect(onlineTapped, isTrue);
    });

    testWidgets('Overlay collapses to compact cloud slash logo after 5 seconds of offline', (tester) async {
      final offlineWatcher = FakeNetworkConnectivityWatcher(initialConnected: false);

      await tester.pumpWidget(
        MaterialApp(
          home: NetworkStatusOverlay(
            connectivityWatcher: offlineWatcher,
            child: const Scaffold(
              body: Text('Main Screen'),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Initially expanded: text is visible
      expect(find.text("You're offline • Showing cached data"), findsOneWidget);

      // Advance time by 5 seconds
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 400));

      // After 5 seconds: text is gone, compact cloud slash logo is visible
      expect(find.text("You're offline • Showing cached data"), findsNothing);
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);

      // Tapping the compact logo expands it again
      await tester.tap(find.byIcon(Icons.cloud_off_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text("You're offline • Showing cached data"), findsOneWidget);

      offlineWatcher.dispose();
    });
  });
}

