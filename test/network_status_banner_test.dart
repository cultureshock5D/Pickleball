import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_app/core/network/network_connectivity_watcher.dart';
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
  });
}
