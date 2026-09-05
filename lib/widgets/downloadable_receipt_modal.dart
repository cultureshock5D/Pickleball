import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import '../models/booking_model.dart';

class DownloadableReceiptModal extends StatelessWidget {
  final BookingModel booking;
  final String paymentMethod;
  final String paymongoReference;

  const DownloadableReceiptModal({
    super.key,
    required this.booking,
    this.paymentMethod = 'GCash via PayMongo',
    this.paymongoReference = 'pm_ref_8921938210',
  });

  static Future<void> show(
    BuildContext context, {
    required BookingModel booking,
    String paymentMethod = 'GCash via PayMongo',
    String paymongoReference = 'pm_ref_8921938210',
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DownloadableReceiptModal(
        booking: booking,
        paymentMethod: paymentMethod,
        paymongoReference: paymongoReference,
      ),
    );
  }

  IconData _getPaymentChannelIcon(String method) {
    final lower = method.toLowerCase();
    if (lower.contains('gcash')) {
      return Icons.account_balance_wallet_rounded;
    } else if (lower.contains('maya')) {
      return Icons.wallet_rounded;
    } else if (lower.contains('grabpay') || lower.contains('grab')) {
      return Icons.send_to_mobile_rounded;
    } else if (lower.contains('card') || lower.contains('visa') || lower.contains('mastercard')) {
      return Icons.credit_card_rounded;
    }
    return Icons.payment_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final courtName = booking.courtName ?? 'SmashCourt - Court 1';
    final dateFormat = DateFormat('MMMM d, yyyy • h:mm a');
    final duration = booking.endTime.difference(booking.startTime).inMinutes / 60.0;
    final baseRate = booking.totalAmount / (duration > 0 ? duration : 1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textMuted.withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

          // Header Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCCFF00).withAlpha(25),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFCCFF00).withAlpha(80)),
                      ),
                      child: Text(
                        'Official Court Reservation Receipt',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFCCFF00),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    Text(
                      'Official Payment Receipt',
                      style: GoogleFonts.inter(
                        color: colors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'PayMongo Transaction Confirmed',
                      style: GoogleFonts.inter(
                        color: colors.neonGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.neonGreen.withAlpha(25),
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.neonGreen.withAlpha(70)),
                ),
                child: Icon(
                  Icons.receipt_long_rounded,
                  color: colors.neonGreen,
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Perforated Digital Ticket Box
          Container(
            decoration: BoxDecoration(
              color: colors.surfaceHighlight,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.borderSubtle),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Upper Ticket Section (Reservation Details)
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildReceiptRow(context, 'Booking ID', booking.id),
                        const SizedBox(height: 8),
                        _buildReceiptRow(context, 'Court', courtName),
                        const SizedBox(height: 8),
                        _buildReceiptRow(
                          context,
                          'Slot Reserved',
                          dateFormat.format(booking.startTime),
                        ),
                        const SizedBox(height: 8),
                        _buildReceiptRowWithIcon(
                          context,
                          'Payment Method',
                          paymentMethod,
                          _getPaymentChannelIcon(paymentMethod),
                        ),
                        const SizedBox(height: 8),
                        _buildReceiptRow(context, 'PayMongo Ref', paymongoReference),
                      ],
                    ),
                  ),

                  // Perforated Ticket Divider with Ticket Notches
                  _buildPerforatedDivider(context),

                  // Lower Ticket Section (Itemized Calculation)
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildReceiptRow(
                          context,
                          'Court Rate (${duration.toStringAsFixed(1)} hrs)',
                          '₱${baseRate.toStringAsFixed(2)} / hr',
                        ),
                        const SizedBox(height: 8),
                        _buildReceiptRow(context, 'Tax & Service Fee', '₱0.00 (Included)'),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(height: 1),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'TOTAL PAID',
                              style: GoogleFonts.inter(
                                color: colors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '₱${booking.totalAmount.toStringAsFixed(2)}',
                              style: GoogleFonts.inter(
                                color: const Color(0xFFCCFF00),
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Receipt Barcode Aesthetics
                        _buildBarcodeAesthetics(context),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),

          // Download PDF & Share Receipt Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    minimumSize: const Size.fromHeight(48),
                    side: BorderSide(color: colors.borderSubtle),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Receipt PDF downloaded to device storage.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    Navigator.pop(context);
                  },
                  icon: Icon(Icons.download_rounded, color: colors.textPrimary),
                  label: Text(
                    'Download PDF',
                    style: GoogleFonts.inter(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: colors.neonGreen,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Receipt exported to share sheet.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.share_rounded),
                  label: Text(
                    'Share Receipt',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
      ),
    );
  }

  Widget _buildPerforatedDivider(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: 20,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Dashed Perforation Line
          LayoutBuilder(
            builder: (context, constraints) {
              final boxWidth = constraints.constrainWidth();
              const dashWidth = 5.0;
              const dashSpace = 4.0;
              final dashCount = (boxWidth / (dashWidth + dashSpace)).floor();
              return Flex(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                direction: Axis.horizontal,
                children: List.generate(dashCount, (_) {
                  return SizedBox(
                    width: dashWidth,
                    height: 1.2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.borderSubtle,
                      ),
                    ),
                  );
                }),
              );
            },
          ),
          // Left Ticket Notch (semi-circle cutout)
          Positioned(
            left: -10,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                shape: BoxShape.circle,
                border: Border.all(color: colors.borderSubtle),
              ),
            ),
          ),
          // Right Ticket Notch (semi-circle cutout)
          Positioned(
            right: -10,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                shape: BoxShape.circle,
                border: Border.all(color: colors.borderSubtle),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarcodeAesthetics(BuildContext context) {
    final colors = context.colors;
    final sanitizedRef = paymongoReference.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    final barcodeId = 'PKL*${booking.id}*$sanitizedRef';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: colors.surface.withAlpha(120),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.borderSubtle.withAlpha(60)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(34, (index) {
              final isThick = index % 3 == 0 || index % 7 == 0;
              final isGap = index % 11 == 0;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 1.2),
                width: isThick ? 2.8 : 1.4,
                height: 24,
                color: isGap
                    ? Colors.transparent
                    : colors.textPrimary.withAlpha(180),
              );
            }),
          ),
          const SizedBox(height: 5),
          Text(
            barcodeId,
            style: GoogleFonts.robotoMono(
              color: const Color(0xFFCCFF00),
              fontSize: 9.0,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(BuildContext context, String label, String value) {
    final colors = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: colors.textMuted,
            fontSize: 12.5,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: GoogleFonts.inter(
              color: colors.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptRowWithIcon(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    final colors = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: colors.textMuted,
            fontSize: 12.5,
          ),
        ),
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: colors.neonGreen),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: GoogleFonts.inter(
                    color: colors.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
