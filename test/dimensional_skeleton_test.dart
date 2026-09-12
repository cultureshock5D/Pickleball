import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_app/models/booking_model.dart';
import 'package:pickleball_app/models/venue_model.dart';
import 'package:pickleball_app/widgets/reservation_card.dart';
import 'package:pickleball_app/widgets/skeleton_loader.dart';
import 'package:pickleball_app/widgets/venue_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleBooking = BookingModel(
    id: 'BK-CLS-001',
    userId: 'user-001',
    courtId: 'court-001',
    courtName: 'C&J Prime Court 1',
    startTime: DateTime(2026, 9, 15, 14),
    endTime: DateTime(2026, 9, 15, 15),
    status: 'confirmed',
    totalPrice: 450.0,
    createdAt: DateTime(2026, 9, 12, 10),
  );

  const sampleVenue = VenueModel(
    id: 'venue-bgc',
    name: 'BGC Pickleball Center',
    city: 'Taguig, Metro Manila',
    tag: 'PREMIUM',
    address: '26th Street, Bonifacio Global City, Taguig',
    courtCount: 6,
    courtType: 'Indoor Cushion',
    reviewCount: 312,
    priceStartingAt: 400.0,
  );

  group('Feature 10: Exact Dimensional Skeletons (CLS = 0) Tests', () {
    // -------------------------------------------------------------------------
    // Tier 1: Feature Coverage (>=5 tests)
    // -------------------------------------------------------------------------
    testWidgets('Tier 1.1: SkeletonReservationCard cardHeight is exactly 179.4dp',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SkeletonReservationCard(
                margin: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      );

      final finder = find.byType(SkeletonReservationCard);
      expect(finder, findsOneWidget);
      final size = tester.getSize(finder);
      expect(size.height, equals(SkeletonReservationCard.cardHeight));
      expect(size.height, equals(179.4));
    });

    testWidgets('Tier 1.2: SkeletonReservationCard pitch is exactly 191.4dp with default margin',
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

      final finder = find.byType(SkeletonReservationCard);
      expect(finder, findsOneWidget);
      final size = tester.getSize(finder);
      expect(size.height, equals(SkeletonReservationCard.cardPitch));
      expect(size.height, equals(191.4));
      expect(SkeletonReservationCard.cardPitch - SkeletonReservationCard.cardHeight,
          equals(SkeletonReservationCard.verticalSpacing));
      expect(SkeletonReservationCard.verticalSpacing, equals(12.0));
    });

    testWidgets('Tier 1.3: SkeletonVenueCard cardHeight is exactly 130.0dp',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SkeletonVenueCard(
                margin: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      );

      final finder = find.byType(SkeletonVenueCard);
      expect(finder, findsOneWidget);
      final size = tester.getSize(finder);
      expect(size.height, equals(SkeletonVenueCard.cardHeight));
      expect(size.height, equals(130.0));
    });

    testWidgets('Tier 1.4: SkeletonVenueCard pitch is exactly 140.0dp with default margin',
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

      final finder = find.byType(SkeletonVenueCard);
      expect(finder, findsOneWidget);
      final size = tester.getSize(finder);
      expect(size.height, equals(SkeletonVenueCard.cardPitch));
      expect(size.height, equals(140.0));
      expect(SkeletonVenueCard.cardPitch - SkeletonVenueCard.cardHeight,
          equals(SkeletonVenueCard.verticalSpacing));
      expect(SkeletonVenueCard.verticalSpacing, equals(10.0));
    });

    testWidgets('Tier 1.5: ShimmerSweep utilizes exact luxury design tokens (#121A16, #1B2620, #CCFF00)',
        (WidgetTester tester) async {
      const shimmer = ShimmerSweep(
        child: SizedBox(width: 50, height: 50),
      );

      expect(shimmer.baseColor, equals(const Color(0xFF121A16)));
      expect(shimmer.highlightColor, equals(const Color(0xFF1B2620)));
      expect(shimmer.accentColor, equals(const Color(0xFFCCFF00)));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: shimmer,
          ),
        ),
      );

      expect(find.byType(ShaderMask), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Tier 2: Boundary & Corner Cases (>=5 tests)
    // -------------------------------------------------------------------------
    testWidgets('Tier 2.1: Transition from SkeletonReservationCard to ReservationCard yields CLS = 0',
        (WidgetTester tester) async {
      bool loaded = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      if (!loaded)
                        const SkeletonReservationCard(
                          
                        )
                      else
                        ReservationCard(
                          booking: sampleBooking,
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        ),
                      const SizedBox(
                        key: Key('sentinel_bottom_widget'),
                        height: 50,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );

      // Measure skeleton size and bottom sentinel position
      final skeletonSize = tester.getSize(find.byType(SkeletonReservationCard));
      final sentinelPosBefore = tester.getTopLeft(find.byKey(const Key('sentinel_bottom_widget')));

      // Swap to loaded ReservationCard
      final state = tester.state(find.byType(StatefulBuilder));
      // ignore: invalid_use_of_protected_member
      state.setState(() {
        loaded = true;
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final cardSize = tester.getSize(find.byType(ReservationCard));
      final sentinelPosAfter = tester.getTopLeft(find.byKey(const Key('sentinel_bottom_widget')));

      // Cumulative Layout Shift Assertions
      final deltaHeight = (cardSize.height - skeletonSize.height).abs();
      final deltaTopShift = (sentinelPosAfter.dy - sentinelPosBefore.dy).abs();

      expect(deltaHeight, equals(0.0), reason: 'Card height delta must be exactly 0 (CLS = 0)');
      expect(deltaTopShift, equals(0.0), reason: 'Downward layout shift must be 0 (CLS = 0)');
      expect(cardSize.height, equals(191.4));
      expect(skeletonSize.height, equals(191.4));
    });

    testWidgets('Tier 2.2: Transition from SkeletonVenueCard to VenueCard yields CLS = 0',
        (WidgetTester tester) async {
      bool loaded = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      if (!loaded)
                        const SkeletonVenueCard(
                          
                        )
                      else
                        const VenueCard(
                          venue: sampleVenue,
                        ),
                      const SizedBox(
                        key: Key('sentinel_bottom_venue'),
                        height: 40,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );

      final skeletonSize = tester.getSize(find.byType(SkeletonVenueCard));
      final sentinelBefore = tester.getTopLeft(find.byKey(const Key('sentinel_bottom_venue')));

      final state = tester.state(find.byType(StatefulBuilder));
      // ignore: invalid_use_of_protected_member
      state.setState(() {
        loaded = true;
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final cardSize = tester.getSize(find.byType(VenueCard));
      final sentinelAfter = tester.getTopLeft(find.byKey(const Key('sentinel_bottom_venue')));

      final deltaHeight = (cardSize.height - skeletonSize.height).abs();
      final deltaShift = (sentinelAfter.dy - sentinelBefore.dy).abs();

      expect(deltaHeight, equals(0.0), reason: 'VenueCard height delta must be 0 (CLS = 0)');
      expect(deltaShift, equals(0.0), reason: 'Sentinel shift must be 0 (CLS = 0)');
      expect(cardSize.height, equals(140.0));
      expect(skeletonSize.height, equals(140.0));
    });

    testWidgets('Tier 2.3: Custom height and margin overrides behave deterministically',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  SkeletonReservationCard(
                    height: 200.0,
                    margin: EdgeInsets.all(10),
                  ),
                  SkeletonVenueCard(
                    height: 150.0,
                    margin: EdgeInsets.all(8),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final reservationSize = tester.getSize(find.byType(SkeletonReservationCard));
      final venueSize = tester.getSize(find.byType(SkeletonVenueCard));

      // 200 + 10*2 = 220
      expect(reservationSize.height, equals(220.0));
      // 150 + 8*2 = 166
      expect(venueSize.height, equals(166.0));
    });

    testWidgets('Tier 2.4: ShimmerSweep disposes AnimationController cleanly without ticker leak',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ShimmerSweep(
              child: SizedBox(width: 50, height: 50),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(ShimmerSweep), findsOneWidget);

      // Remove from tree to verify dispose
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox.shrink(),
          ),
        ),
      );

      expect(find.byType(ShimmerSweep), findsNothing);
      // No FlutterError thrown
    });

    testWidgets('Tier 2.5: Multi-card list stacking maintains exact cumulative pitch (N * pitch)',
        (WidgetTester tester) async {
      const int cardCount = 4;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              itemCount: cardCount,
              itemBuilder: (context, index) => const SkeletonReservationCard(),
            ),
          ),
        ),
      );

      expect(find.byType(SkeletonReservationCard), findsNWidgets(cardCount));

      for (int i = 0; i < cardCount; i++) {
        final cardFinder = find.byType(SkeletonReservationCard).at(i);
        final size = tester.getSize(cardFinder);
        expect(size.height, equals(SkeletonReservationCard.cardPitch));
        final topLeft = tester.getTopLeft(cardFinder);
        expect(topLeft.dy, equals(i * SkeletonReservationCard.cardPitch));
      }
    });

    // -------------------------------------------------------------------------
    // Tier 3: Cross-Feature Combinations
    // -------------------------------------------------------------------------
    testWidgets('Tier 3.1: Stacked multi-card skeleton to multi-card loaded transition has zero cumulative shift',
        (WidgetTester tester) async {
      bool loaded = false;
      final bookings = List.generate(
        3,
        (i) => sampleBooking.copyWith(id: 'BK-MULTI-$i'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return ListView.builder(
                  itemCount: bookings.length,
                  itemBuilder: (context, index) {
                    if (!loaded) {
                      return const SkeletonReservationCard();
                    }
                    return ReservationCard(
                      booking: bookings[index],
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    );
                  },
                );
              },
            ),
          ),
        ),
      );

      final List<Rect> skeletonBounds = [];
      for (int i = 0; i < bookings.length; i++) {
        skeletonBounds.add(tester.getRect(find.byType(SkeletonReservationCard).at(i)));
      }

      final state = tester.state(find.byType(StatefulBuilder));
      // ignore: invalid_use_of_protected_member
      state.setState(() {
        loaded = true;
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final List<Rect> cardBounds = [];
      for (int i = 0; i < bookings.length; i++) {
        cardBounds.add(tester.getRect(find.byType(ReservationCard).at(i)));
      }

      for (int i = 0; i < bookings.length; i++) {
        expect(cardBounds[i].top, equals(skeletonBounds[i].top));
        expect(cardBounds[i].height, equals(skeletonBounds[i].height));
        expect(cardBounds[i].width, equals(skeletonBounds[i].width));
      }
    });

    // -------------------------------------------------------------------------
    // Tier 4: Real-World Application Scenarios
    // -------------------------------------------------------------------------
    testWidgets('Tier 4.1: Viewport scroll offset remains steady during skeleton-to-card transition',
        (WidgetTester tester) async {
      final scrollController = ScrollController();
      bool isLoaded = false;
      final venues = List.generate(
        10,
        (i) => sampleVenue.copyWith(id: 'venue-$i', name: 'Venue $i'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return ListView.builder(
                  controller: scrollController,
                  itemCount: venues.length,
                  itemBuilder: (context, index) {
                    if (!isLoaded) {
                      return const SkeletonVenueCard();
                    }
                    return VenueCard(venue: venues[index]);
                  },
                );
              },
            ),
          ),
        ),
      );

      // Scroll down by 280dp (exactly 2 venue pitches)
      scrollController.jumpTo(280.0);
      await tester.pump();

      expect(scrollController.offset, equals(280.0));

      // Swap to loaded items
      final state = tester.state(find.byType(StatefulBuilder));
      // ignore: invalid_use_of_protected_member
      state.setState(() {
        isLoaded = true;
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Scroll position must remain rock-solid at 280.0dp
      expect(scrollController.offset, equals(280.0));
      scrollController.dispose();
    });
  });
}
