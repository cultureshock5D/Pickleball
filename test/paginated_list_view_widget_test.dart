import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_app/core/pagination/keyset_cursor.dart';
import 'package:pickleball_app/core/pagination/pagination_controller.dart';
import 'package:pickleball_app/widgets/paginated_list_view.dart';
import 'package:pickleball_app/widgets/skeleton_loader.dart';

void main() {
  group('PaginatedListView Widget Tests', () {
    testWidgets('Renders skeleton placeholders on PaginationInitialLoading',
        (WidgetTester tester) async {
      final controller = PaginationController<String>(
        fetchPageChunk: (cursor, pageSize) async => const PageChunk(
          items: [],
          hasMore: false,
        ),
        idExtractor: (s) => s,
        autoLoad: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaginatedListView<String>(
              controller: controller,
              itemBuilder: (context, item, index) => Text(item),
            ),
          ),
        ),
      );

      expect(find.byType(SkeletonReservationCard), findsNWidgets(4));
    });

    testWidgets('Renders items when ContentLoaded', (WidgetTester tester) async {
      final controller = PaginationController<String>(
        fetchPageChunk: (cursor, pageSize) async => PageChunk(
          items: const ['Item 1', 'Item 2', 'Item 3'],
          nextCursor: KeysetCursor(createdAt: DateTime.now(), id: '3'),
          hasMore: true,
        ),
        idExtractor: (s) => s,
        autoLoad: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaginatedListView<String>(
              controller: controller,
              itemBuilder: (context, item, index) => ListTile(title: Text(item)),
            ),
          ),
        ),
      );

      await controller.initialLoad();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
      expect(find.text('Item 3'), findsOneWidget);
      expect(find.byType(SkeletonReservationCard), findsNothing);
    });

    testWidgets('Renders full-screen error and retries on press',
        (WidgetTester tester) async {
      int callCount = 0;
      final controller = PaginationController<String>(
        fetchPageChunk: (cursor, pageSize) async {
          callCount++;
          if (callCount == 1) {
            throw const FormatException('Initial payload corrupt');
          }
          return const PageChunk(
            items: ['Recovered Item'],
            hasMore: false,
          );
        },
        idExtractor: (s) => s,
        autoLoad: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaginatedListView<String>(
              controller: controller,
              itemBuilder: (context, item, index) => Text(item),
            ),
          ),
        ),
      );

      await controller.initialLoad();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Unable to Load Data'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Recovered Item'), findsOneWidget);
      expect(find.text('Unable to Load Data'), findsNothing);
    });

    testWidgets('Renders inline footer error with loaded items preserved',
        (WidgetTester tester) async {
      int chunkCount = 0;
      final controller = PaginationController<String>(
        fetchPageChunk: (cursor, pageSize) async {
          chunkCount++;
          if (chunkCount == 1) {
            return PageChunk(
              items: const ['Item 1', 'Item 2'],
              nextCursor: KeysetCursor(createdAt: DateTime.now(), id: '2'),
              hasMore: true,
            );
          }
          throw const FormatException('Chunk format error');
        },
        idExtractor: (s) => s,
        autoLoad: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaginatedListView<String>(
              controller: controller,
              itemBuilder: (context, item, index) => ListTile(title: Text(item)),
            ),
          ),
        ),
      );

      await controller.initialLoad();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);

      // Trigger next chunk failure
      await controller.fetchNextChunk();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify items remain rendered and inline error banner is visible
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
