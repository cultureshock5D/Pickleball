import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../models/pos_transaction_model.dart';
import '../../../services/pos_service.dart';
import 'supervisor_pin_modal.dart';
import 'thermal_receipt_modal.dart';

class RecentInvoicesDrawer extends StatefulWidget {
  final String currentCashierId;
  final VoidCallback? onTransactionVoided;

  const RecentInvoicesDrawer({
    super.key,
    required this.currentCashierId,
    this.onTransactionVoided,
  });

  @override
  State<RecentInvoicesDrawer> createState() => _RecentInvoicesDrawerState();
}

class _RecentInvoicesDrawerState extends State<RecentInvoicesDrawer> {
  final _posService = PosService.instance;
  List<PosTransactionModel> _transactions = [];
  bool _isLoading = true;
  String _filter = 'all'; // 'all', 'completed', 'voided'
  String _sortBy = 'time_added'; // 'time_added', 'invoice_no', 'recently_voided', 'amount'
  bool _isAscending = false;
  String _searchQuery = '';

  StreamSubscription<void>? _realtimeSub;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
    _posService.initRealtimeSubscription();
    _realtimeSub = _posService.onPosUpdates.listen((_) {
      if (mounted) {
        _loadTransactions();
      }
    });
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    super.dispose();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    try {
      final list = await _posService.fetchRecentTransactions();
      if (mounted) {
        setState(() {
          _transactions = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<PosTransactionModel> get _filteredTransactions {
    final list = _transactions.where((tx) {
      if (_filter == 'completed' && !tx.isCompleted) return false;
      if (_filter == 'voided' && !tx.isVoided) return false;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesInvoice = tx.invoiceNumber.toLowerCase().contains(q);
        final matchesCustomer =
            tx.customerName != null && tx.customerName!.toLowerCase().contains(q);
        if (!matchesInvoice && !matchesCustomer) return false;
      }
      return true;
    }).toList();

    list.sort((a, b) {
      int cmp;
      switch (_sortBy) {
        case 'invoice_no':
          cmp = a.invoiceNumber.compareTo(b.invoiceNumber);
          break;
        case 'recently_voided':
          // Prioritize voided transactions
          if (a.isVoided && !b.isVoided) {
            return _isAscending ? 1 : -1;
          }
          if (!a.isVoided && b.isVoided) {
            return _isAscending ? -1 : 1;
          }
          final aTime = a.voidedAt ?? a.createdAt;
          final bTime = b.voidedAt ?? b.createdAt;
          cmp = aTime.compareTo(bTime);
          break;
        case 'amount':
          cmp = a.totalAmount.compareTo(b.totalAmount);
          break;
        case 'time_added':
        default:
          cmp = a.createdAt.compareTo(b.createdAt);
          break;
      }
      return _isAscending ? cmp : -cmp;
    });

    return list;
  }

  Future<void> _handleVoidTransaction(PosTransactionModel tx) async {
    final pinResult = await SupervisorPinModal.show(
      context,
      title: 'Authorize Invoice Void',
      subtitle: 'Invoice: ${tx.invoiceNumber}\nSupervisor PIN is required to reverse sale & restore stock',
      requireReason: true,
    );

    if (pinResult == null || !pinResult.authorized) return;

    final reason = pinResult.voidReason ?? 'Supervisor Void Authorization';

    // Optimistically reflect voided status immediately in the UI
    final txIndex = _transactions.indexWhere((t) => t.id == tx.id);
    if (txIndex != -1) {
      setState(() {
        _transactions[txIndex] = tx.copyWith(
          status: 'voided',
          voidReason: reason,
          voidedAt: DateTime.now(),
          voidedBy: widget.currentCashierId,
        );
      });
    }

    final success = await _posService.voidTransaction(
      transactionId: tx.id,
      voidReason: reason,
      voidedBy: widget.currentCashierId,
    );

    if (!mounted) return;

    if (success) {
      AppSnackBar.success(context, 'Transaction ${tx.invoiceNumber} has been voided. Stock restored.');
      widget.onTransactionVoided?.call();
      _loadTransactions();
    } else {
      AppSnackBar.error(context, 'Failed to void transaction. Please try again.');
      _loadTransactions();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    return Drawer(
      backgroundColor: colors.card,
      width: 460,
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.accentColor.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.history,
                            color: AppTheme.accentColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Recent Invoices & Void Audit',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.close, color: colors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Search Bar & Filter Chips
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    style: GoogleFonts.inter(fontSize: 13, color: colors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search by Invoice No. or Customer...',
                      hintStyle: GoogleFonts.inter(fontSize: 13, color: colors.textSecondary),
                      prefixIcon: Icon(Icons.search, size: 18, color: colors.textSecondary),
                      filled: true,
                      fillColor: colors.surface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: colors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: colors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.accentColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('All', 'all', colors),
                        const SizedBox(width: 8),
                        _buildFilterChip('Completed', 'completed', colors),
                        const SizedBox(width: 8),
                        _buildFilterChip('Voided', 'voided', colors),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 18),
                          color: colors.textSecondary,
                          tooltip: 'Refresh Invoices',
                          onPressed: _loadTransactions,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Sort Options & Asc/Desc Toggle Bar
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Text(
                          'SORT:',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildSortChip('Time Added', 'time_added', colors),
                        const SizedBox(width: 6),
                        _buildSortChip('Invoice #', 'invoice_no', colors),
                        const SizedBox(width: 6),
                        _buildSortChip('Recently Voided', 'recently_voided', colors),
                        const SizedBox(width: 6),
                        _buildSortChip('Amount', 'amount', colors),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => setState(() => _isAscending = !_isAscending),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: colors.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                  size: 13,
                                  color: AppTheme.accentColor,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  _isAscending ? 'ASC' : 'DESC',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.accentColor,
                                  ),
                                ),
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
            const Divider(height: 1),

            // Transactions List
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppTheme.accentColor),
                    )
                  : _filteredTransactions.isEmpty
                      ? Center(
                          child: Text(
                            'No transactions found.',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: colors.textSecondary,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredTransactions.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final tx = _filteredTransactions[index];
                            return _buildTransactionCard(tx, dateFormat, colors);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, dynamic colors) {
    final isSelected = _filter == value;
    return InkWell(
      onTap: () => setState(() => _filter = value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accentColor.withValues(alpha: 0.15)
              : colors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.accentColor : colors.border,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppTheme.accentColor : colors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildSortChip(String label, String value, dynamic colors) {
    final isSelected = _sortBy == value;
    return InkWell(
      onTap: () {
        setState(() {
          if (_sortBy == value) {
            _isAscending = !_isAscending;
          } else {
            _sortBy = value;
          }
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accentColor.withValues(alpha: 0.15)
              : colors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AppTheme.accentColor : colors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppTheme.accentColor : colors.textPrimary,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 4),
              Icon(
                _isAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                size: 12,
                color: AppTheme.accentColor,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard(
    PosTransactionModel tx,
    DateFormat dateFormat,
    dynamic colors,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: tx.isVoided
              ? Colors.redAccent.withValues(alpha: 0.4)
              : colors.border.withOpacity(0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  tx.invoiceNumber,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: tx.isVoided
                        ? Colors.redAccent.withValues(alpha: 0.15)
                        : AppTheme.accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    tx.status.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: tx.isVoided ? Colors.redAccent : AppTheme.accentColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  dateFormat.format(tx.createdAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 11, color: colors.textSecondary),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '₱${tx.totalAmount.toStringAsFixed(2)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: tx.isVoided ? colors.textSecondary : AppTheme.accentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Payment: ${tx.paymentMethod}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 11, color: colors.textSecondary),
                ),
              ),
              if (tx.hasDiscount) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    tx.discountType == 'senior_citizen'
                        ? 'Senior (20%)'
                        : tx.discountType == 'pwd'
                            ? 'PWD (20%)'
                            : 'Discounted',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.amberAccent,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (tx.isVoided && tx.voidReason != null) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade900.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Void Reason: ${tx.voidReason}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.redAccent,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.receipt_outlined, size: 16),
                label: const Text('View Receipt'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.accentColor,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                onPressed: () => ThermalReceiptModal.show(context, transaction: tx, autoPrint: false),
              ),
              if (!tx.isVoided)
                TextButton.icon(
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: const Text('Void Sale'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  onPressed: () => _handleVoidTransaction(tx),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
