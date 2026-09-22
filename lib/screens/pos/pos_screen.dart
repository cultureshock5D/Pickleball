import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/pos_service.dart';
import '../../core/services/theme_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../models/pos_cart_item_model.dart';
import '../../models/pos_product_model.dart';
import 'controllers/pos_cart_controller.dart';
import 'controllers/pos_catalog_controller.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import '../home/main_navigation_screen.dart';
import 'widgets/cash_tender_modal.dart';
import 'widgets/daily_expenses_margins_view.dart';
import 'widgets/inventory_table_view.dart';
import 'widgets/pos_printer_debug_modal.dart';
import 'widgets/recent_invoices_drawer.dart';
import 'widgets/shift_reports_view.dart';
import 'widgets/thermal_receipt_modal.dart';

enum PosViewMode { register, inventory, expenses, shiftReports }

class PosScreen extends StatefulWidget {
  final String cashierId;
  final String cashierName;
  final String cashierRole;

  const PosScreen({
    super.key,
    required this.cashierId,
    required this.cashierName,
    this.cashierRole = 'cashier',
  });

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  late final PosCatalogController _catalogController;
  late final PosCartController _cartController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();

  int _invoiceCount = 0;
  bool _isCartCollapsed = false;
  bool _isSidebarOpen = true;
  PosViewMode _currentViewMode = PosViewMode.register;
  StreamSubscription<void>? _posUpdatesSub;

  void _toggleNavigationMenu([bool? isWide]) {
    final media = MediaQuery.maybeOf(context);
    final isWideScreen = isWide ??
        (media != null && media.size.width >= 1100 && media.size.height >= 550);
    if (isWideScreen) {
      setState(() {
        _isSidebarOpen = !_isSidebarOpen;
      });
    } else {
      if (_scaffoldKey.currentState?.isDrawerOpen == true) {
        Navigator.of(context).pop();
      } else {
        _scaffoldKey.currentState?.openDrawer();
      }
    }
  }

  @override
  void initState() {
    super.initState();

    // Enable Auto-Rotate (Landscape & Portrait) for Cashier POS
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _catalogController = PosCatalogController();
    _cartController = PosCartController();

    // Strictly restrict POS terminal to cashier / staff accounts only
    final currentUser = AuthService.instance.currentUser;
    final currentEmail = (currentUser?.email ?? '').trim().toLowerCase();
    final isCashierEmail = currentEmail == 'cashier@pickleball.com';
    final isStaff = (widget.cashierRole == 'cashier' ||
            widget.cashierRole == 'admin' ||
            widget.cashierRole == 'owner' ||
            isCashierEmail) &&
        widget.cashierRole != 'client' &&
        widget.cashierRole != 'player';

    if (!isStaff) {
      return;
    }

    _catalogController.loadCatalog();
    _loadInvoiceCount();
    PosService.instance.initRealtimeSubscription();
    _posUpdatesSub = PosService.instance.onPosUpdates.listen((_) {
      if (mounted) {
        _loadInvoiceCount();
      }
    });
  }

  Future<void> _loadInvoiceCount() async {
    try {
      final txs = await PosService.instance.fetchRecentTransactions();
      if (mounted) {
        setState(() {
          _invoiceCount = txs.length;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _posUpdatesSub?.cancel();

    // Revert preferred orientation back to portrait only when exiting Cashier POS
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    _catalogController.dispose();
    _cartController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleAddToCart(PosProductModel product) {
    if (product.isOutOfStock) {
      AppSnackBar.warning(context, '${product.name} is OUT OF STOCK.');
      return;
    }
    final success = _cartController.addItem(product);
    if (success) {
      HapticFeedback.lightImpact();
    } else {
      AppSnackBar.warning(context, 'Cannot add more. Stock limit (${product.stockLevel}) reached.');
    }
  }

  void _handleDecrementItem(PosCartItemModel item) {
    _cartController.decrementItem(item.productId);
  }

  void _handleClearCart() async {
    if (_cartController.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colors = context.colors;
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Clear Current Order?',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          content: Text(
            'All items currently in the cart will be removed.',
            style: GoogleFonts.inter(fontSize: 13, color: colors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel', style: GoogleFonts.inter(color: colors.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Clear Order',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      _cartController.clearCart();
      if (mounted) {
        AppSnackBar.info(context, 'Cart has been cleared.');
      }
    }
  }

  Future<void> _handleCheckout([BuildContext? sheetContext]) async {
    if (_cartController.isEmpty) {
      AppSnackBar.warning(context, 'Cart is empty. Please add items to proceed.');
      return;
    }

    // Cash tender modal and immediate checkout with BIR discount support
    final tender = await CashTenderModal.show(
      context,
      cartController: _cartController,
    );
    if (tender == null) return;
    _cartController.setTenderAmount(tender);

    final tx = await _cartController.checkout(
      cashierId: widget.cashierId,
      cashierName: widget.cashierName,
    );

    if (!mounted) return;

    if (tx != null) {
      if (sheetContext != null && sheetContext.mounted) {
        Navigator.of(sheetContext).pop();
      }
      _catalogController.loadCatalog();
      _loadInvoiceCount();
      await ThermalReceiptModal.show(context, transaction: tx);
    } else if (_cartController.checkoutError != null) {
      AppSnackBar.error(context, _cartController.checkoutError!);
    }
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) {
        final colors = context.colors;
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Close Cashier Register?',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          content: Text(
            'You will be signed out of the POS terminal.',
            style: GoogleFonts.inter(fontSize: 14, color: colors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: GoogleFonts.inter(color: colors.textSecondary)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await AuthService.instance.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
              child: Text(
                'Sign Out',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenSize = MediaQuery.sizeOf(context);
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    final currentUser = AuthService.instance.currentUser;
    final currentEmail = (currentUser?.email ?? '').trim().toLowerCase();
    final isCashierEmail = currentEmail == 'cashier@pickleball.com';
    final isStaff = (widget.cashierRole == 'cashier' ||
            widget.cashierRole == 'admin' ||
            widget.cashierRole == 'owner' ||
            isCashierEmail) &&
        widget.cashierRole != 'client' &&
        widget.cashierRole != 'player';

    if (!isStaff) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF090E14) : const Color(0xFFF8FAFC),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 64, color: Colors.redAccent),
                const SizedBox(height: 16),
                Text(
                  'Access Denied',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Cashier & Pro Shop Staff register only.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
                    );
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to Player App'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final showPermanentSidebar = screenWidth >= 1100 && screenHeight >= 550;
    final isDualPaneDevice = screenWidth >= 960 && screenHeight >= 550;
    final isDualPane = isDualPaneDevice && !_isCartCollapsed;
    final isShortHeight = screenHeight < 550;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark ? const Color(0xFF090E14) : const Color(0xFFF8FAFC),
      drawer: _buildSidebarDrawer(colors, isDark),
      endDrawer: RecentInvoicesDrawer(
        currentCashierId: widget.cashierId,
        onTransactionVoided: () {
          _catalogController.loadCatalog();
        },
      ),
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Sidebar (Desktop / Wide Tablet) - Smoothly collapsible
            if (showPermanentSidebar)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                width: _isSidebarOpen ? 220 : 0,
                child: ClipRect(
                  child: OverflowBox(
                    minWidth: 220,
                    maxWidth: 220,
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: 220,
                      child: SingleChildScrollView(
                        child: _buildSidebarContent(colors, isDark),
                      ),
                    ),
                  ),
                ),
              ),

            if (showPermanentSidebar && _isSidebarOpen)
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              ),

            // Main Content Area
            Expanded(
              child: _buildMainView(
                colors,
                isDark,
                showPermanentSidebar,
                isShortHeight,
                isDualPane,
                isDualPaneDevice,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainView(
    dynamic colors,
    bool isDark,
    bool showPermanentSidebar,
    bool isShortHeight,
    bool isDualPane,
    bool isDualPaneDevice,
  ) {
    switch (_currentViewMode) {
      case PosViewMode.inventory:
        return InventoryTableView(
          onBackToRegister: () =>
              setState(() => _currentViewMode = PosViewMode.register),
          onToggleMenu: () => _toggleNavigationMenu(showPermanentSidebar),
        );
      case PosViewMode.expenses:
        return DailyExpensesMarginsView(
          onBackToRegister: () =>
              setState(() => _currentViewMode = PosViewMode.register),
          onToggleMenu: () => _toggleNavigationMenu(showPermanentSidebar),
        );
      case PosViewMode.shiftReports:
        return ShiftReportsView(
          onBackToRegister: () =>
              setState(() => _currentViewMode = PosViewMode.register),
          onToggleMenu: () => _toggleNavigationMenu(showPermanentSidebar),
        );
      case PosViewMode.register:
        return Column(
          children: [
            // Top Header Bar
            _buildHeaderBar(
                colors, isDark, showPermanentSidebar, isShortHeight),

            // Divider below header
            Divider(
              height: 1,
              thickness: 1,
              color: isDark
                  ? const Color(0xFF1E293B)
                  : const Color(0xFFE2E8F0),
            ),

            // Catalog & Cart Body
            Expanded(
              child: isDualPane
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Center Pane: Catalog & Toolbar
                        Expanded(
                          flex: 62,
                          child: _buildCatalogAndDiscountsPane(colors, isDark,
                              isShortHeight, isDualPaneDevice),
                        ),

                        VerticalDivider(
                          width: 1,
                          thickness: 1,
                          color: isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFE2E8F0),
                        ),

                        // Right Pane: Active Order & Tender
                        Expanded(
                          flex: 38,
                          child:
                              _buildCartPane(colors, isDark, isShortHeight),
                        ),
                      ],
                    )
                  : _buildMobileLayout(
                      colors, isDark, isShortHeight, isDualPaneDevice),
            ),
          ],
        );
    }
  }

  // --- TOP HEADER BAR ---
  Widget _buildHeaderBar(dynamic colors, bool isDark, bool hasSidebar, [bool isShortHeight = false]) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 1100 || isShortHeight;
        final isVeryCompact = constraints.maxWidth < 450;

        return Container(
          height: isShortHeight ? 44 : 60,
          padding: EdgeInsets.symmetric(horizontal: isShortHeight ? 10 : 12),
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          child: Row(
            children: [
              // Navigation Menu Toggle Button (Available for both Vertical & Horizontal views)
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  (hasSidebar && _isSidebarOpen)
                      ? Icons.menu_open_rounded
                      : Icons.menu_rounded,
                  color: colors.textPrimary,
                ),
                tooltip: 'Navigation Menu',
                onPressed: () => _toggleNavigationMenu(hasSidebar),
              ),
              const SizedBox(width: 4),

              // C&J Brand logo & Active Pill
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!hasSidebar || !_isSidebarOpen) ...[
                    Container(
                      height: isShortHeight ? 24 : 30,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.asset(
                          'cashier_pos/cj-logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isVeryCompact) ...[
                          Text(
                            (hasSidebar && _isSidebarOpen) ? 'C&J ARENA' : 'ARENA',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(width: 5),
                        ],
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        if (!isCompact) ...[
                          const SizedBox(width: 5),
                          Text(
                            'Cashier Console Active',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              // Operations Quick Switch Tabs in Header (for Horizontal/Desktop views)
              if (constraints.maxWidth >= 960) ...[
                const SizedBox(width: 12),
                _buildHeaderViewPill(
                  title: 'Register',
                  icon: Icons.point_of_sale_rounded,
                  isActive: _currentViewMode == PosViewMode.register,
                  onTap: () => setState(() => _currentViewMode = PosViewMode.register),
                  colors: colors,
                  isDark: isDark,
                ),
                const SizedBox(width: 6),
                _buildHeaderViewPill(
                  title: 'Inventory',
                  icon: Icons.inventory_2_outlined,
                  isActive: _currentViewMode == PosViewMode.inventory,
                  onTap: () => setState(() => _currentViewMode = PosViewMode.inventory),
                  colors: colors,
                  isDark: isDark,
                ),
                const SizedBox(width: 6),
                _buildHeaderViewPill(
                  title: 'Expenses',
                  icon: Icons.show_chart_rounded,
                  isActive: _currentViewMode == PosViewMode.expenses,
                  onTap: () => setState(() => _currentViewMode = PosViewMode.expenses),
                  colors: colors,
                  isDark: isDark,
                ),
                const SizedBox(width: 6),
                _buildHeaderViewPill(
                  title: 'Reports',
                  icon: Icons.assessment_outlined,
                  isActive: _currentViewMode == PosViewMode.shiftReports,
                  onTap: () => setState(() => _currentViewMode = PosViewMode.shiftReports),
                  colors: colors,
                  isDark: isDark,
                ),
              ],

              const Spacer(),

              // Thermal Printer Setup & Diagnostics Button
              if (!isCompact)
                OutlinedButton.icon(
                  icon: const Icon(Icons.print_outlined, size: 16, color: Color(0xFF00E599)),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'JP58H Printer',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF00E599),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: const Color(0xFF00E599).withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => PosPrinterDebugModal.show(context),
                )
              else
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'JP58H Thermal Printer',
                  icon: const Icon(Icons.print_outlined, size: 20, color: Color(0xFF00E599)),
                  onPressed: () => PosPrinterDebugModal.show(context),
                ),

              const SizedBox(width: 2),

              // Dark/Light Theme Switcher
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: isDark ? 'Switch to Cockpit Light Mode' : 'Switch to Dark Mode',
                icon: Icon(
                  isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  size: 20,
                  color: colors.textSecondary,
                ),
                onPressed: () => ThemeService.instance.toggleTheme(),
              ),

              const SizedBox(width: 2),

              // Cashier profile info (show if wide and not in sidebar)
              if (!hasSidebar && !isCompact) ...[
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.cashierName,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Text(
                            widget.cashierRole.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'cashier@pickleball.com',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
              ],

              // Sign Out Button (Compact icon on mobile, outlined button on wide screens)
              if (isCompact)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Sign Out / Close Register',
                  icon: const Icon(Icons.logout_rounded, size: 20, color: Colors.redAccent),
                  onPressed: _handleLogout,
                )
              else
                OutlinedButton.icon(
                  icon: const Icon(Icons.logout_rounded, size: 15, color: Colors.redAccent),
                  label: Text(
                    'Sign Out',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.redAccent,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    side: BorderSide(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _handleLogout,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderViewPill({
    required String title,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    required dynamic colors,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive
              ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive
                  ? (isDark ? const Color(0xFFCCFF00) : const Color(0xFF0F172A))
                  : colors.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? colors.textPrimary : colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- SIDEBAR DRAWER (Mobile & Horizontal) ---
  Widget _buildSidebarDrawer(dynamic colors, bool isDark) {
    return Drawer(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: SafeArea(
        child: SingleChildScrollView(
          child: _buildSidebarContent(colors, isDark, true),
        ),
      ),
    );
  }

  // --- SIDEBAR CONTENT (Desktop & Drawer) ---
  Widget _buildSidebarContent(dynamic colors, bool isDark, [bool isDrawer = false]) {
    return Container(
      color: isDark ? const Color(0xFF0F172A) : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drawer Header with Close Button / Desktop Sidebar with Collapse Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'OPERATIONS MENU',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: colors.textSecondary,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                tooltip: isDrawer ? 'Close Menu' : 'Collapse Menu',
                icon: Icon(
                  isDrawer ? Icons.close_rounded : Icons.chevron_left_rounded,
                  size: 20,
                  color: colors.textSecondary,
                ),
                onPressed: () {
                  if (isDrawer) {
                    Navigator.of(context).pop();
                  } else {
                    setState(() => _isSidebarOpen = false);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Top Logo
          Center(
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  'cashier_pos/cj-logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Cashier Staff Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFF0F2942),
                  child: Text(
                    widget.cashierName.isNotEmpty ? widget.cashierName[0].toUpperCase() : 'C',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.cashierName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF08A),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'CASHIER',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF854D0E),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'CASHIER TERMINAL',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Section: OPERATIONS
          Text(
            'OPERATIONS',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),

          _buildSidebarNavItem(
            icon: Icons.point_of_sale_rounded,
            label: 'C&J POS REGISTER',
            isActive: _currentViewMode == PosViewMode.register,
            isDark: isDark,
            colors: colors,
            isDrawer: isDrawer,
            onTap: () {
              setState(() => _currentViewMode = PosViewMode.register);
            },
          ),
          _buildSidebarNavItem(
            icon: Icons.inventory_2_outlined,
            label: 'Inventory Table',
            isActive: _currentViewMode == PosViewMode.inventory,
            isDark: isDark,
            colors: colors,
            isDrawer: isDrawer,
            onTap: () {
              setState(() => _currentViewMode = PosViewMode.inventory);
            },
          ),
          _buildSidebarNavItem(
            icon: Icons.show_chart_rounded,
            label: 'Daily Expenses & Margins',
            isActive: _currentViewMode == PosViewMode.expenses,
            isDark: isDark,
            colors: colors,
            isDrawer: isDrawer,
            onTap: () {
              setState(() => _currentViewMode = PosViewMode.expenses);
            },
          ),
          _buildSidebarNavItem(
            icon: Icons.receipt_long_outlined,
            label: 'Shift Reports',
            isActive: _currentViewMode == PosViewMode.shiftReports,
            isDark: isDark,
            colors: colors,
            isDrawer: isDrawer,
            onTap: () {
              setState(() => _currentViewMode = PosViewMode.shiftReports);
            },
          ),

          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.logout_rounded, size: 16, color: Colors.redAccent),
              label: Text(
                'Sign Out / Close Register',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.redAccent,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                side: const BorderSide(color: Colors.redAccent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _handleLogout,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required bool isDark,
    required dynamic colors,
    bool isDrawer = false,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isActive
            ? (isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          leading: Icon(
            icon,
            size: 18,
            color: isActive ? Colors.white : colors.textSecondary,
          ),
          title: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? Colors.white : colors.textPrimary,
            ),
          ),
          trailing: isActive
              ? Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFFCCFF00), // Electric Lime active dot
                    shape: BoxShape.circle,
                  ),
                )
              : null,
          onTap: () {
            if (isDrawer) {
              Navigator.of(context).pop();
            }
            onTap?.call();
          },
        ),
      ),
    );
  }

  // --- CATALOG & DISCOUNTS PANE (CENTER) ---
  Widget _buildCatalogAndDiscountsPane(dynamic colors, bool isDark, [bool isShortHeight = false, bool isDualPaneDevice = false]) {
    return ListenableBuilder(
      listenable: _catalogController,
      builder: (context, _) {
        return Column(
          children: [
            // Cockpit Terminal Header & Actions
            _buildCockpitHeader(colors, isDark, isShortHeight, isDualPaneDevice),

            // Department Navigation Pills Bar
            _buildDepartmentPills(colors, isDark, isShortHeight),

            // Subcategory Filter Chips Bar
            _buildSubcategoryChips(colors, isDark, isShortHeight),

            // Products Catalog Table or Cards
            Expanded(
              child: _catalogController.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _catalogController.filteredProducts.isEmpty
                      ? Center(
                          child: Text(
                            'No items match your search or filter.',
                            style: GoogleFonts.inter(fontSize: 13, color: colors.textSecondary),
                          ),
                        )
                      : _catalogController.isGridView
                          ? _buildProductCardsView(colors, isDark, isShortHeight)
                          : _buildProductTableView(colors, isDark, isShortHeight),
            ),
          ],
        );
      },
    );
  }

  // Cockpit Terminal Header & Actions
  Widget _buildCockpitHeader(dynamic colors, bool isDark, [bool isShortHeight = false, bool isDualPaneDevice = false]) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 680;
        final isVeryNarrow = constraints.maxWidth < 420;

        return Container(
          padding: EdgeInsets.fromLTRB(16, isShortHeight ? 4 : 8, 16, isShortHeight ? 4 : 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left: Invoices & Void + View Toggle
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Recent Invoices & Void trigger
                    OutlinedButton.icon(
                      icon: const Icon(Icons.history_rounded, size: 14),
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(isNarrow ? 'Invoices' : 'Invoices & Void'),
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$_invoiceCount',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: Size(0, isShortHeight ? 30 : 34),
                        foregroundColor: colors.textPrimary,
                        side: BorderSide(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      ),
                      onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                    ),
                    if (isDualPaneDevice) ...[
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: Icon(
                          _isCartCollapsed ? Icons.shopping_cart_outlined : Icons.chevron_right_rounded,
                          size: 14,
                        ),
                        label: Text(_isCartCollapsed ? 'Show Cart' : 'Hide Cart'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size(0, isShortHeight ? 30 : 34),
                          foregroundColor: colors.textPrimary,
                          side: BorderSide(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        ),
                        onPressed: () {
                          setState(() {
                            _isCartCollapsed = !_isCartCollapsed;
                          });
                        },
                      ),
                    ],
                    const SizedBox(width: 8),

                    // View Toggle [Table] [Cards]
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      padding: const EdgeInsets.all(2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: () => _catalogController.setGridView(false),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: !_catalogController.isGridView
                                    ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: !_catalogController.isGridView
                                    ? [const BoxShadow(color: Colors.black12, blurRadius: 3)]
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.table_rows_outlined,
                                    size: 13,
                                    color: !_catalogController.isGridView
                                        ? colors.textPrimary
                                        : colors.textSecondary,
                                  ),
                                  if (!isNarrow) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      'Table',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: !_catalogController.isGridView
                                            ? colors.textPrimary
                                            : colors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => _catalogController.setGridView(true),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: _catalogController.isGridView
                                    ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: _catalogController.isGridView
                                    ? [const BoxShadow(color: Colors.black12, blurRadius: 3)]
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.grid_view_rounded,
                                    size: 13,
                                    color: _catalogController.isGridView
                                        ? colors.textPrimary
                                        : colors.textSecondary,
                                  ),
                                  if (!isNarrow) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      'Cards',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: _catalogController.isGridView
                                            ? colors.textPrimary
                                            : colors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Right: Search Box
              SizedBox(
                width: isVeryNarrow ? 90 : (isNarrow ? 120 : 150),
                height: isShortHeight ? 30 : 34,
                child: TextField(
                  controller: _searchController,
                  onChanged: _catalogController.updateSearch,
                  style: GoogleFonts.inter(fontSize: 11, color: colors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search SKU...',
                    hintStyle: GoogleFonts.inter(fontSize: 10, color: colors.textSecondary),
                    prefixIcon: Icon(Icons.search, size: 14, color: colors.textSecondary),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 12),
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              _searchController.clear();
                              _catalogController.updateSearch('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Department Filter Navigation Pills
  Widget _buildDepartmentPills(dynamic colors, bool isDark, [bool isShortHeight = false]) {
    final depts = [
      {'key': 'Coffee', 'name': 'Coffee', 'icon': '☕', 'tint': const Color(0xFFFEF3C7), 'text': const Color(0xFF92400E)},
      {'key': 'Drinks', 'name': 'Drinks', 'icon': '🥤', 'tint': const Color(0xFFE0F2FE), 'text': const Color(0xFF0369A1)},
      {'key': 'Food', 'name': 'Food', 'icon': '🍳', 'tint': const Color(0xFFFFEDD5), 'text': const Color(0xFFC2410C)},
      {'key': 'Supplies', 'name': 'Supplies', 'icon': '📦', 'tint': const Color(0xFFF1F5F9), 'text': const Color(0xFF475569)},
      {'key': 'All', 'name': 'All Menu', 'icon': '🌐', 'tint': const Color(0xFF0F172A), 'text': Colors.white},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: isShortHeight ? 2 : 4),
      child: Row(
        children: depts.map((d) {
          final deptKey = d['key'] as String;
          final isSelected = _catalogController.selectedDepartment == deptKey;
          final count = _catalogController.getDepartmentCount(deptKey);
          final icon = d['icon'] as String;
          final name = d['name'] as String;
          final defaultTint = d['tint'] as Color;
          final defaultTextColor = d['text'] as Color;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => _catalogController.selectDepartment(deptKey),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: isShortHeight ? 9 : 12, vertical: isShortHeight ? 4 : 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? const Color(0xFF0F172A) : const Color(0xFF0F172A))
                      : (isDark ? const Color(0xFF1E293B) : defaultTint),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF0F172A)
                        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(icon, style: TextStyle(fontSize: isShortHeight ? 11 : 13)),
                    const SizedBox(width: 5),
                    Text(
                      name,
                      style: GoogleFonts.inter(
                        fontSize: isShortHeight ? 11 : 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected ? Colors.white : (isDark ? Colors.white70 : defaultTextColor),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF38BDF8)
                            : (isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: GoogleFonts.inter(
                          fontSize: isShortHeight ? 9 : 10,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : (isDark ? Colors.white : defaultTextColor),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Subcategory Chips Bar
  Widget _buildSubcategoryChips(dynamic colors, bool isDark, [bool isShortHeight = false]) {
    final categories = _catalogController.availableCategories;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: isShortHeight ? 2 : 4),
      child: Row(
        children: categories.map((cat) {
          final isSelected = _catalogController.selectedCategory == cat;
          final count = _catalogController.getCategoryCount(cat);

          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: InkWell(
              onTap: () => _catalogController.selectCategory(cat),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: isShortHeight ? 8 : 10, vertical: isShortHeight ? 3 : 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A))
                      : (isDark ? Colors.transparent : Colors.white),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF0F172A)
                        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      cat.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: isShortHeight ? 9 : 10,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : colors.textPrimary,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white24
                            : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$count',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- PRODUCT TABLE VIEW (Responsive POS Data Table) ---
  Widget _buildProductTableView(dynamic colors, bool isDark, [bool isShortHeight = false]) {
    return ListenableBuilder(
      listenable: _cartController,
      builder: (context, _) {
        final products = _catalogController.filteredProducts;

        return LayoutBuilder(
          builder: (context, constraints) {
            const double tableMinWidth = 620.0;
            final bool isScrollable = constraints.maxWidth < tableMinWidth;
            final double actualWidth = isScrollable ? tableMinWidth : constraints.maxWidth;

            Widget tableContent = SizedBox(
              width: actualWidth,
              child: Column(
                children: [
                  // Clean Table Header
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 28, vertical: isShortHeight ? 4 : 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.5) : const Color(0xFFF1F5F9),
                      border: Border(
                        bottom: BorderSide(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 60,
                          child: Text(
                            'SKU',
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: colors.textSecondary),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(width: isShortHeight ? 28 : 36), // thumbnail space
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 3,
                          child: Text(
                            'ITEM',
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: colors.textSecondary),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 85,
                          child: Text(
                            'CATEGORY',
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: colors.textSecondary),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 85,
                          child: Text(
                            'STOCK',
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: colors.textSecondary),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 75,
                          child: Text(
                            'PRICE',
                            textAlign: TextAlign.right,
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: colors.textSecondary),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 76,
                          child: Text(
                            'ACTION',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: colors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Table Rows List
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: isShortHeight ? 3 : 6),
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final product = products[index];
                        final cartQty = _cartController.quantityForProduct(product.id);
                        final isOos = product.isOutOfStock;
                        final isLowStock = product.stockLevel > 0 && product.stockLevel <= 5;

                        return Container(
                          margin: EdgeInsets.only(bottom: isShortHeight ? 3 : 6),
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: isShortHeight ? 4 : 8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : Colors.white,
                            borderRadius: BorderRadius.circular(isShortHeight ? 8 : 10),
                            border: Border.all(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            children: [
                              // SKU Badge
                              SizedBox(
                                width: 60,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Text(
                                    product.sku ?? 'SKU-${index + 1}',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.robotoMono(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Product Image Thumbnail
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  width: isShortHeight ? 28 : 36,
                                  height: isShortHeight ? 28 : 36,
                                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                  child: Image.asset(
                                    product.effectiveImagePath,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Image.asset(
                                      'cashier_pos/cj-logo.png',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Name (Ample width, never vertically squished!)
                              Expanded(
                                flex: 3,
                                child: Text(
                                  product.name,
                                  maxLines: isShortHeight ? 1 : 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: isShortHeight ? 12 : 13,
                                    fontWeight: FontWeight.w700,
                                    color: isOos ? colors.textSecondary : colors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Category Pill
                              SizedBox(
                                width: 85,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE0F2FE),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      product.category.toUpperCase(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1),
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Stock indicator
                              SizedBox(
                                width: 85,
                                child: isOos
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.redAccent.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'OUT OF STOCK',
                                          maxLines: 1,
                                          style: GoogleFonts.inter(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.redAccent,
                                          ),
                                        ),
                                      )
                                    : isLowStock
                                        ? Row(
                                            children: [
                                              Container(
                                                width: 6,
                                                height: 6,
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFFC2410C),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Low (${product.stockLevel})',
                                                style: GoogleFonts.inter(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: const Color(0xFFC2410C),
                                                ),
                                              ),
                                            ],
                                          )
                                        : Row(
                                            children: [
                                              Container(
                                                width: 6,
                                                height: 6,
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFF10B981),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'In Stock (${product.stockLevel})',
                                                style: GoogleFonts.inter(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark ? const Color(0xFF10B981) : const Color(0xFF059669),
                                                ),
                                              ),
                                            ],
                                          ),
                              ),
                              const SizedBox(width: 10),

                              // Price
                              SizedBox(
                                width: 75,
                                child: Text(
                                  '₱${product.price.toStringAsFixed(2)}',
                                  textAlign: TextAlign.right,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: isShortHeight ? 12 : 13,
                                    fontWeight: FontWeight.w800,
                                    color: isOos ? colors.textSecondary : colors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Add button or Qty Stepper
                              SizedBox(
                                width: 76,
                                child: isOos
                                    ? const Center(
                                        child: Text(
                                          'UNAVAILABLE',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.redAccent,
                                          ),
                                        ),
                                      )
                                    : cartQty > 0
                                        ? Container(
                                            height: isShortHeight ? 26 : 32,
                                            padding: const EdgeInsets.symmetric(horizontal: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF0F172A),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                InkWell(
                                                  onTap: () {
                                                    final cartItem = _cartController.items.firstWhere(
                                                      (item) => item.productId == product.id,
                                                    );
                                                    _handleDecrementItem(cartItem);
                                                  },
                                                  child: const Padding(
                                                    padding: EdgeInsets.symmetric(horizontal: 4),
                                                    child: Icon(Icons.remove, size: 13, color: Colors.white),
                                                  ),
                                                ),
                                                Text(
                                                  '$cartQty',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w800,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                InkWell(
                                                  onTap: () => _handleAddToCart(product),
                                                  child: const Padding(
                                                    padding: EdgeInsets.symmetric(horizontal: 4),
                                                    child: Icon(Icons.add, size: 13, color: Colors.white),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        : SizedBox(
                                            height: isShortHeight ? 26 : 32,
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF0F172A),
                                                foregroundColor: Colors.white,
                                                minimumSize: Size(64, isShortHeight ? 26 : 32),
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                elevation: 0,
                                              ),
                                              onPressed: () => _handleAddToCart(product),
                                              child: Text(
                                                '+ Add',
                                                style: GoogleFonts.inter(fontSize: isShortHeight ? 10 : 11, fontWeight: FontWeight.w700),
                                              ),
                                            ),
                                          ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );

            if (isScrollable) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: tableContent,
              );
            }

            return tableContent;
          },
        );
      },
    );
  }

  // --- PRODUCT CARDS VIEW ---
  Widget _buildProductCardsView(dynamic colors, bool isDark, [bool isShortHeight = false]) {
    return ListenableBuilder(
      listenable: _cartController,
      builder: (context, _) {
        final products = _catalogController.filteredProducts;

        return GridView.builder(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: isShortHeight ? 4 : 6),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: isShortHeight ? 150 : 220,
            mainAxisSpacing: isShortHeight ? 6 : 10,
            crossAxisSpacing: isShortHeight ? 6 : 10,
            childAspectRatio: isShortHeight ? 0.88 : 0.68,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            final cartQty = _cartController.quantityForProduct(product.id);
            final isOos = product.isOutOfStock;
            final isLowStock = product.stockLevel > 0 && product.stockLevel <= 5;

            return InkWell(
              onTap: isOos ? null : () => _handleAddToCart(product),
              borderRadius: BorderRadius.circular(isShortHeight ? 8 : 12),
              child: Container(
                padding: EdgeInsets.all(isShortHeight ? 6 : 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius: BorderRadius.circular(isShortHeight ? 8 : 12),
                  border: Border.all(
                    color: cartQty > 0
                        ? const Color(0xFF0F172A)
                        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                    width: cartQty > 0 ? 1.5 : 1.0,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Image Banner
                    ClipRRect(
                      borderRadius: BorderRadius.circular(isShortHeight ? 5 : 8),
                      child: Container(
                        height: isShortHeight ? 46 : 82,
                        width: double.infinity,
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        child: Image.asset(
                          product.effectiveImagePath,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Image.asset(
                            'cashier_pos/cj-logo.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: isShortHeight ? 3 : 6),

                    // SKU & Cart Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            product.sku ?? 'SKU-${index + 1}',
                            style: GoogleFonts.robotoMono(
                              fontSize: isShortHeight ? 8 : 9,
                              fontWeight: FontWeight.w700,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                        if (cartQty > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              isShortHeight ? '$cartQty' : '$cartQty in cart',
                              style: GoogleFonts.inter(
                                fontSize: isShortHeight ? 8 : 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: isShortHeight ? 2 : 4),

                    // Name
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: isShortHeight ? 11 : 12,
                        fontWeight: FontWeight.w700,
                        color: isOos ? colors.textSecondary : colors.textPrimary,
                      ),
                    ),
                    if (!isShortHeight) ...[
                      const SizedBox(height: 2),
                      // Category
                      Text(
                        product.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 10, color: colors.textSecondary),
                      ),
                    ],
                    const Spacer(),

                    // Stock & Price Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: isOos
                              ? Text(
                                  'OUT OF STOCK',
                                  style: GoogleFonts.inter(
                                    fontSize: isShortHeight ? 8 : 9,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.redAccent,
                                  ),
                                )
                              : isLowStock
                                  ? Text(
                                      'Low (${product.stockLevel})',
                                      style: GoogleFonts.inter(
                                        fontSize: isShortHeight ? 9 : 10,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFFC2410C),
                                      ),
                                    )
                                  : Text(
                                      'Stock: ${product.stockLevel}',
                                      style: GoogleFonts.inter(
                                        fontSize: isShortHeight ? 9 : 10,
                                        color: colors.textSecondary,
                                      ),
                                    ),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              '₱${product.price.toStringAsFixed(2)}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: isShortHeight ? 11 : 13,
                                fontWeight: FontWeight.w800,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- RIGHT PANE: ACTIVE ORDER & TENDER ---
  Widget _buildCartPane(dynamic colors, bool isDark, [bool isShortHeight = false, bool isModal = false]) {
    return ListenableBuilder(
      listenable: _cartController,
      builder: (context, _) {
        final tax = _cartController.taxBreakdown;

        return Container(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          child: Column(
            children: [
              // Cart Header
              Container(
                padding: EdgeInsets.fromLTRB(16, isShortHeight ? 8 : 12, 16, isShortHeight ? 8 : 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: const BoxDecoration(
                              color: Color(0xFF0F2942),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.shopping_cart_outlined, size: 15, color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Active Order (${_cartController.itemCount} items)',
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: isShortHeight ? 12 : 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: const BoxDecoration(
                              color: Color(0xFFEAB308), // Bright yellow badge
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${_cartController.itemCount}',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_cartController.isNotEmpty)
                          InkWell(
                            onTap: _handleClearCart,
                            child: Text(
                              'Clear All',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.redAccent,
                              ),
                            ),
                          ),
                        if (isModal) ...[
                          const SizedBox(width: 12),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: Icon(Icons.close_rounded, size: 20, color: colors.textSecondary),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Cart Items / Empty State
              Expanded(
                child: _cartController.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: EdgeInsets.all(isShortHeight ? 8 : 14),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF0F9FF),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.shopping_cart_outlined,
                                size: isShortHeight ? 24 : 32,
                                color: const Color(0xFF0284C7),
                              ),
                            ),
                            SizedBox(height: isShortHeight ? 6 : 12),
                            Text(
                              'Order cart is empty',
                              style: GoogleFonts.inter(
                                fontSize: isShortHeight ? 12 : 13,
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Click catalog items on the left to add to order',
                              style: GoogleFonts.inter(fontSize: isShortHeight ? 10 : 11, color: colors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.all(isShortHeight ? 6 : 12),
                        itemCount: _cartController.items.length,
                        separatorBuilder: (_, __) => SizedBox(height: isShortHeight ? 4 : 6),
                        itemBuilder: (context, index) {
                          final item = _cartController.items[index];
                          return _buildCartItemTile(item, colors, isDark, isShortHeight);
                        },
                      ),
              ),

              // Divider
              Divider(
                height: 1,
                thickness: 1,
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              ),

              // Tender, Summary & Checkout Bar
              Container(
                padding: EdgeInsets.all(isShortHeight ? 8 : 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isShortHeight) ...[
                      // Payment Channel Header
                      Text(
                        'PAYMENT CHANNEL',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Single Payment Channel: Cash
                      Row(
                        children: [
                          _buildPaymentChannelButton(
                            'Cash',
                            Icons.payments_outlined,
                            isDark,
                            colors,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Financial Breakdown
                    _buildSummaryLine('Gross Subtotal:', '₱${tax.grossSubtotal.toStringAsFixed(2)}', colors, isShort: isShortHeight),
                    if (tax.discountAmount > 0)
                      _buildSummaryLine(
                        'Statutory 20% Discount:',
                        '-₱${tax.discountAmount.toStringAsFixed(2)}',
                        colors,
                        isHighlight: true,
                        isShort: isShortHeight,
                      ),
                    _buildSummaryLine('Vatable Sales:', '₱${tax.vatableSales.toStringAsFixed(2)}', colors, isShort: isShortHeight),
                    _buildSummaryLine('12% VAT:', '₱${tax.vatAmount.toStringAsFixed(2)}', colors, isShort: isShortHeight),
                    if (tax.vatExemptSales > 0)
                      _buildSummaryLine('VAT-Exempt Sales:', '₱${tax.vatExemptSales.toStringAsFixed(2)}', colors, isShort: isShortHeight),

                    SizedBox(height: isShortHeight ? 2 : 4),

                    // Net Payable Large Text
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          'NET PAYABLE:',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: isShortHeight ? 10 : 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          '₱${tax.netPayable.toStringAsFixed(2)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: isShortHeight ? 16 : 22,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: isShortHeight ? 6 : 12),

                    // Complete and Print Invoice Button
                    SizedBox(
                      width: double.infinity,
                      height: isShortHeight ? 36 : 46,
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.shopping_cart_outlined, size: isShortHeight ? 15 : 17),
                        label: Text(
                          'COMPLETE & PRINT INVOICE (₱${tax.netPayable.toStringAsFixed(2)})',
                          style: GoogleFonts.inter(
                            fontSize: isShortHeight ? 10 : 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _cartController.isEmpty
                              ? (isDark ? const Color(0xFF334155) : const Color(0xFF94A3B8))
                              : const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          minimumSize: Size(0, isShortHeight ? 36 : 46),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _cartController.isEmpty || _cartController.isProcessing
                            ? null
                            : () => _handleCheckout(isModal ? context : null),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCartItemTile(PosCartItemModel item, dynamic colors, bool isDark, [bool isShortHeight = false]) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: isShortHeight ? 4 : 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(isShortHeight ? 6 : 8),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          // Cart Item Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Container(
              width: isShortHeight ? 28 : 34,
              height: isShortHeight ? 28 : 34,
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
              child: Image.asset(
                item.product.effectiveImagePath,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Image.asset(
                  'cashier_pos/cj-logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: isShortHeight ? 11 : 12,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  '₱${item.unitPrice.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(fontSize: isShortHeight ? 10 : 11, color: colors.textSecondary),
                ),
              ],
            ),
          ),
          // Stepper
          Row(
            children: [
              IconButton(
                icon: Icon(
                  item.quantity == 1 ? Icons.delete_outline : Icons.remove,
                  size: isShortHeight ? 13 : 14,
                  color: item.quantity == 1 ? Colors.redAccent : colors.textPrimary,
                ),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(
                  minWidth: isShortHeight ? 22 : 26,
                  minHeight: isShortHeight ? 22 : 26,
                ),
                onPressed: () => _handleDecrementItem(item),
              ),
              Text(
                '${item.quantity}',
                style: GoogleFonts.inter(
                  fontSize: isShortHeight ? 11 : 12,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
              IconButton(
                icon: Icon(Icons.add, size: isShortHeight ? 13 : 14),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(
                  minWidth: isShortHeight ? 22 : 26,
                  minHeight: isShortHeight ? 22 : 26,
                ),
                onPressed: () => _cartController.incrementItem(item.productId),
              ),
            ],
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 62,
            child: Text(
              '₱${item.subtotal.toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: GoogleFonts.plusJakartaSans(
                fontSize: isShortHeight ? 11 : 13,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentChannelButton(
    String method,
    IconData icon,
    bool isDark,
    dynamic colors,
  ) {
    final isSelected = _cartController.paymentMethod == method;

    return Expanded(
      child: InkWell(
        onTap: () => _cartController.setPaymentMethod(method),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF0F172A)
                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF0F172A)
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : colors.textSecondary,
              ),
              const SizedBox(height: 3),
              Text(
                method,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryLine(String label, String value, dynamic colors, {bool isHighlight = false, bool isShort = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isShort ? 0.5 : 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: isShort ? 9 : 11,
              color: isHighlight ? const Color(0xFFD97706) : colors.textSecondary,
              fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: isShort ? 9 : 11,
              color: isHighlight ? const Color(0xFFD97706) : colors.textPrimary,
              fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // --- MOBILE / SINGLE-PANE LAYOUT (Adaptive for Phones & Horizontal) ---
  Widget _buildMobileLayout(dynamic colors, bool isDark, [bool isShortHeight = false, bool isDualPaneDevice = false]) {
    return Column(
      children: [
        // Catalog takes the full body
        Expanded(child: _buildCatalogAndDiscountsPane(colors, isDark, isShortHeight, isDualPaneDevice)),

        // Bottom floating order summary & cart bar
        ListenableBuilder(
          listenable: _cartController,
          builder: (context, _) {
            final count = _cartController.itemCount;
            final net = _cartController.taxBreakdown.netPayable;

            return Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: isShortHeight ? 6 : 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$count item(s) in order',
                          style: GoogleFonts.inter(fontSize: isShortHeight ? 10 : 11, color: colors.textSecondary),
                        ),
                        Text(
                          '₱${net.toStringAsFixed(2)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: isShortHeight ? 15 : 18,
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: isShortHeight ? 34 : 42,
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.shopping_bag_outlined, size: isShortHeight ? 14 : 16),
                      label: Text(count > 0 ? 'View Cart ($count)' : 'View Cart'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        minimumSize: Size(isShortHeight ? 100 : 120, isShortHeight ? 34 : 42),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.symmetric(horizontal: isShortHeight ? 10 : 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          builder: (context) {
                            return FractionallySizedBox(
                              heightFactor: isShortHeight ? 0.96 : 0.88,
                              child: _buildCartPane(colors, isDark, isShortHeight, true),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
