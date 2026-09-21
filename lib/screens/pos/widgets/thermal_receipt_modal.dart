import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../models/pos_transaction_model.dart';
import '../../../services/thermal_printer_service.dart';
import '../../../widgets/neon_button.dart';

class ThermalReceiptModal extends StatefulWidget {
  final PosTransactionModel transaction;

  final bool autoPrint;

  const ThermalReceiptModal({
    super.key,
    required this.transaction,
    this.autoPrint = true,
  });

  static Future<void> show(
    BuildContext context, {
    required PosTransactionModel transaction,
    bool autoPrint = true,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => ThermalReceiptModal(
        transaction: transaction,
        autoPrint: autoPrint,
      ),
    );
  }

  /// Formats currency with Philippine Peso sign
  static String formatCurrency(double amount) {
    return '₱${amount.toStringAsFixed(2)}';
  }

  /// Formats currency with ASCII P for thermal printer
  static String formatEscPosCurrency(double amount) {
    return 'P${amount.toStringAsFixed(2)}';
  }

  /// Converts text to 7-bit ASCII byte list safe for thermal printers
  static List<int> asciiBytes(String text) {
    final sanitized = text
        .replaceAll('₱', 'P')
        .replaceAll('’', "'")
        .replaceAll('‘', "'")
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('•', '-')
        .replaceAll('—', '-')
        .replaceAll('–', '-');
    return sanitized.codeUnits.map((c) => (c < 0 || c > 127) ? 63 : c).toList();
  }

  /// Generates 80mm plain text receipt
  static String generatePlainTextReceipt(PosTransactionModel transaction) {
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final sb = StringBuffer();
    sb.writeln('      C&J\'S EVENTS PLACE & SPORTS ARENA');
    sb.writeln('    25 Bologna Muzon, Taytay, Rizal, 1920');
    sb.writeln('   VAT Reg. TIN: 000-123-456-00000 • EOPT');
    sb.writeln('------------------------------------------');
    sb.writeln('Invoice No: ${transaction.invoiceNumber}');
    sb.writeln('Date/Time:  ${dateFormat.format(transaction.createdAt)}');
    sb.writeln('Cashier:    ${transaction.cashierName ?? 'Cashier Staff'}');
    if (transaction.customerName != null && transaction.customerName!.isNotEmpty) {
      sb.writeln('------------------------------------------');
      sb.writeln('Customer:   ${transaction.customerName}');
      final priv = transaction.discountType == 'senior_citizen'
          ? 'SENIOR CITIZEN (RA 9994)'
          : transaction.discountType == 'pwd'
              ? 'PERSON WITH DISABILITY (RA 10754)'
              : 'REGULAR';
      sb.writeln('Privilege:  $priv');
      if (transaction.discountIdNumber != null) {
        sb.writeln('ID No:      ${transaction.discountIdNumber}');
      }
    }
    sb.writeln('------------------------------------------');
    sb.writeln('ITEM                     QTY         TOTAL');
    for (final item in transaction.items) {
      final rawName = item.productName.trim();
      final displayName = rawName.isEmpty ? 'Item' : rawName;
      final qty = item.quantity.toString().padLeft(4);
      final total = formatCurrency(item.subtotal).padLeft(14);
      if (displayName.length <= 22) {
        final name = displayName.padRight(22);
        sb.writeln('$name$qty$total');
      } else {
        sb.writeln(displayName);
        final indent = ''.padRight(22);
        sb.writeln('$indent$qty$total');
      }
    }
    sb.writeln('------------------------------------------');
    sb.writeln('Gross Sales:                       ${formatCurrency(transaction.grossAmount).padLeft(12)}');
    if (transaction.discountAmount > 0) {
      sb.writeln('Statutory 20% Discount:            -${formatCurrency(transaction.discountAmount).padLeft(11)}');
    }
    sb.writeln('Vatable Sales:                     ${formatCurrency(transaction.vatableSales).padLeft(12)}');
    sb.writeln('12% VAT:                           ${formatCurrency(transaction.vatAmount).padLeft(12)}');
    sb.writeln('VAT-Exempt Sales:                  ${formatCurrency(transaction.vatExemptSales).padLeft(12)}');
    sb.writeln('------------------------------------------');
    sb.writeln('TOTAL DUE:                         ${formatCurrency(transaction.totalAmount).padLeft(12)}');
    sb.writeln('Payment Mode:              ${transaction.paymentMethod.toUpperCase()}');
    sb.writeln('------------------------------------------');
    sb.writeln('         *${transaction.invoiceNumber.replaceAll('-', '')}*');
    sb.writeln('     THANK YOU FOR PLAYING AT C&J!');
    sb.writeln('   Non-refundable after 24 hours');
    return sb.toString();
  }

  /// Generates 58mm ESC/POS bytes tailored for POS-58 / JP58H (32 characters per line)
  static List<int> generatePos58Bytes(PosTransactionModel transaction) {
    final bytes = <int>[];

    // INIT: \x1b\x40
    bytes.addAll([0x1B, 0x40]);

    // CENTER + BOLD_ON
    bytes.addAll([0x1B, 0x61, 0x01, 0x1B, 0x45, 0x01]);
    bytes.addAll(asciiBytes("C&J EVENTS & SPORTS ARENA\n"));
    // BOLD_OFF
    bytes.addAll([0x1B, 0x45, 0x00]);
    bytes.addAll(asciiBytes("Taytay, Rizal - EOPT\n"));
    bytes.addAll(asciiBytes("TIN: 000-123-456-00000\n"));
    bytes.addAll(asciiBytes("--------------------------------\n")); // 32 chars

    // LEFT ALIGN
    bytes.addAll([0x1B, 0x61, 0x00]);
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    bytes.addAll(asciiBytes('Inv: ${transaction.invoiceNumber}\n'));
    bytes.addAll(asciiBytes('Date: ${dateFormat.format(transaction.createdAt)}\n'));
    bytes.addAll(asciiBytes('Cashier: ${transaction.cashierName ?? 'Staff'}\n'));

    if (transaction.customerName != null && transaction.customerName!.isNotEmpty) {
      bytes.addAll(asciiBytes("--------------------------------\n"));
      bytes.addAll(asciiBytes('Cust: ${transaction.customerName}\n'));
      if (transaction.discountType != 'none') {
        final priv = transaction.discountType == 'senior_citizen' ? 'SENIOR (RA 9994)' : 'PWD (RA 10754)';
        bytes.addAll(asciiBytes('Disc: $priv\n'));
        if (transaction.discountIdNumber != null) {
          bytes.addAll(asciiBytes('ID: ${transaction.discountIdNumber}\n'));
        }
      }
    }

    bytes.addAll(asciiBytes("--------------------------------\n"));
    bytes.addAll(asciiBytes("ITEM              QTY     AMOUNT\n")); // 32 chars
    for (final item in transaction.items) {
      final rawName = item.productName.trim();
      final displayName = rawName.isEmpty ? 'Item' : rawName;
      final qty = item.quantity.toString().padLeft(3);
      final total = formatEscPosCurrency(item.subtotal).padLeft(11);
      if (displayName.length <= 16) {
        final name = displayName.padRight(16);
        bytes.addAll(asciiBytes('$name $qty $total\n'));
      } else {
        bytes.addAll(asciiBytes('$displayName\n'));
        final indent = ''.padRight(16);
        bytes.addAll(asciiBytes('$indent $qty $total\n'));
      }
    }
    bytes.addAll(asciiBytes("--------------------------------\n"));
    bytes.addAll(asciiBytes('Gross Sales:        ${formatEscPosCurrency(transaction.grossAmount).padLeft(12)}\n'));
    if (transaction.discountAmount > 0) {
      bytes.addAll(asciiBytes('20% Discount:      -${formatEscPosCurrency(transaction.discountAmount).padLeft(11)}\n'));
    }
    bytes.addAll(asciiBytes('Vatable Sales:      ${formatEscPosCurrency(transaction.vatableSales).padLeft(12)}\n'));
    bytes.addAll(asciiBytes('12% VAT:            ${formatEscPosCurrency(transaction.vatAmount).padLeft(12)}\n'));
    bytes.addAll(asciiBytes('VAT-Exempt:         ${formatEscPosCurrency(transaction.vatExemptSales).padLeft(12)}\n'));
    bytes.addAll(asciiBytes("--------------------------------\n"));

    // Total Due in BOLD
    bytes.addAll([0x1B, 0x45, 0x01]);
    bytes.addAll(asciiBytes('TOTAL DUE:          ${formatEscPosCurrency(transaction.totalAmount).padLeft(12)}\n'));
    bytes.addAll([0x1B, 0x45, 0x00]);
    bytes.addAll(asciiBytes('Payment:            ${transaction.paymentMethod.toUpperCase().padLeft(12)}\n'));
    bytes.addAll(asciiBytes("--------------------------------\n"));

    // CENTER + FEED past tear bar (\n\n\n\n)
    bytes.addAll([0x1B, 0x61, 0x01]);
    bytes.addAll(asciiBytes("THANK YOU FOR PLAYING!\n"));
    bytes.addAll(asciiBytes("Non-refundable after 24h\n\n\n\n"));

    return bytes;
  }

  @override
  State<ThermalReceiptModal> createState() => _ThermalReceiptModalState();
}

class _ThermalReceiptModalState extends State<ThermalReceiptModal> {
  bool _isPrinting = false;
  bool _hasPrinted = false;
  String? _lastPrintStatus;
  bool _lastPrintSuccess = false;

  PosTransactionModel get transaction => widget.transaction;

  @override
  void initState() {
    super.initState();
    if (widget.autoPrint) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _triggerThermalPrint();
        }
      });
    }
  }

  String _formatCurrency(double amount) => ThermalReceiptModal.formatCurrency(amount);

  String _generatePlainTextReceipt() => ThermalReceiptModal.generatePlainTextReceipt(transaction);

  void _copyReceipt(BuildContext context) {
    Clipboard.setData(ClipboardData(text: _generatePlainTextReceipt()));
    HapticFeedback.mediumImpact();
    AppSnackBar.success(context, 'Receipt copied to clipboard for 80mm thermal printer.');
  }

  List<int> _generatePos58Bytes() => ThermalReceiptModal.generatePos58Bytes(transaction);

  bool get _isMobileDevice =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _triggerThermalPrint() async {
    if (_isPrinting) return;

    setState(() => _isPrinting = true);
    HapticFeedback.heavyImpact();

    try {
      final escPosData = _generatePos58Bytes();

      // Copy exact 58mm ESC/POS stream text to clipboard as safety backup
      try {
        Clipboard.setData(ClipboardData(text: String.fromCharCodes(escPosData)));
      } catch (_) {}

      final result = await ThermalPrinterService.print58mmReceipt(escPosData)
          .timeout(
            const Duration(seconds: 8),
            onTimeout: () => const PrinterResult(
              success: false,
              message: 'Printing timed out after 8 seconds. Please check printer power and connection.',
            ),
          );

      if (!mounted) return;

      setState(() {
        _hasPrinted = true;
        _lastPrintSuccess = result.success;
        _lastPrintStatus = result.message;
      });

      if (result.success) {
        AppSnackBar.success(context, result.message);
      } else {
        AppSnackBar.error(
          context,
          '${result.message} (Payload copied to clipboard).',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lastPrintSuccess = false;
        _lastPrintStatus = 'Print error: $e';
      });
      AppSnackBar.error(context, 'Print error: $e');
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Center(
        child: Container(
          width: 440,
          constraints: const BoxConstraints(maxHeight: 740),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.border.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.receipt_long,
                            color: AppTheme.accentColor,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '80mm Thermal Receipt',
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
                    IconButton(
                      icon: Icon(Icons.close, color: colors.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Scrollable Thermal Paper Simulation
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Store Header
                        Text(
                          'C&J\'S EVENTS PLACE & SPORTS ARENA',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.robotoMono(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '25 Bologna Muzon, Taytay, Rizal, 1920\nVAT Reg. TIN: 000-123-456-00000 • EOPT',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.robotoMono(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildDashedLine(),
                        const SizedBox(height: 10),

                        // Transaction Metadata
                        _buildReceiptRow('Invoice No:', transaction.invoiceNumber),
                        _buildReceiptRow('Date/Time:', dateFormat.format(transaction.createdAt)),
                        _buildReceiptRow('Cashier:', transaction.cashierName ?? 'Cashier Staff'),

                        // Discount Customer Information
                        if (transaction.customerName != null &&
                            transaction.customerName!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _buildDashedLine(),
                          const SizedBox(height: 8),
                          _buildReceiptRow('Customer:', transaction.customerName!),
                          _buildReceiptRow(
                            'Privilege:',
                            transaction.discountType == 'senior_citizen'
                                ? 'SENIOR CITIZEN (RA 9994)'
                                : transaction.discountType == 'pwd'
                                    ? 'PWD (RA 10754)'
                                    : 'REGULAR',
                          ),
                          if (transaction.discountIdNumber != null)
                            _buildReceiptRow('ID No:', transaction.discountIdNumber!),
                        ],

                        const SizedBox(height: 10),
                        _buildDashedLine(),
                        const SizedBox(height: 8),

                        // Items Header
                        Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: Text(
                                'ITEM',
                                style: GoogleFonts.robotoMono(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'QTY',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.robotoMono(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                'TOTAL',
                                textAlign: TextAlign.right,
                                style: GoogleFonts.robotoMono(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Items List
                        ...transaction.items.map((item) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: Text(
                                    item.productName.trim().isEmpty ? 'Item' : item.productName,
                                    style: GoogleFonts.robotoMono(
                                      fontSize: 11,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '${item.quantity}',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.robotoMono(
                                      fontSize: 11,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    _formatCurrency(item.subtotal),
                                    textAlign: TextAlign.right,
                                    style: GoogleFonts.robotoMono(
                                      fontSize: 11,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),

                        const SizedBox(height: 10),
                        _buildDashedLine(),
                        const SizedBox(height: 8),

                        // Financial Summary & BIR EOPT Breakdown
                        _buildReceiptRow('Gross Sales:', _formatCurrency(transaction.grossAmount)),
                        if (transaction.discountAmount > 0)
                          _buildReceiptRow(
                            'Statutory 20% Discount:',
                            '-${_formatCurrency(transaction.discountAmount)}',
                            isBold: true,
                          ),
                        _buildReceiptRow('Vatable Sales (12%):', _formatCurrency(transaction.vatableSales)),
                        _buildReceiptRow('12% VAT:', _formatCurrency(transaction.vatAmount)),
                        _buildReceiptRow('VAT-Exempt Sales:', _formatCurrency(transaction.vatExemptSales)),
                        const SizedBox(height: 8),
                        _buildDashedLine(),
                        const SizedBox(height: 8),

                        // Total Due
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'TOTAL DUE:',
                              style: GoogleFonts.robotoMono(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                            Text(
                              _formatCurrency(transaction.totalAmount),
                              style: GoogleFonts.robotoMono(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        _buildReceiptRow('Payment Mode:', transaction.paymentMethod.toUpperCase()),

                        if (transaction.isVoided) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              border: Border.all(color: Colors.red.shade300),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '*** VOIDED TRANSACTION ***',
                                  style: GoogleFonts.robotoMono(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.red.shade900,
                                  ),
                                ),
                                if (transaction.voidReason != null)
                                  Text(
                                    'Reason: ${transaction.voidReason}',
                                    style: GoogleFonts.robotoMono(
                                      fontSize: 10,
                                      color: Colors.red.shade700,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 14),
                        _buildDashedLine(),
                        const SizedBox(height: 12),

                        // Barcode Simulation
                        Text(
                          '*${transaction.invoiceNumber.replaceAll('-', '')}*',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.libreBarcode39(
                            fontSize: 36,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'THANK YOU FOR PLAYING AT C&J!\nNon-refundable after 24 hours',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.robotoMono(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Action Buttons
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Driverless Status Hint
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E599).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF00E599).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF00E599)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _isMobileDevice
                                    ? 'Mobile/Tablet: 100% Driverless (Direct Bluetooth RFCOMM)'
                                    : 'Windows/Web: Direct Serial COM4 (Bypasses OS Driver)',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Realtime Status Banner if print was attempted
                    if (_lastPrintStatus != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: _lastPrintSuccess
                                ? const Color(0xFF00E599).withValues(alpha: 0.12)
                                : Colors.amber.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _lastPrintSuccess
                                  ? const Color(0xFF00E599).withValues(alpha: 0.35)
                                  : Colors.amber.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _lastPrintSuccess
                                    ? Icons.check_circle_outline
                                    : Icons.info_outline,
                                size: 16,
                                color: _lastPrintSuccess
                                    ? const Color(0xFF00E599)
                                    : Colors.amber,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _lastPrintStatus!,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _lastPrintSuccess
                                        ? const Color(0xFF00E599)
                                        : Colors.amber,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Primary Action Button: "Print Again" or "Print Receipt"
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: _isPrinting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF0A0F0D),
                                ),
                              )
                            : Icon(
                                _hasPrinted ? Icons.replay : Icons.print,
                                size: 20,
                              ),
                        label: Text(
                          _isPrinting
                              ? 'Printing Receipt...'
                              : _hasPrinted
                                  ? 'Print Again'
                                  : 'Print Receipt (JP58H 58mm)',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _hasPrinted
                              ? AppTheme.accentColor
                              : const Color(0xFF00E599),
                          foregroundColor: const Color(0xFF0A0F0D),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        onPressed: _isPrinting ? null : _triggerThermalPrint,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.copy, size: 16),
                            label: const Text('Copy ESC/POS'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: colors.textPrimary,
                              side: BorderSide(color: colors.border),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () => _copyReceipt(context),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.print_outlined, size: 16),
                            label: const Text('Print 80mm'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: colors.textPrimary,
                              side: BorderSide(color: colors.border),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () {
                              _copyReceipt(context);
                              AppSnackBar.success(context, 'Receipt copied for 80mm printer spooler.');
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: NeonButton(
                            text: 'Done',
                            icon: Icons.check,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.robotoMono(
              fontSize: 11,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
              color: Colors.black87,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.robotoMono(
              fontSize: 11,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashedLine() {
    return Row(
      children: List.generate(
        36,
        (index) => Expanded(
          child: Container(
            color: index % 2 == 0 ? Colors.black26 : Colors.transparent,
            height: 1,
          ),
        ),
      ),
    );
  }
}
