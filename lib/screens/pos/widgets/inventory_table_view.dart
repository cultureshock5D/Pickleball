import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../models/pos_product_model.dart';
import '../../../services/pos_service.dart';

class InventoryTableView extends StatefulWidget {
  final VoidCallback onBackToRegister;
  final VoidCallback? onToggleMenu;

  const InventoryTableView({
    super.key,
    required this.onBackToRegister,
    this.onToggleMenu,
  });

  @override
  State<InventoryTableView> createState() => _InventoryTableViewState();
}

class _InventoryTableViewState extends State<InventoryTableView> {
  final PosService _posService = PosService.instance;
  final TextEditingController _searchController = TextEditingController();

  List<PosProductModel> _allProducts = [];
  bool _isLoading = true;
  String _selectedCategory = 'All';
  String _stockFilter = 'all'; // 'all', 'low', 'out'
  StreamSubscription<void>? _updatesSub;

  final currencyFmt = NumberFormat.currency(locale: 'en_PH', symbol: '₱');

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _updatesSub = _posService.onPosUpdates.listen((_) {
      if (mounted) _loadProducts(isSilent: true);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _updatesSub?.cancel();
    super.dispose();
  }

  Future<void> _loadProducts({bool isSilent = false}) async {
    if (!isSilent) {
      setState(() => _isLoading = true);
    }
    try {
      final products = await _posService.fetchInventoryProducts();
      if (mounted) {
        setState(() {
          _allProducts = products;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppSnackBar.error(context, 'Failed to load inventory: $e');
      }
    }
  }

  List<PosProductModel> get _filteredProducts {
    return _allProducts.where((p) {
      // Category filter
      if (_selectedCategory != 'All' &&
          p.category.toLowerCase() != _selectedCategory.toLowerCase()) {
        return false;
      }
      // Stock status filter
      if (_stockFilter == 'low' &&
          (p.stockLevel > p.reorderThreshold || p.stockLevel <= 0)) {
        return false;
      }
      if (_stockFilter == 'out' && p.stockLevel > 0) {
        return false;
      }
      // Search term
      final query = _searchController.text.trim().toLowerCase();
      if (query.isNotEmpty) {
        final matchesName = p.name.toLowerCase().contains(query);
        final matchesSku = p.sku?.toLowerCase().contains(query) ?? false;
        final matchesCat = p.category.toLowerCase().contains(query);
        if (!matchesName && !matchesSku && !matchesCat) return false;
      }
      return true;
    }).toList();
  }

  List<String> get _categories {
    final cats = _allProducts.map((p) => p.category).toSet().toList();
    cats.sort();
    return ['All', ...cats];
  }

  void _showAdjustStockDialog(PosProductModel product) {
    final palette = context.colors;
    final countController =
        TextEditingController(text: product.stockLevel.toString());
    int changeDelta = 0;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final currentCount =
              int.tryParse(countController.text) ?? product.stockLevel;
          final updatedCount = (currentCount + changeDelta).clamp(0, 99999);

          return AlertDialog(
            backgroundColor: palette.surfaceElevated,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: palette.neonGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.inventory_2_rounded,
                      color: palette.neonGreen, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Adjust Stock Level',
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${product.sku} • ${product.name}',
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: palette.borderSubtle),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Current System Stock',
                                style: TextStyle(
                                    color: palette.textMuted, fontSize: 11)),
                            const SizedBox(height: 2),
                            Text(
                              '${product.stockLevel} units',
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Reorder Alert at',
                                style: TextStyle(
                                    color: palette.textMuted, fontSize: 11)),
                            const SizedBox(height: 2),
                            Text(
                              '${product.reorderThreshold} units',
                              style: TextStyle(
                                color: palette.neonLime,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Quick Adjust Delta',
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildQuickDeltaButton(
                          ctx, setDialogState, -10, palette),
                      _buildQuickDeltaButton(ctx, setDialogState, -5, palette),
                      _buildQuickDeltaButton(ctx, setDialogState, -1, palette),
                      _buildQuickDeltaButton(ctx, setDialogState, 1, palette),
                      _buildQuickDeltaButton(ctx, setDialogState, 5, palette),
                      _buildQuickDeltaButton(ctx, setDialogState, 10, palette),
                      _buildQuickDeltaButton(ctx, setDialogState, 50, palette),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: countController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: 'New Absolute Quantity',
                      labelStyle: TextStyle(color: palette.neonGreen),
                      filled: true,
                      fillColor: palette.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: palette.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            BorderSide(color: palette.neonGreen, width: 2),
                      ),
                      suffixText: 'units',
                      suffixStyle: TextStyle(color: palette.textMuted),
                    ),
                    onChanged: (val) {
                      setDialogState(() {
                        changeDelta = 0;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Updated quantity will be immediately synced to Supabase pos_products.',
                    style: TextStyle(
                      color: palette.textMuted,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: Text('Cancel',
                    style: TextStyle(color: palette.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.neonGreen,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
                onPressed: () async {
                  final newQty =
                      int.tryParse(countController.text) ?? updatedCount;
                  Navigator.of(dialogCtx).pop();
                  final success = await _posService.updateProductStock(
                      product.id, newQty);
                  if (mounted) {
                    if (success) {
                      AppSnackBar.success(context,
                          'Updated ${product.name} stock to $newQty units');
                    } else {
                      AppSnackBar.warning(context,
                          'Stock updated locally. Offline sync queued.');
                    }
                    _loadProducts(isSilent: true);
                  }
                },
                child: const Text('Save Stock',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildQuickDeltaButton(BuildContext context, StateSetter setDialogState,
      int delta, AppPalette palette) {
    final isPos = delta > 0;
    return InkWell(
      onTap: () {
        setDialogState(() {
          final curr = int.tryParse(_searchController.text) ?? 0;
          final updated = (curr + delta).clamp(0, 99999);
          _searchController.text = updated.toString();
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isPos
              ? palette.neonGreen.withValues(alpha: 0.12)
              : palette.errorRed.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isPos
                ? palette.neonGreen.withValues(alpha: 0.3)
                : palette.errorRed.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          isPos ? '+$delta' : '$delta',
          style: TextStyle(
            color: isPos ? palette.neonGreen : palette.errorRed,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final products = _filteredProducts;

    // Metrics calculations
    final totalSkus = _allProducts.length;
    final lowStockCount = _allProducts
        .where((p) => p.stockLevel > 0 && p.stockLevel <= p.reorderThreshold)
        .length;
    final outOfStockCount = _allProducts.where((p) => p.stockLevel <= 0).length;
    final totalUnits = _allProducts.fold<int>(0, (s, p) => s + p.stockLevel);
    final totalInventoryRetailValue = _allProducts.fold<double>(
        0.0, (s, p) => s + (p.price * p.stockLevel));
    final totalInventoryCostValue = _allProducts.fold<double>(
        0.0,
        (s, p) =>
            s +
            ((p.costPrice > 0 ? p.costPrice : (p.price * 0.5)) * p.stockLevel));

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.surface,
        elevation: 0,
        leading: widget.onToggleMenu != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.menu_rounded, color: palette.textPrimary),
                    tooltip: 'Toggle Navigation Menu',
                    onPressed: widget.onToggleMenu,
                  ),
                  IconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: palette.neonGreen),
                    tooltip: 'Back to POS Register',
                    onPressed: widget.onBackToRegister,
                  ),
                ],
              )
            : IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: palette.neonGreen),
                tooltip: 'Back to POS Register',
                onPressed: widget.onBackToRegister,
              ),
        leadingWidth: widget.onToggleMenu != null ? 96 : null,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: palette.neonGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: palette.neonGreen.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inventory_rounded,
                      size: 14, color: palette.neonGreen),
                  const SizedBox(width: 6),
                  Text(
                    'OPERATIONS',
                    style: TextStyle(
                      color: palette.neonGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Inventory & Stock Control',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _posService.isSupabaseActive
                  ? palette.neonGreen.withValues(alpha: 0.12)
                  : Colors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _posService.isSupabaseActive
                    ? palette.neonGreen.withValues(alpha: 0.35)
                    : Colors.amber.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _posService.isSupabaseActive
                        ? palette.neonGreen
                        : Colors.amber,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _posService.isSupabaseActive
                      ? 'Supabase Connected'
                      : 'Offline Cache',
                  style: TextStyle(
                    color: _posService.isSupabaseActive
                        ? palette.neonGreen
                        : Colors.amber,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: palette.textSecondary),
            tooltip: 'Reload Supabase Inventory',
            onPressed: () => _loadProducts(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: palette.neonGreen),
            )
          : Column(
              children: [
                // Top Metrics KPI Strip
                Container(
                  color: palette.surfaceElevated,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildKpiCard(
                              palette: palette,
                              title: 'TOTAL SKUS',
                              value: '$totalSkus items',
                              subtitle: '$totalUnits units in stock',
                              icon: Icons.qr_code_2_rounded,
                              accentColor: palette.neonGreen,
                            ),
                            const SizedBox(width: 12),
                            _buildKpiCard(
                              palette: palette,
                              title: 'LOW STOCK ALERTS',
                              value: '$lowStockCount items',
                              subtitle: 'Below reorder threshold',
                              icon: Icons.warning_amber_rounded,
                              accentColor: Colors.amber,
                            ),
                            const SizedBox(width: 12),
                            _buildKpiCard(
                              palette: palette,
                              title: 'OUT OF STOCK',
                              value: '$outOfStockCount items',
                              subtitle: 'Requires replenishment',
                              icon: Icons.remove_shopping_cart_rounded,
                              accentColor: palette.errorRed,
                            ),
                            const SizedBox(width: 12),
                            _buildKpiCard(
                              palette: palette,
                              title: 'RETAIL VALUE',
                              value: currencyFmt.format(totalInventoryRetailValue),
                              subtitle:
                                  'Cost: ${currencyFmt.format(totalInventoryCostValue)}',
                              icon: Icons.monetization_on_outlined,
                              accentColor: palette.neonLime,
                            ),
                          ],
                        ),
                      ),
                    ),

                // Filter & Search Toolbar
                Container(
                  color: palette.surface,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 40,
                              child: TextField(
                                controller: _searchController,
                                onChanged: (_) => setState(() {}),
                                style: TextStyle(
                                    color: palette.textPrimary, fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: 'Search by SKU, product name, or category...',
                                  hintStyle: TextStyle(
                                      color: palette.textMuted, fontSize: 13),
                                  prefixIcon: Icon(Icons.search_rounded,
                                      size: 18, color: palette.textSecondary),
                                  suffixIcon: _searchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear_rounded,
                                              size: 16),
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() {});
                                          },
                                        )
                                      : null,
                                  filled: true,
                                  fillColor: palette.background,
                                  contentPadding: EdgeInsets.zero,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide:
                                        BorderSide(color: palette.borderSubtle),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                        color: palette.neonGreen, width: 1.5),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Stock status filter chips
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                value: 'all',
                                label: Text('All', style: TextStyle(fontSize: 11)),
                              ),
                              ButtonSegment(
                                value: 'low',
                                label: Text('Low Stock',
                                    style: TextStyle(fontSize: 11)),
                              ),
                              ButtonSegment(
                                value: 'out',
                                label: Text('Out',
                                    style: TextStyle(fontSize: 11)),
                              ),
                            ],
                            selected: {_stockFilter},
                            onSelectionChanged: (val) {
                              setState(() => _stockFilter = val.first);
                            },
                            style: ButtonStyle(
                              visualDensity: VisualDensity.compact,
                              backgroundColor:
                                  WidgetStateProperty.resolveWith((states) {
                                if (states.contains(WidgetState.selected)) {
                                  return palette.neonGreen.withValues(alpha: 0.2);
                                }
                                return palette.background;
                              }),
                              foregroundColor:
                                  WidgetStateProperty.resolveWith((states) {
                                if (states.contains(WidgetState.selected)) {
                                  return palette.neonGreen;
                                }
                                return palette.textSecondary;
                              }),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Category Filter Row
                      SizedBox(
                        height: 32,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _categories.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 6),
                          itemBuilder: (context, idx) {
                            final cat = _categories[idx];
                            final isSelected = cat == _selectedCategory;
                            return ChoiceChip(
                              label: Text(
                                cat,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? Colors.black
                                      : palette.textSecondary,
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: palette.neonGreen,
                              backgroundColor: palette.background,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4),
                              onSelected: (_) {
                                setState(() => _selectedCategory = cat);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Table View / List
                Expanded(
                  child: products.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inventory_2_outlined,
                                  size: 48, color: palette.textMuted),
                              const SizedBox(height: 12),
                              Text(
                                'No products match your filter',
                                style: TextStyle(
                                    color: palette.textSecondary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Try clearing search or selecting a different category',
                                style: TextStyle(
                                    color: palette.textMuted, fontSize: 12),
                              ),
                            ],
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                      minWidth: constraints.maxWidth),
                                  child: DataTable(
                                    headingRowColor: WidgetStateProperty.all(
                                        palette.surfaceElevated),
                                    dataRowColor:
                                        WidgetStateProperty.resolveWith(
                                            (states) {
                                      if (states
                                          .contains(WidgetState.hovered)) {
                                        return palette.neonGreen
                                            .withValues(alpha: 0.05);
                                      }
                                      return Colors.transparent;
                                    }),
                                    horizontalMargin: 16,
                                    columnSpacing: 20,
                                    columns: [
                                      DataColumn(
                                        label: Text('SKU',
                                            style: TextStyle(
                                                color: palette.textSecondary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12)),
                                      ),
                                      DataColumn(
                                        label: Text('PRODUCT NAME',
                                            style: TextStyle(
                                                color: palette.textSecondary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12)),
                                      ),
                                      DataColumn(
                                        label: Text('CATEGORY',
                                            style: TextStyle(
                                                color: palette.textSecondary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12)),
                                      ),
                                      DataColumn(
                                        numeric: true,
                                        label: Text('RETAIL PRICE',
                                            style: TextStyle(
                                                color: palette.textSecondary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12)),
                                      ),
                                      DataColumn(
                                        numeric: true,
                                        label: Text('COST PRICE',
                                            style: TextStyle(
                                                color: palette.textSecondary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12)),
                                      ),
                                      DataColumn(
                                        numeric: true,
                                        label: Text('MARGIN %',
                                            style: TextStyle(
                                                color: palette.textSecondary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12)),
                                      ),
                                      DataColumn(
                                        numeric: true,
                                        label: Text('STOCK LEVEL',
                                            style: TextStyle(
                                                color: palette.textSecondary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12)),
                                      ),
                                      DataColumn(
                                        label: Text('ACTION',
                                            style: TextStyle(
                                                color: palette.textSecondary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12)),
                                      ),
                                    ],
                                    rows: products.map((product) {
                                      final cost = product.costPrice > 0
                                          ? product.costPrice
                                          : (product.price * 0.5);
                                      final margin = product.price > 0
                                          ? ((product.price - cost) /
                                                  product.price) *
                                              100
                                          : 0.0;

                                      final isOutOfStock =
                                          product.stockLevel <= 0;
                                      final isLowStock = !isOutOfStock &&
                                          product.stockLevel <=
                                              product.reorderThreshold;

                                      final Color stockBadgeColor = isOutOfStock
                                          ? palette.errorRed
                                          : isLowStock
                                              ? Colors.amber
                                              : palette.neonGreen;

                                      return DataRow(
                                        cells: [
                                          DataCell(
                                            Text(
                                              product.sku ?? '-',
                                              style: TextStyle(
                                                color: palette.textMuted,
                                                fontFamily: 'monospace',
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  product.name,
                                                  style: TextStyle(
                                                    color: palette.textPrimary,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          DataCell(
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3),
                                              decoration: BoxDecoration(
                                                color: palette.surface,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                    color:
                                                        palette.borderSubtle),
                                              ),
                                              child: Text(
                                                product.category,
                                                style: TextStyle(
                                                  color: palette.textSecondary,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              currencyFmt.format(product.price),
                                              style: TextStyle(
                                                color: palette.textPrimary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              currencyFmt.format(cost),
                                              style: TextStyle(
                                                color: palette.textMuted,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              '${margin.toStringAsFixed(1)}%',
                                              style: TextStyle(
                                                color: margin >= 40
                                                    ? palette.neonLime
                                                    : palette.textSecondary,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3),
                                              decoration: BoxDecoration(
                                                color: stockBadgeColor
                                                    .withValues(alpha: 0.15),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: stockBadgeColor
                                                      .withValues(alpha: 0.4),
                                                ),
                                              ),
                                              child: Text(
                                                '${product.stockLevel} units',
                                                style: TextStyle(
                                                  color: stockBadgeColor,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    palette.surfaceElevated,
                                                foregroundColor:
                                                    palette.neonGreen,
                                                side: BorderSide(
                                                    color: palette.neonGreen
                                                        .withValues(
                                                            alpha: 0.4)),
                                                visualDensity:
                                                    VisualDensity.compact,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 4),
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6)),
                                              ),
                                              icon: const Icon(
                                                  Icons.tune_rounded,
                                                  size: 13),
                                              label: const Text('Adjust',
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600)),
                                              onPressed: () =>
                                                  _showAdjustStockDialog(
                                                      product),
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildKpiCard({
    required AppPalette palette,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      width: 175,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: accentColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: palette.textMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
