import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../models/cashier_duty_session_model.dart';
import '../../../models/pos_transaction_model.dart';
import '../../../services/pos_service.dart';
import 'thermal_receipt_modal.dart';

class ShiftReportsView extends StatefulWidget {
  final VoidCallback onBackToRegister;
  final VoidCallback? onToggleMenu;

  const ShiftReportsView({
    super.key,
    required this.onBackToRegister,
    this.onToggleMenu,
  });

  @override
  State<ShiftReportsView> createState() => _ShiftReportsViewState();
}

class _ShiftReportsViewState extends State<ShiftReportsView> {
  final PosService _posService = PosService.instance;

  bool _isLoading = true;
  List<CashierDutySessionModel> _sessions = [];
  CashierDutySessionModel? _selectedSession;
  List<PosTransactionModel> _shiftTransactions = [];
  StreamSubscription<void>? _updatesSub;

  final currencyFmt = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
  final dateTimeFmt = DateFormat('MMM dd, yyyy • hh:mm a');

  @override
  void initState() {
    super.initState();
    _loadShiftData();
    _updatesSub = _posService.onPosUpdates.listen((_) {
      if (mounted) _loadShiftData(isSilent: true);
    });
  }

  @override
  void dispose() {
    _updatesSub?.cancel();
    super.dispose();
  }

  Future<void> _loadShiftData({bool isSilent = false}) async {
    if (!isSilent) {
      setState(() => _isLoading = true);
    }
    try {
      final sessions = await _posService.fetchDutySessions();
      final allTransactions = await _posService.fetchTransactions();

      if (mounted) {
        setState(() {
          _sessions = sessions;
          _selectedSession = _sessions.isNotEmpty ? _sessions.first : null;

          if (_selectedSession != null) {
            _shiftTransactions = allTransactions.where((t) {
              final isAfterStart =
                  t.createdAt.isAfter(_selectedSession!.startedAt) ||
                      t.createdAt.isAtSameMomentAs(_selectedSession!.startedAt);
              if (_selectedSession!.endedAt != null) {
                return isAfterStart &&
                    t.createdAt.isBefore(_selectedSession!.endedAt!);
              }
              return isAfterStart;
            }).toList();
          } else {
            _shiftTransactions = allTransactions;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppSnackBar.error(context, 'Failed to load shift report: $e');
      }
    }
  }

  void _onSessionSelected(CashierDutySessionModel session) async {
    setState(() {
      _selectedSession = session;
      _isLoading = true;
    });

    final allTransactions = await _posService.fetchTransactions();
    if (mounted) {
      setState(() {
        _shiftTransactions = allTransactions.where((t) {
          final isAfterStart = t.createdAt.isAfter(session.startedAt) ||
              t.createdAt.isAtSameMomentAs(session.startedAt);
          if (session.endedAt != null) {
            return isAfterStart && t.createdAt.isBefore(session.endedAt!);
          }
          return isAfterStart;
        }).toList();
        _isLoading = false;
      });
    }
  }

  void _showCloseDrawerDialog() {
    final palette = context.colors;
    final countController = TextEditingController();

    // Calculations
    final activeTxs = _shiftTransactions.where((t) => !t.isVoided).toList();
    final cashSales = activeTxs
        .where((t) => t.paymentMethod.toLowerCase() == 'cash')
        .fold<double>(0.0, (s, t) => s + t.totalAmount);
    final openingFloat = _selectedSession?.openingFloat ?? 1000.00;
    final expectedCash = openingFloat + cashSales;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final enteredCount = double.tryParse(countController.text) ?? 0.0;
          final difference = enteredCount - expectedCash;

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
                  child: Icon(Icons.point_of_sale_rounded,
                      color: palette.neonGreen, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'End Shift & Balance Drawer',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
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
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Opening Float:',
                                style: TextStyle(
                                    color: palette.textMuted, fontSize: 12)),
                            Text(currencyFmt.format(openingFloat),
                                style: TextStyle(
                                    color: palette.textPrimary, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Shift Cash Sales:',
                                style: TextStyle(
                                    color: palette.textMuted, fontSize: 12)),
                            Text(currencyFmt.format(cashSales),
                                style: TextStyle(
                                    color: palette.textPrimary, fontSize: 12)),
                          ],
                        ),
                        Divider(color: palette.borderSubtle, height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Expected Drawer Cash:',
                                style: TextStyle(
                                    color: palette.neonGreen,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)),
                            Text(currencyFmt.format(expectedCash),
                                style: TextStyle(
                                    color: palette.neonGreen,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: countController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: 'Actual Counted Drawer Cash *',
                      labelStyle: TextStyle(color: palette.neonLime),
                      prefixText: '₱ ',
                      prefixStyle: TextStyle(
                          color: palette.neonLime,
                          fontWeight: FontWeight.bold),
                      filled: true,
                      fillColor: palette.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: palette.borderSubtle),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            BorderSide(color: palette.neonGreen, width: 1.5),
                      ),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 10),
                  if (countController.text.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: difference == 0
                            ? palette.neonGreen.withValues(alpha: 0.1)
                            : difference > 0
                                ? Colors.blue.withValues(alpha: 0.1)
                                : palette.errorRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        difference == 0
                            ? 'Drawer is perfectly balanced!'
                            : difference > 0
                                ? 'Cash Overage: +${currencyFmt.format(difference)}'
                                : 'Cash Shortage: ${currencyFmt.format(difference)}',
                        style: TextStyle(
                          color: difference == 0
                              ? palette.neonGreen
                              : difference > 0
                                  ? Colors.lightBlueAccent
                                  : palette.errorRed,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
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
                onPressed: () {
                  Navigator.of(dialogCtx).pop();
                  AppSnackBar.success(context,
                      'Shift ended and drawer closed. Report archived.');
                },
                child: const Text('Close Drawer & Archive',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _printShiftSummary() {
    if (_shiftTransactions.isEmpty) {
      AppSnackBar.info(context, 'No transactions in this shift to print.');
      return;
    }
    // Launch preview via the first or aggregate transaction
    showDialog<void>(
      context: context,
      builder: (ctx) => ThermalReceiptModal(
        transaction: _shiftTransactions.first,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final session = _selectedSession;

    final activeTxs = _shiftTransactions.where((t) => !t.isVoided).toList();
    final voidedTxs = _shiftTransactions.where((t) => t.isVoided).toList();

    // Sales by tender
    final cashSales = activeTxs
        .where((t) => t.paymentMethod.toLowerCase() == 'cash')
        .fold<double>(0.0, (s, t) => s + t.totalAmount);
    final cashCount = activeTxs
        .where((t) => t.paymentMethod.toLowerCase() == 'cash')
        .length;

    final gcashSales = activeTxs
        .where((t) =>
            t.paymentMethod.toLowerCase() == 'gcash' ||
            t.paymentMethod.toLowerCase() == 'e-wallet')
        .fold<double>(0.0, (s, t) => s + t.totalAmount);
    final gcashCount = activeTxs
        .where((t) =>
            t.paymentMethod.toLowerCase() == 'gcash' ||
            t.paymentMethod.toLowerCase() == 'e-wallet')
        .length;

    final cardSales = activeTxs
        .where((t) => t.paymentMethod.toLowerCase() == 'card')
        .fold<double>(0.0, (s, t) => s + t.totalAmount);
    final cardCount = activeTxs
        .where((t) => t.paymentMethod.toLowerCase() == 'card')
        .length;

    final grossTendered = cashSales + gcashSales + cardSales;
    final totalTransactionsCount = activeTxs.length;

    // BIR Tax Summary
    final vatableSales =
        activeTxs.fold<double>(0.0, (s, t) => s + t.vatableSales);
    final vatAmount = activeTxs.fold<double>(0.0, (s, t) => s + t.vatAmount);
    final vatExemptSales =
        activeTxs.fold<double>(0.0, (s, t) => s + t.vatExemptSales);
    final discountTotal =
        activeTxs.fold<double>(0.0, (s, t) => s + t.discountAmount);
    final voidAmount =
        voidedTxs.fold<double>(0.0, (s, t) => s + t.totalAmount);

    final openingFloat = session?.openingFloat ?? 1000.00;
    final expectedCash = openingFloat + cashSales;

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
                  Icon(Icons.assessment_rounded,
                      size: 14, color: palette.neonGreen),
                  const SizedBox(width: 6),
                  Text(
                    'REPORTS',
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
                'Shift & Drawer Reports (Z-Reading)',
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
          // Shift Selector
          if (_sessions.isNotEmpty)
            DropdownButtonHideUnderline(
              child: DropdownButton<CashierDutySessionModel>(
                value: session,
                dropdownColor: palette.surfaceElevated,
                items: _sessions.map((s) {
                  return DropdownMenuItem(
                    value: s,
                    child: Text(
                      s.isOnDuty
                          ? 'Active Shift (On Duty)'
                          : 'Shift on ${DateFormat('MM/dd hh:mm a').format(s.startedAt)}',
                      style: TextStyle(
                        color: s.isOnDuty
                            ? palette.neonGreen
                            : palette.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (s) {
                  if (s != null) _onSessionSelected(s);
                },
              ),
            ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.print_rounded, color: palette.neonGreen),
            tooltip: 'Print Z-Reading to Thermal Printer',
            onPressed: _printShiftSummary,
          ),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: palette.textSecondary),
            tooltip: 'Reload Shift Data',
            onPressed: () => _loadShiftData(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: palette.neonGreen),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Active Shift Status Banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: palette.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: session?.isOnDuty == true
                            ? palette.neonGreen.withValues(alpha: 0.3)
                            : palette.borderSubtle,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: session?.isOnDuty == true
                                ? palette.neonGreen.withValues(alpha: 0.15)
                                : palette.surface,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.badge_rounded,
                            color: session?.isOnDuty == true
                                ? palette.neonGreen
                                : palette.textSecondary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Cashier Session: ${session?.cashierId ?? "Terminal 1"}',
                                    style: TextStyle(
                                      color: palette.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: session?.isOnDuty == true
                                          ? palette.neonGreen
                                              .withValues(alpha: 0.15)
                                          : Colors.grey.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: session?.isOnDuty == true
                                            ? palette.neonGreen
                                            : Colors.grey,
                                      ),
                                    ),
                                    child: Text(
                                      session?.isOnDuty == true
                                          ? 'ON DUTY'
                                          : 'CLOSED',
                                      style: TextStyle(
                                        color: session?.isOnDuty == true
                                            ? palette.neonGreen
                                            : Colors.grey,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Started: ${session != null ? dateTimeFmt.format(session.startedAt) : "N/A"} • Shift Duration: ${session != null ? "${session.sessionDuration.inHours}h ${session.sessionDuration.inMinutes % 60}m" : ""}',
                                style: TextStyle(
                                  color: palette.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (session?.isOnDuty == true)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  palette.errorRed.withValues(alpha: 0.15),
                              foregroundColor: palette.errorRed,
                              side: BorderSide(
                                  color: palette.errorRed.withValues(alpha: 0.4)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                            ),
                            icon: const Icon(Icons.lock_clock_rounded, size: 16),
                            label: const Text('End Shift & Reconcile',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: _showCloseDrawerDialog,
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 2-Column Responsive Layout: Cash Drawer Tender & BIR Tax Audit
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 750;
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Column: Drawer Reconciliation & Tender Breakdown
                          Expanded(
                            flex: isWide ? 6 : 1,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: palette.surface,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: palette.borderSubtle),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.account_balance_wallet_rounded,
                                          color: palette.neonGreen, size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        'CASH DRAWER & TENDER BREAKDOWN',
                                        style: TextStyle(
                                          color: palette.textPrimary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Divider(
                                      color: palette.borderSubtle, height: 20),
                                  _buildLineItem(
                                    palette: palette,
                                    label: 'Beginning Drawer Cash (Float)',
                                    value: currencyFmt.format(openingFloat),
                                  ),
                                  _buildLineItem(
                                    palette: palette,
                                    label: 'Cash Tendered ($cashCount orders)',
                                    value: currencyFmt.format(cashSales),
                                    isAccent: true,
                                  ),
                                  Container(
                                    margin:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: palette.surfaceElevated,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: palette.neonGreen
                                              .withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'EXPECTED DRAWER CASH',
                                          style: TextStyle(
                                            color: palette.neonGreen,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          currencyFmt.format(expectedCash),
                                          style: TextStyle(
                                            color: palette.neonGreen,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  _buildLineItem(
                                    palette: palette,
                                    label: 'GCash / Maya / QR Ph ($gcashCount orders)',
                                    value: currencyFmt.format(gcashSales),
                                  ),
                                  _buildLineItem(
                                    palette: palette,
                                    label: 'Credit / Debit Card ($cardCount orders)',
                                    value: currencyFmt.format(cardSales),
                                  ),
                                  Divider(
                                      color: palette.borderSubtle, height: 16),
                                  _buildLineItem(
                                    palette: palette,
                                    label: 'TOTAL GROSS TENDERED',
                                    value: currencyFmt.format(grossTendered),
                                    isBold: true,
                                  ),
                                  _buildLineItem(
                                    palette: palette,
                                    label: 'Completed Transactions Count',
                                    value: '$totalTransactionsCount',
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(width: 16),

                          // Right Column: Statutory BIR Tax Breakdown & Void Audit
                          Expanded(
                            flex: isWide ? 6 : 1,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: palette.surface,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: palette.borderSubtle),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.receipt_long_rounded,
                                          color: palette.neonLime, size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        'BIR STATUTORY TAX & VOID AUDIT',
                                        style: TextStyle(
                                          color: palette.textPrimary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Divider(
                                      color: palette.borderSubtle, height: 20),
                                  _buildLineItem(
                                    palette: palette,
                                    label: 'VATable Sales (Net of 12% VAT)',
                                    value: currencyFmt.format(vatableSales),
                                  ),
                                  _buildLineItem(
                                    palette: palette,
                                    label: 'VAT Amount (12%)',
                                    value: currencyFmt.format(vatAmount),
                                  ),
                                  _buildLineItem(
                                    palette: palette,
                                    label: 'VAT-Exempt Sales (Senior/PWD)',
                                    value: currencyFmt.format(vatExemptSales),
                                  ),
                                  _buildLineItem(
                                    palette: palette,
                                    label: 'Discounts Total (20% Statutory)',
                                    value:
                                        '-${currencyFmt.format(discountTotal)}',
                                    isMuted: discountTotal <= 0,
                                  ),
                                  Divider(
                                      color: palette.borderSubtle, height: 16),
                                  _buildLineItem(
                                    palette: palette,
                                    label: 'NET PAYABLE / SALES COLLECTED',
                                    value: currencyFmt.format(grossTendered),
                                    isBold: true,
                                  ),
                                  Divider(
                                      color: palette.borderSubtle, height: 20),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Icon(Icons.cancel_outlined,
                                                size: 15,
                                                color: palette.errorRed),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                'Voided Transactions Audit',
                                                style: TextStyle(
                                                  color: palette.textSecondary,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${voidedTxs.length} voids (${currencyFmt.format(voidAmount)})',
                                        style: TextStyle(
                                          color: voidedTxs.isNotEmpty
                                              ? palette.errorRed
                                              : palette.textMuted,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildLineItem({
    required AppPalette palette,
    required String label,
    required String value,
    bool isBold = false,
    bool isAccent = false,
    bool isMuted = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isMuted ? palette.textMuted : palette.textSecondary,
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isAccent
                  ? palette.neonGreen
                  : isBold
                      ? palette.textPrimary
                      : isMuted
                          ? palette.textMuted
                          : palette.textPrimary,
              fontSize: isBold ? 13 : 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
