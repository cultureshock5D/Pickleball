import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_app/screens/pos/controllers/pos_catalog_controller.dart';
import 'package:pickleball_app/services/pos_service.dart';

void main() {
  group('PosCatalogController Filtering & Navigation Tests', () {
    late PosCatalogController controller;

    setUp(() {
      controller = PosCatalogController(posService: PosService.instance);
    });

    tearDown(() {
      controller.dispose();
    });

    test('Initial state loads products across all departments', () async {
      await controller.loadCatalog();

      expect(controller.allProducts.isNotEmpty, isTrue);
      expect(controller.selectedDepartment, 'All');
      expect(controller.filteredProducts.length, controller.allProducts.length);
    });

    test('Department filtering filters products properly', () async {
      await controller.loadCatalog();

      controller.selectDepartment('Coffee');
      expect(controller.selectedDepartment, 'Coffee');
      for (final p in controller.filteredProducts) {
        expect(p.department, 'Coffee');
      }

      controller.selectDepartment('Drinks');
      for (final p in controller.filteredProducts) {
        expect(p.department, 'Drinks');
      }

      controller.selectDepartment('Food');
      for (final p in controller.filteredProducts) {
        expect(p.department, 'Food');
      }

      controller.selectDepartment('Supplies');
      for (final p in controller.filteredProducts) {
        expect(p.department, 'Supplies');
      }
    });

    test('Category chip filtering narrows within department', () async {
      await controller.loadCatalog();

      controller.selectDepartment('Coffee');
      final availableCats = controller.availableCategories;
      expect(availableCats.contains('All'), isTrue);
      expect(availableCats.contains('Coffee'), isTrue);

      controller.selectCategory('Coffee');
      for (final p in controller.filteredProducts) {
        expect(p.category, 'Coffee');
      }
    });

    test('Instant search filters by product name or SKU', () async {
      await controller.loadCatalog();

      controller.updateSearch('Americano');
      expect(controller.filteredProducts.isNotEmpty, isTrue);
      for (final p in controller.filteredProducts) {
        expect(
          p.name.toLowerCase().contains('americano') ||
              (p.sku != null && p.sku!.toLowerCase().contains('americano')),
          isTrue,
        );
      }

      controller.updateSearch('NONEXISTENT-ITEM-XYZ');
      expect(controller.filteredProducts.isEmpty, isTrue);
    });

    test('Grid view / Table view toggle flips isGridView', () {
      expect(controller.isGridView, isTrue);
      controller.toggleViewMode();
      expect(controller.isGridView, isFalse);
      controller.setGridView(true);
      expect(controller.isGridView, isTrue);
    });

    test('Loads complete migrated 87 items catalog and categories', () async {
      await controller.loadCatalog();

      expect(controller.allProducts.length, 87);

      final categories = controller.allProducts.map((p) => p.category).toSet();
      expect(categories, containsAll([
        'Coffee',
        'Decaf Coffee',
        'Non-Coffee & Tea',
        'Fruit Shakes',
        'Beverages & Hydration',
        'Silog Meals',
        'Snacks & Dimsum',
        'Noodles & Pasta',
        'Rice & Add-ons',
        'Bar Supplies',
        'Kitchen Supplies',
      ]));

      // Verify specific sample items exist with correct pricing
      final longBlack = controller.allProducts.firstWhere((p) => p.sku == '00-01');
      expect(longBlack.name, 'Long Black');
      expect(longBlack.price, 110.0);
      expect(longBlack.costPrice, 55.0);

      final baconsilog = controller.allProducts.firstWhere((p) => p.sku == 'K00-01');
      expect(baconsilog.name, 'Baconsilog');
      expect(baconsilog.price, 140.0);
      expect(baconsilog.costPrice, 70.0);
    });
  });
}
