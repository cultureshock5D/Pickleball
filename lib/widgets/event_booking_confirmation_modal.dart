import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import '../models/event_space_model.dart';
import 'tap_collapse.dart';

class EventBookingConfirmationModal extends StatelessWidget {
  final EventBookingModel booking;
  final VoidCallback? onDismiss;

  const EventBookingConfirmationModal({
    super.key,
    required this.booking,
    this.onDismiss,
  });

  static Future<void> show(BuildContext context, {required EventBookingModel booking, VoidCallback? onDismiss}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EventBookingConfirmationModal(
        booking: booking,
        onDismiss: onDismiss,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dateFormat = DateFormat('EEE, MMMM d, yyyy');
    final isInquiry = booking.isMessageFirst || booking.totalAmount == 0;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: colors.borderSubtle),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.paddingOf(context).bottom + 20,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Success Badge & Title
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colors.neonGreenAlpha15,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colors.neonGreen, width: 1.5),
                  ),
                  child: Icon(
                    isInquiry ? Icons.mark_chat_unread_outlined : Icons.check_circle_rounded,
                    color: colors.neonGreen,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isInquiry ? 'INQUIRY SUBMITTED' : 'EVENT RESERVED',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: colors.neonGreen,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isInquiry ? 'Inquiry Received' : 'Booking Confirmed',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: colors.surfaceHighlight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.borderSubtle),
                  ),
                  child: Text(
                    booking.id,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (isInquiry) ...[
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: colors.neonGreenAlpha15,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.neonGreen.withAlpha(60)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.chat_bubble_outline_rounded, size: 18, color: colors.neonGreen),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "We'll Message You Directly",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'No payment charged now. Our coordinator will contact you to confirm dates, customize your package, and arrange your free ocular inspection.',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: colors.textSecondary,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Space & Schedule Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    booking.spaceName,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${booking.eventType} • ${booking.guestCount} Guests • ${booking.packageType.label}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: colors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 14, color: colors.neonGreen),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                dateFormat.format(booking.date),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: colors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.access_time_rounded, size: 14, color: colors.neonGreen),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                '${booking.startTime.format(context)} – ${booking.endTime.format(context)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: colors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Itemized Breakdown
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.borderSubtle),
              ),
              child: Column(
                children: [
                  _buildSummaryRow(
                    colors,
                    label: 'Base Space Rental (${booking.packageType.label})',
                    value: isInquiry ? 'Message Us First' : '₱${booking.basePrice.toStringAsFixed(0)}',
                  ),
                  if (booking.selectedAddons.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _buildSummaryRow(
                      colors,
                      label: 'Equipment & Services (${booking.selectedAddons.length})',
                      value: isInquiry ? 'Included in quote' : '₱${booking.addonsPrice.toStringAsFixed(0)}',
                    ),
                  ],
                  const SizedBox(height: 10),
                  _buildSummaryRow(
                    colors,
                    label: 'Refundable Security Deposit',
                    value: isInquiry ? '₱0 (On Confirmation)' : '₱${booking.securityDeposit.toStringAsFixed(0)}',
                    isMuted: true,
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          isInquiry ? 'Payment Due Now' : 'Total Reservation',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isInquiry ? '₱0 (Inquiry Only)' : '₱${booking.totalAmount.toStringAsFixed(0)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: colors.neonGreen,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            TapCollapse(
              onTap: () {
                HapticFeedback.mediumImpact();
                Navigator.of(context).pop();
                onDismiss?.call();
              },
              child: Container(
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.neonGreen,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Done & Return to Arena',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    AppPalette colors, {
    required String label,
    required String value,
    bool isMuted = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              color: isMuted ? colors.textMuted : colors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: isMuted ? colors.textMuted : colors.textPrimary,
          ),
        ),
      ],
    );
  }
}
