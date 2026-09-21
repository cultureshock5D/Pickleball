import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/neon_button.dart';

class CashTenderModal extends StatefulWidget {
  final double netPayable;

  const CashTenderModal({
    super.key,
    required this.netPayable,
  });

  static Future<double?> show(BuildContext context, {required double netPayable}) {
    return showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CashTenderModal(netPayable: netPayable),
    );
  }

  @override
  State<CashTenderModal> createState() => _CashTenderModalState();
}

class _CashTenderModalState extends State<CashTenderModal> {
  String _tenderStr = '';

  double get _currentTender {
    return double.tryParse(_tenderStr) ?? 0.0;
  }

  double get _changeDue {
    final diff = ((_currentTender - widget.netPayable) * 100).round() / 100.0;
    return diff.clamp(0.0, 999999.0);
  }

  bool get _isSufficient {
    return _currentTender >= (widget.netPayable - 0.001);
  }

  @override
  void initState() {
    super.initState();
    // Default tender to exact or next rounded hundred
    final rounded = (widget.netPayable / 100).ceil() * 100.0;
    _tenderStr = (rounded > widget.netPayable ? rounded : widget.netPayable).toStringAsFixed(0);
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
      _tenderStr = widget.netPayable.toStringAsFixed(2);
    });
  }

  void _addQuickBill(double bill) {
    HapticFeedback.selectionClick();
    setState(() {
      _tenderStr = bill.toStringAsFixed(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Center(
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(24),
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
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.accentColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.payments_outlined,
                          color: AppTheme.accentColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Cash Tender & Change',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: colors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Net Payable & Tender Display Cards
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TOTAL DUE',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₱${widget.netPayable.toStringAsFixed(2)}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(12),
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
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₱${_changeDue.toStringAsFixed(2)}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: _isSufficient
                                  ? AppTheme.accentColor
                                  : Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Tender input display
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tendered:',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: colors.textSecondary,
                      ),
                    ),
                    Text(
                      '₱${_tenderStr.isEmpty ? '0.00' : _tenderStr}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.accentColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Quick Bill Denominations
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildQuickBillChip('Exact', _setExact, colors, isAccent: true),
                  _buildQuickBillChip('₱100', () => _addQuickBill(100), colors),
                  _buildQuickBillChip('₱200', () => _addQuickBill(200), colors),
                  _buildQuickBillChip('₱500', () => _addQuickBill(500), colors),
                  _buildQuickBillChip('₱1,000', () => _addQuickBill(1000), colors),
                ],
              ),
              const SizedBox(height: 16),

              // Numeric Keypad
              Column(
                children: [
                  _buildKeypadRow(['1', '2', '3'], colors),
                  const SizedBox(height: 8),
                  _buildKeypadRow(['4', '5', '6'], colors),
                  const SizedBox(height: 8),
                  _buildKeypadRow(['7', '8', '9'], colors),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActionKey(label: 'C', onTap: _onClear, colors: colors, width: 68),
                      _buildNumericKey('0', colors, width: 68),
                      _buildActionKey(label: '.', onTap: _onDot, colors: colors, width: 68),
                      _buildActionKey(
                        icon: Icons.backspace_outlined,
                        onTap: _onBackspace,
                        colors: colors,
                        width: 68,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Confirm Button
              NeonButton(
                text: _isSufficient
                    ? 'Confirm Tender & Pay (Change: ₱${_changeDue.toStringAsFixed(2)})'
                    : 'Insufficient Cash Tendered',
                onPressed: _isSufficient
                    ? () {
                        HapticFeedback.mediumImpact();
                        Navigator.of(context).pop(_currentTender);
                      }
                    : null,
              ),
            ],
          ),
        ),
      ),
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
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isAccent
              ? AppTheme.accentColor.withValues(alpha: 0.2)
              : colors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isAccent ? AppTheme.accentColor : colors.border,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
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

  Widget _buildNumericKey(String digit, dynamic colors, {double width = 72}) {
    return SizedBox(
      width: width,
      height: 44,
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _onDigit(digit),
          child: Center(
            child: Text(
              digit,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
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
    double width = 72,
  }) {
    return SizedBox(
      width: width,
      height: 44,
      child: Material(
        color: colors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Center(
            child: label != null
                ? Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: colors.textSecondary,
                    ),
                  )
                : Icon(
                    icon,
                    size: 18,
                    color: colors.textSecondary,
                  ),
          ),
        ),
      ),
    );
  }
}
