import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/services/theme_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../models/pos_cart_item_model.dart';
import '../../models/pos_product_model.dart';
import 'controllers/pos_cart_controller.dart';
import 'controllers/pos_catalog_controller.dart';
import '../../services/auth_service.dart';
import '../../widgets/auth_gate.dart';
import '../home/main_navigation_screen.dart';
import 'widgets/cash_tender_modal.dart';
import 'widgets/pos_printer_debug_modal.dart';
import 'widgets/recent_invoices_drawer.dart';
import 'widgets/thermal_receipt_modal.dart';

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

  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _discountIdController = TextEditingController();
  final TextEditingController _customerTinController = TextEditingController();

  @override
  void initState() {
    super.initState();

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

    _customerNameController.addListener(() {
      _cartController.setCustomerDetails(name: _customerNameController.text);
    });
    _discountIdController.addListener(() {
      _cartController.setCustomerDetails(idNumber: _discountIdController.text);
    });
    _customerTinController.addListener(() {
      _cartController.setCustomerDetails(tin: _customerTinController.text);
    });
  }

  @override
  void dispose() {
    _catalogController.dispose();
    _cartController.dispose();
    _searchController.dispose();
    _customerNameController.dispose();
    _discountIdController.dispose();
    _customerTinController.dispose();
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
            'Clear Active Order?',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          content: Text(
            'Remove all ${_cartController.itemCount} item(s) from current order?',
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
      _customerNameController.clear();
      _discountIdController.clear();
      _customerTinController.clear();
      if (mounted) {
        AppSnackBar.info(context, 'Cart has been cleared.');
      }
    }
  }

  Future<void> _handleCheckout() async {
    final validationErr = _cartController.validateForCheckout(checkTender: false);
    if (validationErr != null) {
      AppSnackBar.error(context, validationErr);
      return;
    }

    // Cash tender modal and immediate checkout
    final tender = await CashTenderModal.show(
      context,
      netPayable: _cartController.taxBreakdown.netPayable,
    );
    if (tender == null) return;
    _cartController.setTenderAmount(tender);

    final tx = await _cartController.checkout(
      cashierId: widget.cashierId,
      cashierName: widget.cashierName,
    );

    if (!mounted) return;

    if (tx != null) {
      _customerNameController.clear();
      _discountIdController.clear();
      _customerTinController.clear();
      _catalogController.loadCatalog();
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
                    MaterialPageRoute(builder: (context) => const AuthGate()),
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
    final screenWidth = MediaQuery.sizeOf(context).width;

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

    final showPermanentSidebar = screenWidth >= 1100;
    final isDualPane = screenWidth >= 800;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark ? const Color(0xFF090E14) : const Color(0xFFF8FAFC),
      drawer: !isDualPane ? _buildSidebarDrawer(colors, isDark) : null,
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
            // Left Sidebar (Desktop / Wide Tablet)
            if (showPermanentSidebar)
              SizedBox(
                width: 220,
                child: SingleChildScrollView(
                  child: _buildSidebarContent(colors, isDark),
                ),
              ),

            if (showPermanentSidebar)
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              ),

            // Main Content Area
            Expanded(
              child: Column(
                children: [
                  // Top Header Bar
                  _buildHeaderBar(colors, isDark, showPermanentSidebar),

                  // Divider below header
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  ),

                  // Catalog & Cart Body
                  Expanded(
                    child: isDualPane
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Center Pane: Catalog & Philippine BIR Panel
                              Expanded(
                                flex: 62,
                                child: _buildCatalogAndDiscountsPane(colors, isDark),
                              ),

                              VerticalDivider(
                                width: 1,
                                thickness: 1,
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                              ),

                              // Right Pane: Active Order & Tender
                              Expanded(
                                flex: 38,
                                child: _buildCartPane(colors, isDark),
                              ),
                            ],
                          )
                        : _buildMobileLayout(colors, isDark),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- TOP HEADER BAR ---
  Widget _buildHeaderBar(dynamic colors, bool isDark, bool hasSidebar) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 750;
        final isVeryCompact = constraints.maxWidth < 450;

        return Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          child: Row(
            children: [
              if (!hasSidebar) ...[
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.menu_rounded, color: colors.textPrimary),
                  tooltip: 'Navigation Menu',
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                ),
                const SizedBox(width: 2),
              ],

              // C&J Brand logo & Active Pill
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!hasSidebar) ...[
                    Container(
                      height: 30,
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
                            hasSidebar ? 'C&J ARENA' : 'ARENA',
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

  // --- SIDEBAR DRAWER (Mobile) ---
  Widget _buildSidebarDrawer(dynamic colors, bool isDark) {
    return Drawer(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: SafeArea(
        child: SingleChildScrollView(
          child: _buildSidebarContent(colors, isDark),
        ),
      ),
    );
  }

  // --- SIDEBAR CONTENT (Desktop & Drawer) ---
  Widget _buildSidebarContent(dynamic colors, bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF0F172A) : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
            isActive: true,
            isDark: isDark,
            colors: colors,
          ),
          _buildSidebarNavItem(
            icon: Icons.inventory_2_outlined,
            label: 'Inventory Table',
            isActive: false,
            isDark: isDark,
            colors: colors,
          ),
          _buildSidebarNavItem(
            icon: Icons.show_chart_rounded,
            label: 'Daily Expenses & Margins',
            isActive: false,
            isDark: isDark,
            colors: colors,
          ),
          _buildSidebarNavItem(
            icon: Icons.receipt_long_outlined,
            label: 'Shift Reports',
            isActive: false,
            isDark: isDark,
            colors: colors,
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
                    color: Color(0xFFEAB308), // Yellow active dot on right
                    shape: BoxShape.circle,
                  ),
                )
              : null,
          onTap: () {
            if (!isActive) {
              AppSnackBar.info(context, '$label is viewing-only in POS mode.');
            }
          },
        ),
      ),
    );
  }

  // --- CATALOG & DISCOUNTS PANE (CENTER) ---
  Widget _buildCatalogAndDiscountsPane(dynamic colors, bool isDark) {
    return ListenableBuilder(
      listenable: _catalogController,
      builder: (context, _) {
        return Column(
          children: [
            // Cockpit Terminal Header & Actions
            _buildCockpitHeader(colors, isDark),

            // Department Navigation Pills Bar
            _buildDepartmentPills(colors, isDark),

            // Subcategory Filter Chips Bar
            _buildSubcategoryChips(colors, isDark),

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
                          ? _buildProductCardsView(colors, isDark)
                          : _buildProductTableView(colors, isDark),
            ),

            // Bottom Philippine BIR Statutory Discounts Panel
            _buildBirDiscountsBottomPanel(colors, isDark),
          ],
        );
      },
    );
  }

  // Cockpit Terminal Header
  Widget _buildCockpitHeader(dynamic colors, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 750;

        final titleWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444), // Red/coral dot
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'ARENA COCKPIT TERMINAL • ACTIVE SHIFT',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: const Color(0xFFEF4444),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'POINT OF SALE & PRO SHOP',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
          ],
        );

        final actionsWidget = Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Recent Invoices & Void trigger
            OutlinedButton.icon(
              icon: const Icon(Icons.history_rounded, size: 15),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(isNarrow ? 'Invoices & Void' : 'Recent Invoices & Void'),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '25',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 34),
                foregroundColor: colors.textPrimary,
                side: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            ),

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
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        color: !_catalogController.isGridView
                            ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: !_catalogController.isGridView
                            ? [const BoxShadow(color: Colors.black12, blurRadius: 4)]
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
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => _catalogController.setGridView(true),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        color: _catalogController.isGridView
                            ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: _catalogController.isGridView
                            ? [const BoxShadow(color: Colors.black12, blurRadius: 4)]
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
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Search Box
            SizedBox(
              width: 150,
              height: 34,
              child: TextField(
                controller: _searchController,
                onChanged: _catalogController.updateSearch,
                style: GoogleFonts.inter(fontSize: 11, color: colors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search SKU...',
                  hintStyle: GoogleFonts.inter(fontSize: 11, color: colors.textSecondary),
                  prefixIcon: Icon(Icons.search, size: 15, color: colors.textSecondary),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 13),
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            _searchController.clear();
                            _catalogController.updateSearch('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
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
        );

        return Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleWidget,
                    const SizedBox(height: 8),
                    actionsWidget,
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: titleWidget),
                    actionsWidget,
                  ],
                ),
        );
      },
    );
  }

  // Department Filter Navigation Pills
  Widget _buildDepartmentPills(dynamic colors, bool isDark) {
    final depts = [
      {'key': 'Coffee', 'name': 'Coffee', 'icon': '☕', 'tint': const Color(0xFFFEF3C7), 'text': const Color(0xFF92400E)},
      {'key': 'Drinks', 'name': 'Drinks', 'icon': '🥤', 'tint': const Color(0xFFE0F2FE), 'text': const Color(0xFF0369A1)},
      {'key': 'Food', 'name': 'Food', 'icon': '🍳', 'tint': const Color(0xFFFFEDD5), 'text': const Color(0xFFC2410C)},
      {'key': 'Supplies', 'name': 'Supplies', 'icon': '📦', 'tint': const Color(0xFFF1F5F9), 'text': const Color(0xFF475569)},
      {'key': 'All', 'name': 'All Menu', 'icon': '🌐', 'tint': const Color(0xFF0F172A), 'text': Colors.white},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                    Text(icon, style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 6),
                    Text(
                      name,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected ? Colors.white : (isDark ? Colors.white70 : defaultTextColor),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF38BDF8)
                            : (isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: GoogleFonts.inter(
                          fontSize: 10,
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
  Widget _buildSubcategoryChips(dynamic colors, bool isDark) {
    final categories = _catalogController.availableCategories;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                        fontSize: 10,
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

  // --- PRODUCT TABLE VIEW (Matching c-jpickle design) ---
  Widget _buildProductTableView(dynamic colors, bool isDark) {
    return ListenableBuilder(
      listenable: _cartController,
      builder: (context, _) {
        final products = _catalogController.filteredProducts;

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            final cartQty = _cartController.quantityForProduct(product.id);
            final isOos = product.isOutOfStock;
            final isLowStock = product.stockLevel > 0 && product.stockLevel <= 5;

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  // SKU Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Text(
                      product.sku ?? 'SKU-${index + 1}',
                      style: GoogleFonts.robotoMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Product Image Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: 36,
                      height: 36,
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

                  // Name
                  Expanded(
                    flex: 3,
                    child: Text(
                      product.name,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isOos ? colors.textSecondary : colors.textPrimary,
                      ),
                    ),
                  ),

                  // Category Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      product.category.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Stock indicator
                  SizedBox(
                    width: 85,
                    child: isOos
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Out of stock',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFDC2626),
                              ),
                            ),
                          )
                        : isLowStock
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFEDD5),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Low (${product.stockLevel})',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFC2410C),
                                  ),
                                ),
                              )
                            : Text(
                                '${product.stockLevel} in stock',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF059669),
                                ),
                              ),
                  ),
                  const SizedBox(width: 10),

                  // Price
                  SizedBox(
                    width: 65,
                    child: Text(
                      '₱${product.price.toStringAsFixed(2)}',
                      textAlign: TextAlign.right,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isOos ? colors.textSecondary : colors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Add button or Qty Stepper
                  if (isOos)
                    const SizedBox(
                      width: 70,
                      child: Center(
                        child: Text(
                          'UNAVAILABLE',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.redAccent,
                          ),
                        ),
                      ),
                    )
                  else if (cartQty > 0)
                    Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: () {
                              final cartItem = _cartController.items.firstWhere(
                                (item) => item.productId == product.id,
                              );
                              _handleDecrementItem(cartItem);
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 5),
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
                              padding: EdgeInsets.symmetric(horizontal: 5),
                              child: Icon(Icons.add, size: 13, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      height: 32,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(64, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        onPressed: () => _handleAddToCart(product),
                        child: Text(
                          '+ Add',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- PRODUCT CARDS VIEW ---
  Widget _buildProductCardsView(dynamic colors, bool isDark) {
    return ListenableBuilder(
      listenable: _cartController,
      builder: (context, _) {
        final products = _catalogController.filteredProducts;

        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.68,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            final cartQty = _cartController.quantityForProduct(product.id);
            final isOos = product.isOutOfStock;
            final isLowStock = product.stockLevel > 0 && product.stockLevel <= 5;

            return InkWell(
              onTap: isOos ? null : () => _handleAddToCart(product),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
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
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 82,
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
                    const SizedBox(height: 6),

                    // SKU & Cart Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            product.sku ?? 'SKU-${index + 1}',
                            style: GoogleFonts.robotoMono(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                        if (cartQty > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$cartQty in cart',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Name
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isOos ? colors.textSecondary : colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),

                    // Category
                    Text(
                      product.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 10, color: colors.textSecondary),
                    ),
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
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.redAccent,
                                  ),
                                )
                              : isLowStock
                                  ? Text(
                                      'Low (${product.stockLevel})',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFFC2410C),
                                      ),
                                    )
                                  : Text(
                                      'Stock: ${product.stockLevel}',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
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
                                fontSize: 13,
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

  // --- PHILIPPINE BIR EOPT & STATUTORY DISCOUNTS (Bottom Panel) ---
  Widget _buildBirDiscountsBottomPanel(dynamic colors, bool isDark) {
    return ListenableBuilder(
      listenable: _cartController,
      builder: (context, _) {
        final current = _cartController.discountType;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            border: Border(
              top: BorderSide(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified_user_outlined, size: 15, color: Color(0xFF10B981)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'PHILIPPINE BIR EOPT & STATUTORY DISCOUNTS',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Segmented 3 tabs: [Regular] [Senior Citizen] [PWD]
              Row(
                children: [
                  _buildDiscountTab('none', 'Regular', current, isDark, colors),
                  const SizedBox(width: 8),
                  _buildDiscountTab('senior_citizen', 'Senior Citizen', current, isDark, colors),
                  const SizedBox(width: 8),
                  _buildDiscountTab('pwd', 'PWD', current, isDark, colors),
                ],
              ),

              // Inputs for Senior / PWD
              if (current != 'none') ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 34,
                        child: TextField(
                          controller: _customerNameController,
                          style: GoogleFonts.inter(fontSize: 11, color: colors.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Customer / Cardholder Name *',
                            hintStyle: GoogleFonts.inter(fontSize: 11, color: colors.textSecondary),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 34,
                        child: TextField(
                          controller: _discountIdController,
                          style: GoogleFonts.inter(fontSize: 11, color: colors.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'OSCA / PWD ID Number *',
                            hintStyle: GoogleFonts.inter(fontSize: 11, color: colors.textSecondary),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDiscountTab(
    String key,
    String label,
    String current,
    bool isDark,
    dynamic colors,
  ) {
    final isSelected = current == key;

    return Expanded(
      child: InkWell(
        onTap: () => _cartController.setDiscountType(key),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
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
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? Colors.white : colors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  // --- RIGHT PANE: ACTIVE ORDER & TENDER ---
  Widget _buildCartPane(dynamic colors, bool isDark) {
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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
                    Row(
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
                        Text(
                          'Active Order (${_cartController.itemCount} items)',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF0F9FF),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.shopping_cart_outlined,
                                size: 32,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Order cart is empty',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Click catalog items on the left to add to order',
                              style: GoogleFonts.inter(fontSize: 11, color: colors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _cartController.items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final item = _cartController.items[index];
                          return _buildCartItemTile(item, colors, isDark);
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
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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

                    const SizedBox(height: 12),

                    // Financial Breakdown
                    _buildSummaryLine('Gross Subtotal:', '₱${tax.grossSubtotal.toStringAsFixed(2)}', colors),
                    if (tax.discountAmount > 0)
                      _buildSummaryLine(
                        'Statutory 20% Discount:',
                        '-₱${tax.discountAmount.toStringAsFixed(2)}',
                        colors,
                        isHighlight: true,
                      ),
                    _buildSummaryLine('Vatable Sales:', '₱${tax.vatableSales.toStringAsFixed(2)}', colors),
                    _buildSummaryLine('12% VAT:', '₱${tax.vatAmount.toStringAsFixed(2)}', colors),
                    if (tax.vatExemptSales > 0)
                      _buildSummaryLine('VAT-Exempt Sales:', '₱${tax.vatExemptSales.toStringAsFixed(2)}', colors),

                    const SizedBox(height: 4),

                    // Net Payable Large Text
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          'NET PAYABLE:',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          '₱${tax.netPayable.toStringAsFixed(2)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Complete and Print Invoice Button
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.shopping_cart_outlined, size: 17),
                        label: Text(
                          'COMPLETE & PRINT INVOICE (₱${tax.netPayable.toStringAsFixed(2)})',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _cartController.isEmpty
                              ? (isDark ? const Color(0xFF334155) : const Color(0xFF94A3B8))
                              : const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 46),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _cartController.isEmpty || _cartController.isProcessing
                            ? null
                            : _handleCheckout,
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

  Widget _buildCartItemTile(PosCartItemModel item, dynamic colors, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          // Cart Item Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: 34,
              height: 34,
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
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  '₱${item.unitPrice.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(fontSize: 11, color: colors.textSecondary),
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
                  size: 14,
                  color: item.quantity == 1 ? Colors.redAccent : colors.textPrimary,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                onPressed: () => _handleDecrementItem(item),
              ),
              Text(
                '${item.quantity}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 14),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                onPressed: () => _cartController.incrementItem(item.productId),
              ),
            ],
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 65,
            child: Text(
              '₱${item.subtotal.toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
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

  Widget _buildSummaryLine(String label, String value, dynamic colors, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: isHighlight ? const Color(0xFFD97706) : colors.textSecondary,
              fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: isHighlight ? const Color(0xFFD97706) : colors.textPrimary,
              fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // --- MOBILE LAYOUT (With Zero Infinite-Width Bugs) ---
  Widget _buildMobileLayout(dynamic colors, bool isDark) {
    return Column(
      children: [
        // Catalog takes the body
        Expanded(child: _buildCatalogAndDiscountsPane(colors, isDark)),

        // Bottom floating order summary & cart bar
        ListenableBuilder(
          listenable: _cartController,
          builder: (context, _) {
            final count = _cartController.itemCount;
            final net = _cartController.taxBreakdown.netPayable;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                          style: GoogleFonts.inter(fontSize: 11, color: colors.textSecondary),
                        ),
                        Text(
                          '₱${net.toStringAsFixed(2)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 42,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.shopping_bag_outlined, size: 16),
                      label: Text(count > 0 ? 'View Cart ($count)' : 'View Cart'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(120, 42),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
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
                              heightFactor: 0.85,
                              child: _buildCartPane(colors, isDark),
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
