import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_app/widgets/skeleton_loader.dart';

void main() {
  group('Zero-CLS Skeleton Loader Tests', () {
    testWidgets('SkeletonReservationCard renders exact structure and height',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SkeletonReservationCard(),
            ),
          ),
        ),
      );

      // Verify ShimmerSweep is present
      expect(find.byType(ShimmerSweep), findsOneWidget);
      expect(find.byType(SkeletonBlock), findsNWidgets(5));

      final reservationCardFinder = find.byType(SkeletonReservationCard);
      expect(reservationCardFinder, findsOneWidget);

      final size = tester.getSize(reservationCardFinder);
      expect(size.width, equals(800.0)); // Default test screen width
      expect(size.height, equals(191.4)); // 179.4dp card + 12dp margin pitch
    });

    testWidgets('SkeletonVenueCard renders venue details with exact pitch',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SkeletonVenueCard(),
            ),
          ),
        ),
      );

      expect(find.byType(SkeletonVenueCard), findsOneWidget);
      expect(find.byType(ShimmerSweep), findsOneWidget);
      expect(find.byType(SkeletonBlock), findsWidgets);

      final size = tester.getSize(find.byType(SkeletonVenueCard));
      expect(size.height, equals(140.0)); // 130.0dp card + 10dp margin pitch
    });

    testWidgets('ShimmerSweep animation repeats continuously',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ShimmerSweep(
              child: SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      );

      expect(find.byType(ShaderMask), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ShaderMask), findsOneWidget);
    });
  });
}
