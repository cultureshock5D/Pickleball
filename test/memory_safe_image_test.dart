import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_app/widgets/memory_safe_image.dart';

void main() {
  group('MemorySafeImage Tests', () {
    testWidgets('Renders error placeholder when imageUrl is null',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MemorySafeImage(imageUrl: null, width: 100, height: 100),
          ),
        ),
      );

      expect(find.byIcon(Icons.sports_tennis_rounded), findsOneWidget);
    });

    testWidgets('Renders error placeholder when imageUrl is empty',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MemorySafeImage(imageUrl: '   ', width: 100, height: 100),
          ),
        ),
      );

      expect(find.byIcon(Icons.sports_tennis_rounded), findsOneWidget);
    });

    testWidgets('Renders image widget with default memory constraints',
        (WidgetTester tester) async {
      const widget = MemorySafeImage(
        imageUrl: 'https://images.unsplash.com/photo-court',
        width: 300,
        height: 200,
      );

      expect(widget.memCacheWidth, equals(600));
      expect(widget.memCacheHeight, equals(400));
      expect(widget.maxWidthDiskCache, equals(1200));
      expect(widget.maxHeightDiskCache, equals(800));
    });
  });
}
