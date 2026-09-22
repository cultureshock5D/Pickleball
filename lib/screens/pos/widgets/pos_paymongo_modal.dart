import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/pos_transaction_model.dart';
import '../../../services/pos_service.dart';
import '../controllers/pos_cart_controller.dart';

class PosPayMongoModal extends StatefulWidget {
  final PosCartController cartController;
  final String cashierId;
  final String? cashierName;

  const PosPayMongoModal({
    super.key,
    required this.cartController,
    required this.cashierId,
    this.cashierName,
  });

  static Future<PosTransactionModel?> show(
    BuildContext context, {
    required PosCartController cartController,
    required String cashierId,
    String? cashierName,
  }) {
    return showDialog<PosTransactionModel?>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PosPayMongoModal(
        cartController: cartController,
        cashierId: cashierId,
        cashierName: cashierName,
      ),
    );
  }

  @override
  State<PosPayMongoModal> createState() => _PosPayMongoModalState();
}

class _PosPayMongoModalState extends State<PosPayMongoModal> {
  Timer? _pollTimer;
  bool _isCreatingSession = true;
  bool _isPaymentCompleted = false;
  String? _sessionId;
  String? _checkoutUrl;
  String? _errorMessage;
  bool _isMock = false;

  @override
  void initState() {
    super.initState();
    _initiatePayMongoCheckout();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _initiatePayMongoCheckout() async {
    setState(() {
      _isCreatingSession = true;
      _errorMessage = null;
    });

    try {
      final items = widget.cartController.items
          .map((i) => {
                'name': i.productName,
                'price': i.unitPrice,
                'quantity': i.quantity,
              })
          .toList();

      final res = await PosService.instance.createPayMongoCheckoutSession(
        totalAmount: widget.cartController.taxBreakdown.netPayable,
        items: items,
        customerName: widget.cartController.customerName,
      );

      final sessionId = res['sessionId'] as String;
      final checkoutUrl = res['checkoutUrl'] as String;
      final isMock = res['isMock'] == true;

      if (!mounted) return;

      setState(() {
        _isCreatingSession = false;
        _sessionId = sessionId;
        _checkoutUrl = checkoutUrl;
        _isMock = isMock;
      });

      // Automatically launch PayMongo checkout in browser/app
      await _launchCheckoutUrl(checkoutUrl);

      // Start status polling every 2.5 seconds
      _startStatusPolling(sessionId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCreatingSession = false;
        _errorMessage = 'Failed to create PayMongo checkout: $e';
      });
    }
  }

  Future<void> _launchCheckoutUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      debugPrint('Security warning: Rejected invalid or unsafe checkout URL: $url');
      return;
    }
    try {
      bool launched = await launchUrl(uri);
      if (!launched) {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      if (!launched) {
        await launchUrl(uri);
      }
    } catch (e) {
      debugPrint('Could not launch PayMongo URL: $e');
    }
  }

  void _startStatusPolling(String sessionId) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) async {
      if (_isPaymentCompleted || !mounted) return;

      final isPaid = await PosService.instance.checkPayMongoPaymentStatus(sessionId);
      if (isPaid && !_isPaymentCompleted) {
        _onPaymentConfirmed(sessionId);
      }
    });
  }

  Future<void> _onPaymentConfirmed(String sessionId) async {
    _pollTimer?.cancel();
    setState(() => _isPaymentCompleted = true);

    HapticFeedback.heavyImpact();

    // Persist completed transaction with PayMongo session reference
    final tx = await widget.cartController.checkout(
      cashierId: widget.cashierId,
      cashierName: widget.cashierName,
    );

    if (mounted) {
      Navigator.of(context).pop(tx);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final netPayable = widget.cartController.taxBreakdown.netPayable;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Center(
        child: Container(
          width: 440,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Badge & Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.qr_code_2_rounded,
                      size: 24,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GCash / QR Ph Checkout',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          'Powered by PayMongo Gateway',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Net Payable Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'TOTAL PAYABLE',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₱${netPayable.toStringAsFixed(2)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0284C7),
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      '${widget.cartController.itemCount} item(s) in active order',
                      style: GoogleFonts.inter(fontSize: 11, color: colors.textSecondary),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Status Content
              if (_isCreatingSession)
                Column(
                  children: [
                    const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Redirecting to PayMongo...',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                )
              else if (_errorMessage != null)
                Column(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 36, color: Colors.redAccent),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.redAccent),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _initiatePayMongoCheckout,
                      child: const Text('Retry PayMongo Checkout'),
                    ),
                  ],
                )
              else if (_isPaymentCompleted)
                Column(
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 44, color: Color(0xFF10B981)),
                    const SizedBox(height: 8),
                    Text(
                      'Payment Successfully Verified!',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Generating 80mm sales invoice receipt...',
                      style: GoogleFonts.inter(fontSize: 12, color: colors.textSecondary),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            'Waiting for customer payment on PayMongo...',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Receipt will only be issued once payment successfully reflects.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_checkoutUrl != null)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.open_in_new, size: 14),
                        label: const Text('Re-open PayMongo Checkout'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(200, 38),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        onPressed: () => _launchCheckoutUrl(_checkoutUrl!),
                      ),
                    if (_isMock || !_sessionId!.startsWith('cs_live')) ...[
                      const SizedBox(height: 10),
                      TextButton.icon(
                        icon: const Icon(Icons.flash_on_rounded, size: 15, color: Color(0xFFEAB308)),
                        label: Text(
                          'Simulate Payment Received (Dev/Test)',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFEAB308),
                          ),
                        ),
                        onPressed: () => _onPaymentConfirmed(_sessionId ?? 'sim_session'),
                      ),
                    ],
                  ],
                ),

              const SizedBox(height: 20),

              // Cancel button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _isPaymentCompleted
                      ? null
                      : () {
                          _pollTimer?.cancel();
                          Navigator.of(context).pop();
                        },
                  style: TextButton.styleFrom(
                    foregroundColor: colors.textSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'Cancel Payment',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
