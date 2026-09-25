import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/bir_tax_breakdown.dart';
import '../../../widgets/neon_button.dart';
import '../controllers/pos_cart_controller.dart';

class CashTenderModal extends StatefulWidget {
  final PosCartController? cartController;
  final double? netPayable;

  const CashTenderModal({
    super.key,
    this.cartController,
    this.netPayable,
  });

  static Future<double?> show(
    BuildContext context, {
    PosCartController? cartController,
    double? netPayable,
  }) {
    assert(
      cartController != null || netPayable != null,
      'Either cartController or netPayable must be provided',
    );
    return showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CashTenderModal(
        cartController: cartController,
        netPayable: netPayable,
      ),
    );
  }

  @override
  State<CashTenderModal> createState() => _CashTenderModalState();
}

class _CashTenderModalState extends State<CashTenderModal> {
  String _tenderStr = '';
  late String _discountType;
  late final TextEditingController _nameController;
  late final TextEditingController _idController;
  String? _validationError;

  BirTaxBreakdown get _taxBreakdown {
    if (widget.cartController != null) {
      return BirTaxBreakdown.compute(
        gross: widget.cartController!.grossSubtotal,
        discountType: _discountType,
      );
    }
    final gross = widget.netPayable ?? 0.0;
    return BirTaxBreakdown.compute(
      gross: gross,
      discountType: _discountType,
    );
  }

  double get _effectiveNetPayable => _taxBreakdown.netPayable;

  double get _currentTender {
    return double.tryParse(_tenderStr) ?? 0.0;
  }

  double get _changeDue {
    final diff = ((_currentTender - _effectiveNetPayable) * 100).round() / 100.0;
    return diff.clamp(0.0, 999999.0);
  }

  bool get _isSufficient {
    return _currentTender >= (_effectiveNetPayable - 0.001);
  }

  @override
  void initState() {
    super.initState();
    _discountType = widget.cartController?.discountType ?? 'none';
    _nameController = TextEditingController(text: widget.cartController?.customerName ?? '');
    _idController = TextEditingController(text: widget.cartController?.discountIdNumber ?? '');

    // Default tender to exact or next rounded hundred
    final net = _effectiveNetPayable;
    final rounded = (net / 100).ceil() * 100.0;
    _tenderStr = (rounded > net ? rounded : net).toStringAsFixed(0);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    super.dispose();
  }

  void _onDigit(String d) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_tenderStr == '0') {
        _tenderStr = d;
      } else {
        _tenderStr += d;
      }
    });
  }

  void _onBackspace() {
    HapticFeedback.lightImpact();
    setState(() {
      if (_tenderStr.isNotEmpty) {
        _tenderStr = _tenderStr.substring(0, _tenderStr.length - 1);
      }
    });
  }

  void _onDot() {
    HapticFeedback.lightImpact();
    setState(() {
      if (_tenderStr.isEmpty) {
        _tenderStr = '0.';
      } else if (!_tenderStr.contains('.')) {
        _tenderStr += '.';
      }
    });
  }

  void _onClear() {
    HapticFeedback.selectionClick();
    setState(() {
      _tenderStr = '';
    });
  }

  void _setExact() {
    HapticFeedback.selectionClick();
    setState(() {
      _tenderStr = _effectiveNetPayable.toStringAsFixed(2);
    });
  }

  void _addQuickBill(double bill) {
    HapticFeedback.selectionClick();
    setState(() {
      _tenderStr = bill.toStringAsFixed(0);
    });
  }

  void _onDiscountSelected(String type) {
    HapticFeedback.selectionClick();
    setState(() {
      _discountType = type;
      _validationError = null;

      // When discount changes, re-adjust tender if current tender is now less than net
      final net = _effectiveNetPayable;
      if (_currentTender < net) {
        final rounded = (net / 100).ceil() * 100.0;
        _tenderStr = (rounded > net ? rounded : net).toStringAsFixed(0);
      }
    });
  }

  void _handleConfirm() {
    if (_discountType != 'none') {
      if (_nameController.text.trim().isEmpty) {
        setState(() => _validationError = 'Customer / Cardholder Name is required.');
        return;
      }
      if (_idController.text.trim().isEmpty) {
        setState(() => _validationError = 'Discount ID is required.');
        return;
      }
    }

    if (widget.cartController != null) {
      widget.cartController!.setDiscountType(_discountType);
      widget.cartController!.setCustomerDetails(
        name: _nameController.text.trim(),
        idNumber: _idController.text.trim(),
      );
      widget.cartController!.setTenderAmount(_currentTender);
    }

    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(_currentTender);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);
    final isLandscape = size.width >= 650 && size.height < 600;
    final dialogWidth = isLandscape ? 660.0 : 420.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Center(
        child: Container(
          width: dialogWidth,
          constraints: BoxConstraints(maxHeight: size.height * 0.94),
          padding: EdgeInsets.all(isLandscape ? 16 : 20),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colors.border.withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppTheme.accentColor.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.payments_outlined,
                            color: AppTheme.accentColor,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Cash Tender & Change',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: isLandscape ? 16 : 18,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.close, color: colors.textSecondary, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                SizedBox(height: isLandscape ? 10 : 14),

                // Main body: 2 columns in landscape, 1 column in portrait
                if (isLandscape)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column: BIR discounts + Totals + Tender input & Quick bills
                      Expanded(
                        flex: 11,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildBirDiscountSection(colors, isDark),
                            const SizedBox(height: 10),
                            _buildPayableAndChangeCards(colors),
                            const SizedBox(height: 10),
                            _buildTenderDisplay(colors),
                            const SizedBox(height: 8),
                            _buildQuickBillChips(colors),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Right Column: Keypad + Confirm button
                      Expanded(
                        flex: 9,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildKeypad(colors),
                            const SizedBox(height: 12),
                            _buildConfirmButton(),
                          ],
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Compact Philippine BIR Statutory Discounts Section
                      _buildBirDiscountSection(colors, isDark),
                      const SizedBox(height: 12),

                      // Net Payable & Change Due Display Cards
                      _buildPayableAndChangeCards(colors),
                      const SizedBox(height: 12),

                      // Tendered Input Display
                      _buildTenderDisplay(colors),
                      const SizedBox(height: 10),

                      // Quick Bill Denominations
                      _buildQuickBillChips(colors),
                      const SizedBox(height: 14),

                      // Numeric Keypad
                      _buildKeypad(colors),
                      const SizedBox(height: 16),

                      // Confirm Button
                      _buildConfirmButton(),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- COMPACT PHILIPPINE BIR SECTION ---
  Widget _buildBirDiscountSection(dynamic colors, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _discountType != 'none'
              ? const Color(0xFF10B981).withValues(alpha: 0.6)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_outlined, size: 13, color: Color(0xFF10B981)),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'PHILIPPINE BIR STATUTORY DISCOUNT',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: colors.textSecondary,
                  ),
                ),
              ),
              if (_discountType != 'none')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _discountType == 'student'
                        ? '10% OFF (VAT INCL)'
                        : (_discountType == 'staff'
                            ? '15% OFF (VAT INCL)'
                            : '20% OFF + VAT EXEMPT'),
                    style: GoogleFonts.inter(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),

          // 5 Responsive Discount Options (Scrollable for compact screens)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildDiscountOption('none', 'Regular', colors, isDark),
                const SizedBox(width: 6),
                _buildDiscountOption('senior_citizen', 'Senior (20%)', colors, isDark),
                const SizedBox(width: 6),
                _buildDiscountOption('pwd', 'PWD (20%)', colors, isDark),
                const SizedBox(width: 6),
                _buildDiscountOption('student', 'Student (10%)', colors, isDark),
                const SizedBox(width: 6),
                _buildDiscountOption('staff', 'Staff (15%)', colors, isDark),
              ],
            ),
          ),

          // Conditional Input Fields for Discounts
          if (_discountType != 'none') ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 32,
                    child: TextField(
                      controller: _nameController,
                      style: GoogleFonts.inter(fontSize: 11, color: colors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Customer Name *',
                        hintStyle: GoogleFonts.inter(fontSize: 10, color: colors.textSecondary),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
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
                const SizedBox(width: 6),
                Expanded(
                  child: SizedBox(
                    height: 32,
                    child: TextField(
                      controller: _idController,
                      style: GoogleFonts.inter(fontSize: 11, color: colors.textPrimary),
                      decoration: InputDecoration(
                        hintText: _discountType == 'student'
                            ? 'Student ID # *'
                            : (_discountType == 'staff'
                                ? 'Staff ID # *'
                                : 'OSCA / PWD ID # *'),
                        hintStyle: GoogleFonts.inter(fontSize: 10, color: colors.textSecondary),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
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

          if (_validationError != null) ...[
            const SizedBox(height: 4),
            Text(
              _validationError!,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.redAccent,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDiscountOption(String key, String label, dynamic colors, bool isDark) {
    final isSelected = _discountType == key;

    return InkWell(
      onTap: () => _onDiscountSelected(key),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF0F172A)
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF0F172A)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : colors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildPayableAndChangeCards(dynamic colors) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TOTAL DUE',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '₱${_effectiveNetPayable.toStringAsFixed(2)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _isSufficient
                    ? AppTheme.accentColor.withValues(alpha: 0.6)
                    : Colors.redAccent.withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CHANGE DUE',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '₱${_changeDue.toStringAsFixed(2)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: _isSufficient ? AppTheme.accentColor : Colors.redAccent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTenderDisplay(dynamic colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Tendered:',
            style: GoogleFonts.inter(fontSize: 13, color: colors.textSecondary),
          ),
          Text(
            '₱${_tenderStr.isEmpty ? '0.00' : _tenderStr}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.accentColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickBillChips(dynamic colors) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _buildQuickBillChip('Exact', _setExact, colors, isAccent: true),
        _buildQuickBillChip('₱100', () => _addQuickBill(100), colors),
        _buildQuickBillChip('₱200', () => _addQuickBill(200), colors),
        _buildQuickBillChip('₱500', () => _addQuickBill(500), colors),
        _buildQuickBillChip('₱1,000', () => _addQuickBill(1000), colors),
      ],
    );
  }

  Widget _buildKeypad(dynamic colors) {
    return Column(
      children: [
        _buildKeypadRow(['1', '2', '3'], colors),
        const SizedBox(height: 6),
        _buildKeypadRow(['4', '5', '6'], colors),
        const SizedBox(height: 6),
        _buildKeypadRow(['7', '8', '9'], colors),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionKey(label: 'C', onTap: _onClear, colors: colors),
            _buildNumericKey('0', colors),
            _buildActionKey(label: '.', onTap: _onDot, colors: colors),
            _buildActionKey(
              icon: Icons.backspace_outlined,
              onTap: _onBackspace,
              colors: colors,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConfirmButton() {
    return NeonButton(
      text: _isSufficient
          ? 'Confirm Tender & Pay (Change: ₱${_changeDue.toStringAsFixed(2)})'
          : 'Insufficient Cash Tendered',
      onPressed: _isSufficient ? _handleConfirm : null,
    );
  }

  Widget _buildQuickBillChip(
    String label,
    VoidCallback onTap,
    dynamic colors, {
    bool isAccent = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isAccent ? AppTheme.accentColor.withValues(alpha: 0.2) : colors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isAccent ? AppTheme.accentColor : colors.border,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isAccent ? AppTheme.accentColor : colors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildKeypadRow(List<String> keys, dynamic colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((k) => _buildNumericKey(k, colors)).toList(),
    );
  }

  Widget _buildNumericKey(String digit, dynamic colors, {double width = 62}) {
    return SizedBox(
      width: width,
      height: 40,
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _onDigit(digit),
          child: Center(
            child: Text(
              digit,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionKey({
    String? label,
    IconData? icon,
    required VoidCallback onTap,
    required dynamic colors,
    double width = 62,
  }) {
    return SizedBox(
      width: width,
      height: 40,
      child: Material(
        color: colors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Center(
            child: label != null
                ? Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colors.textSecondary,
                    ),
                  )
                : Icon(
                    icon,
                    size: 16,
                    color: colors.textSecondary,
                  ),
          ),
        ),
      ),
    );
  }
}

