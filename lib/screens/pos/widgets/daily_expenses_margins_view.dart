import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../models/daily_expense_model.dart';
import '../../../services/pos_service.dart';

class DailyExpensesMarginsView extends StatefulWidget {
  final VoidCallback onBackToRegister;
  final VoidCallback? onToggleMenu;

  const DailyExpensesMarginsView({
    super.key,
    required this.onBackToRegister,
    this.onToggleMenu,
  });

  @override
  State<DailyExpensesMarginsView> createState() =>
      _DailyExpensesMarginsViewState();
}

class _DailyExpensesMarginsViewState extends State<DailyExpensesMarginsView> {
  final PosService _posService = PosService.instance;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  StreamSubscription<void>? _updatesSub;

  Map<String, dynamic> _margins = {};
  List<DailyExpenseModel> _expenses = [];

  final currencyFmt = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
  final dateFmt = DateFormat('MMM dd, yyyy');

  @override
  void initState() {
    super.initState();
    _loadData();
    _updatesSub = _posService.onPosUpdates.listen((_) {
      if (mounted) _loadData(isSilent: true);
    });
  }

  @override
  void dispose() {
    _updatesSub?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool isSilent = false}) async {
    if (!isSilent) {
      setState(() => _isLoading = true);
    }
    try {
      final margins =
          await _posService.computeDailyMargins(date: _selectedDate);
      final expenses =
          await _posService.fetchDailyExpenses(date: _selectedDate);

      if (mounted) {
        setState(() {
          _margins = margins;
          _expenses = expenses;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppSnackBar.error(context, 'Failed to load expenses & margins: $e');
      }
    }
  }

  void _showAddExpenseDialog() {
    final palette = context.colors;
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final receiptController = TextEditingController();
    final notesController = TextEditingController();

    String selectedCategory = 'supplies';
    String selectedPaymentMethod = 'cash';

    final categories = [
      {'id': 'supplies', 'name': 'Consumables & Supplies'},
      {'id': 'maintenance', 'name': 'Court & Machine Maintenance'},
      {'id': 'utilities', 'name': 'Utilities & Emergency Water/Ice'},
      {'id': 'packaging', 'name': 'Takeout Packaging & Bags'},
      {'id': 'inventory_delivery', 'name': 'Inventory Freight & Delivery'},
      {'id': 'general', 'name': 'General & Store Supplies'},
    ];

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: palette.surfaceElevated,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: palette.errorRed.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.receipt_long_rounded,
                      color: palette.errorRed, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Record Daily Expense',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: titleController,
                      style: TextStyle(color: palette.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Expense Description *',
                        labelStyle: TextStyle(color: palette.textSecondary),
                        hintText: 'e.g. Espresso machine filters, Ice bags',
                        hintStyle:
                            TextStyle(color: palette.textMuted, fontSize: 12),
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
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: amountController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Amount (PHP) *',
                              prefixText: '₱ ',
                              prefixStyle: TextStyle(
                                  color: palette.neonGreen,
                                  fontWeight: FontWeight.bold),
                              filled: true,
                              fillColor: palette.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    BorderSide(color: palette.borderSubtle),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                    color: palette.neonGreen, width: 1.5),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedPaymentMethod,
                            dropdownColor: palette.surfaceElevated,
                            style: TextStyle(
                                color: palette.textPrimary, fontSize: 13),
                            decoration: InputDecoration(
                              labelText: 'Paid via',
                              filled: true,
                              fillColor: palette.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    BorderSide(color: palette.borderSubtle),
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(
                                  value: 'cash', child: Text('Cash Drawer')),
                              DropdownMenuItem(
                                  value: 'gcash', child: Text('GCash')),
                              DropdownMenuItem(
                                  value: 'bank_transfer',
                                  child: Text('Bank Transfer')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() => selectedPaymentMethod = val);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategory,
                      dropdownColor: palette.surfaceElevated,
                      style:
                          TextStyle(color: palette.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Expense Category *',
                        filled: true,
                        fillColor: palette.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: palette.borderSubtle),
                        ),
                      ),
                      items: categories
                          .map((c) => DropdownMenuItem(
                                value: c['id'],
                                child: Text(c['name']!),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedCategory = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: receiptController,
                      style: TextStyle(color: palette.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Receipt / Voucher / OR Number',
                        hintText: 'e.g. OR-99214, VCH-102',
                        hintStyle:
                            TextStyle(color: palette.textMuted, fontSize: 12),
                        filled: true,
                        fillColor: palette.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: palette.borderSubtle),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      maxLines: 2,
                      style: TextStyle(color: palette.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Notes / Justification (Optional)',
                        filled: true,
                        fillColor: palette.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: palette.borderSubtle),
                        ),
                      ),
                    ),
                  ],
                ),
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
                  final title = titleController.text.trim();
                  final amount = double.tryParse(amountController.text) ?? 0.0;
                  if (title.isEmpty) {
                    AppSnackBar.warning(context, 'Please enter a description');
                    return;
                  }
                  if (amount <= 0) {
                    AppSnackBar.warning(
                        context, 'Please enter a valid expense amount');
                    return;
                  }

                  Navigator.of(dialogCtx).pop();

                  final newExpense = DailyExpenseModel(
                    id: '',
                    expenseDate: _selectedDate,
                    category: selectedCategory,
                    title: title,
                    amount: amount,
                    paymentMethod: selectedPaymentMethod,
                    receiptReference: receiptController.text.trim().isNotEmpty
                        ? receiptController.text.trim()
                        : null,
                    notes: notesController.text.trim().isNotEmpty
                        ? notesController.text.trim()
                        : null,
                    recordedBy: 'Cashier On-Duty',
                    createdAt: DateTime.now(),
                  );

                  final created =
                      await _posService.createDailyExpense(newExpense);
                  if (mounted) {
                    if (created != null) {
                      AppSnackBar.success(context,
                          'Expense of ${currencyFmt.format(amount)} recorded');
                    }
                    _loadData(isSilent: true);
                  }
                },
                child: const Text('Record Expense',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;

    final grossRev = (_margins['grossRevenue'] as num?)?.toDouble() ?? 0.0;
    final cogs = (_margins['cogs'] as num?)?.toDouble() ?? 0.0;
    final grossProfit =
        (_margins['grossProfit'] as num?)?.toDouble() ?? 0.0;
    final grossMarginPct =
        (_margins['grossMarginPercent'] as num?)?.toDouble() ?? 0.0;
    final totalExpenses =
        (_margins['totalOperatingExpenses'] as num?)?.toDouble() ?? 0.0;
    final netProfit = (_margins['netProfit'] as num?)?.toDouble() ?? 0.0;
    final netMarginPct =
        (_margins['netMarginPercent'] as num?)?.toDouble() ?? 0.0;
    final txCount = (_margins['transactionCount'] as int?) ?? 0;
    final itemsSold = (_margins['itemsSold'] as int?) ?? 0;

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
                  Icon(Icons.query_stats_rounded,
                      size: 14, color: palette.neonGreen),
                  const SizedBox(width: 6),
                  Text(
                    'FINANCIALS',
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
                'Daily Expenses & Margins',
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
          // Date Selector Button
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: palette.textPrimary,
              side: BorderSide(color: palette.borderSubtle),
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            icon: Icon(Icons.calendar_today_rounded,
                size: 14, color: palette.neonGreen),
            label: Text(
              dateFmt.format(_selectedDate),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2024),
                lastDate: DateTime(2030),
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
                _loadData();
              }
            },
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: palette.textSecondary),
            tooltip: 'Reload Financials',
            onPressed: () => _loadData(),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // KPI Stat Grid: Revenue, COGS, Gross Profit, Expenses, Net Profit
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 800;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _buildFinancialKpi(
                            palette: palette,
                            title: 'GROSS SALES',
                            amount: currencyFmt.format(grossRev),
                            subtitle: '$txCount orders ($itemsSold units sold)',
                            accentColor: palette.neonGreen,
                            icon: Icons.point_of_sale_rounded,
                            width: isWide
                                ? (constraints.maxWidth - 48) / 5
                                : (constraints.maxWidth - 12) / 2,
                          ),
                          _buildFinancialKpi(
                            palette: palette,
                            title: 'COST OF GOODS (COGS)',
                            amount: currencyFmt.format(cogs),
                            subtitle: 'Unit ingredient & catalog cost',
                            accentColor: Colors.orange,
                            icon: Icons.inventory_outlined,
                            width: isWide
                                ? (constraints.maxWidth - 48) / 5
                                : (constraints.maxWidth - 12) / 2,
                          ),
                          _buildFinancialKpi(
                            palette: palette,
                            title: 'GROSS PROFIT',
                            amount: currencyFmt.format(grossProfit),
                            subtitle:
                                'Gross Margin: ${grossMarginPct.toStringAsFixed(1)}%',
                            accentColor: palette.neonLime,
                            icon: Icons.trending_up_rounded,
                            width: isWide
                                ? (constraints.maxWidth - 48) / 5
                                : (constraints.maxWidth - 12) / 2,
                          ),
                          _buildFinancialKpi(
                            palette: palette,
                            title: 'STORE EXPENSES',
                            amount: currencyFmt.format(totalExpenses),
                            subtitle: '${_expenses.length} logged expense items',
                            accentColor: palette.errorRed,
                            icon: Icons.outbox_rounded,
                            width: isWide
                                ? (constraints.maxWidth - 48) / 5
                                : (constraints.maxWidth - 12) / 2,
                          ),
                          _buildFinancialKpi(
                            palette: palette,
                            title: 'NET OPERATING PROFIT',
                            amount: currencyFmt.format(netProfit),
                            subtitle:
                                'Net Margin: ${netMarginPct.toStringAsFixed(1)}%',
                            accentColor: netProfit >= 0
                                ? palette.neonGreen
                                : palette.errorRed,
                            icon: Icons.account_balance_wallet_rounded,
                            width: isWide
                                ? (constraints.maxWidth - 48) / 5
                                : constraints.maxWidth,
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Section Header & Add Expense CTA
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Logged Daily Store Expenses',
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Track operating costs, supplies, maintenance, and petty cash disbursements',
                              style: TextStyle(
                                color: palette.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: palette.neonGreen,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Record Expense',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: _showAddExpenseDialog,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Expenses Table or Empty State
                  if (_expenses.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(36),
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: palette.borderSubtle),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.savings_outlined,
                              size: 44, color: palette.textMuted),
                          const SizedBox(height: 12),
                          Text(
                            'No expenses recorded for ${dateFmt.format(_selectedDate)}',
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap "+ Record Expense" to log supplies, maintenance, or petty cash outlays.',
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: palette.borderSubtle),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _expenses.length,
                        separatorBuilder: (_, __) =>
                            Divider(color: palette.borderSubtle, height: 1),
                        itemBuilder: (context, index) {
                          final expense = _expenses[index];
                          final timeStr =
                              DateFormat('hh:mm a').format(expense.createdAt);

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: palette.surfaceElevated,
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: palette.borderSubtle),
                              ),
                              child: Icon(Icons.receipt_rounded,
                                  color: palette.neonGreen, size: 20),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    expense.title,
                                    style: TextStyle(
                                      color: palette.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Text(
                                  currencyFmt.format(expense.amount),
                                  style: TextStyle(
                                    color: palette.errorRed,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: palette.surfaceElevated,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      expense.category.toUpperCase(),
                                      style: TextStyle(
                                        color: palette.textSecondary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Paid via ${expense.paymentMethod.toUpperCase()}',
                                    style: TextStyle(
                                      color: palette.textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                  if (expense.receiptReference != null) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      '• Ref: ${expense.receiptReference}',
                                      style: TextStyle(
                                        color: palette.textMuted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                  const Spacer(),
                                  Text(
                                    timeStr,
                                    style: TextStyle(
                                      color: palette.textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildFinancialKpi({
    required AppPalette palette,
    required String title,
    required String amount,
    required String subtitle,
    required Color accentColor,
    required IconData icon,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: palette.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(icon, color: accentColor, size: 16),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
