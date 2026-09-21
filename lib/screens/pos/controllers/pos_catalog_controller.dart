import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/pos_product_model.dart';
import '../../../services/pos_service.dart';

class PosCatalogController extends ChangeNotifier {
  final PosService _posService;
  StreamSubscription<void>? _realtimeSub;

  PosCatalogController({PosService? posService})
      : _posService = posService ?? PosService.instance {
    _posService.initRealtimeSubscription();
    _realtimeSub = _posService.onPosUpdates.listen((_) {
      loadCatalog();
    });
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    super.dispose();
  }

  List<PosProductModel> _allProducts = [];
  bool _isLoading = false;
  String? _error;

  String _selectedDepartment = 'All';
  String _selectedCategory = 'All';
  String _searchQuery = '';
  bool _isGridView = true;

  List<PosProductModel> get allProducts => _allProducts;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get selectedDepartment => _selectedDepartment;
  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  bool get isGridView => _isGridView;

  static const List<String> departments = [
    'All',
    'Coffee',
    'Drinks',
    'Food',
    'Supplies',
  ];

  /// Get total item count for a given department
  int getDepartmentCount(String dept) {
    if (dept == 'All') return _allProducts.length;
    return _allProducts.where((p) => p.department == dept).length;
  }

  /// Get item count for a given category within current department
  int getCategoryCount(String cat) {
    if (cat == 'All') {
      return _selectedDepartment == 'All'
          ? _allProducts.length
          : _allProducts.where((p) => p.department == _selectedDepartment).length;
    }
    final inDept = _selectedDepartment == 'All'
        ? _allProducts
        : _allProducts.where((p) => p.department == _selectedDepartment);
    return inDept.where((p) => p.category == cat).length;
  }

  /// Available sub-categories for current selected department
  List<String> get availableCategories {
    final filteredByDept = _selectedDepartment == 'All'
        ? _allProducts
        : _allProducts.where((p) => p.department == _selectedDepartment).toList();

    final cats = filteredByDept.map((p) => p.category).toSet().toList();
    cats.sort();
    return ['All', ...cats];
  }

  /// Products filtered by department, category, and search query
  List<PosProductModel> get filteredProducts {
    return _allProducts.where((p) {
      // Department filter
      if (_selectedDepartment != 'All' && p.department != _selectedDepartment) {
        return false;
      }
      // Category chip filter
      if (_selectedCategory != 'All' && p.category != _selectedCategory) {
        return false;
      }
      // Search query (matches name, SKU, or category)
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesName = p.name.toLowerCase().contains(q);
        final matchesSku = p.sku != null && p.sku!.toLowerCase().contains(q);
        final matchesCategory = p.category.toLowerCase().contains(q);
        if (!matchesName && !matchesSku && !matchesCategory) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Future<void> loadCatalog() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _allProducts = await _posService.fetchProducts();
    } catch (e) {
      _error = 'Failed to load catalog: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectDepartment(String department) {
    if (_selectedDepartment != department) {
      _selectedDepartment = department;
      _selectedCategory = 'All'; // Reset category on department change
      notifyListeners();
    }
  }

  void selectCategory(String category) {
    if (_selectedCategory != category) {
      _selectedCategory = category;
      notifyListeners();
    }
  }

  void updateSearch(String query) {
    _searchQuery = query.trim();
    notifyListeners();
  }

  void toggleViewMode() {
    _isGridView = !_isGridView;
    notifyListeners();
  }

  void setGridView(bool grid) {
    if (_isGridView != grid) {
      _isGridView = grid;
      notifyListeners();
    }
  }
}
