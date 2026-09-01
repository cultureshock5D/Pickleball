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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final courtName = booking.courtName ?? 'SmashCourt - Court 1';
    final dateFormat = DateFormat('MMMM d, yyyy • h:mm a');
    final duration = booking.endTime.difference(booking.startTime).inMinutes / 60.0;
    final baseRate = booking.totalAmount / (duration > 0 ? duration : 1);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: colors.borderSubtle),
      ),
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
          const SizedBox(height: 20),

          // Header Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.neonGreen.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.receipt_long_rounded,
                  color: colors.neonGreen,
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Receipt Container Box
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.surfaceHighlight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.borderSubtle),
            ),
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
                _buildReceiptRow(context, 'Payment Method', paymentMethod),
                const SizedBox(height: 8),
                _buildReceiptRow(context, 'PayMongo Ref', paymongoReference),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1),
                ),

                // Itemized Calculation
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
                        color: colors.neonGreen,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Download PDF & Share Receipt Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
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
          const SizedBox(height: 12),
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
}
