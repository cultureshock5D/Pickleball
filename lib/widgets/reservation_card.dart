import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/validators.dart';
import '../models/booking_model.dart';
import '../services/calendar_link_service.dart';
import 'booking_success_modal.dart';
import 'check_in_qr_modal.dart';
import 'downloadable_receipt_modal.dart';

class ReservationCard extends StatefulWidget {
  final BookingModel booking;
  final bool isUpcoming;
  final VoidCallback? onRefresh;

  const ReservationCard({
    super.key,
    required this.booking,
    this.isUpcoming = true,
    this.onRefresh,
  });

  @override
  State<ReservationCard> createState() => _ReservationCardState();
}

class _ReservationCardState extends State<ReservationCard>
    with SingleTickerProviderStateMixin {
  bool _isAddingToCalendar = false;
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;

  // Memoized formatters (zero allocation per frame)
  static final DateFormat _monthDayYearFormat = DateFormat('MMMM d, y');
  static final DateFormat _fullDayFormat = DateFormat('EEEE, MMMM d, y');

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.95,
      upperBound: 1.0,
      value: 1.0,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _pressController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  String _formatDateHeader(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final target = DateTime(dt.year, dt.month, dt.day);

    if (target == today) {
      return 'Today • ${_monthDayYearFormat.format(dt)}';
    } else if (target == tomorrow) {
      return 'Tomorrow • ${_monthDayYearFormat.format(dt)}';
    }
    return _fullDayFormat.format(dt);
  }

  String _formatTimeSlot(DateTime start, DateTime end) {
    return Validators.formatTimeSlotRange(start, end);
  }

  Future<void> _handleAddToCalendar() async {
    HapticFeedback.lightImpact();
    _pressController.forward(from: 0.95);
    setState(() => _isAddingToCalendar = true);
    try {
      await CalendarLinkService.addBookingToCalendar(
        widget.booking,
        context: context,
      );
    } finally {
      if (mounted) {
        setState(() => _isAddingToCalendar = false);
      }
    }
  }

  void _openDetailsModal() {
    HapticFeedback.selectionClick();
    BookingSuccessModal.show(
      context,
      booking: widget.booking,
    );
  }

  void _openCheckInQrModal() {
    HapticFeedback.mediumImpact();
    CheckInQrModal.show(context, booking: widget.booking);
  }

  void _openReceiptModal() {
    HapticFeedback.lightImpact();
    DownloadableReceiptModal.show(context, booking: widget.booking);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;
    final booking = widget.booking;
    final status = booking.status.toLowerCase();
    final isConfirmed = status == 'confirmed';
    final isPending = status == 'pending';
    final isCompleted = status == 'completed';

    Color statusColor = colors.neonGreen;
    if (isPending) {
      statusColor = colors.neonYellow;
    } else if (isCompleted) {
      statusColor = colors.textMuted;
    } else if (status == 'cancelled') {
      statusColor = colors.errorRed;
    }

    final courtName = booking.courtName ?? 'SmashCourt - Court 1';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: widget.isUpcoming ? colors.borderSubtle : colors.borderSubtleAlpha50,
          width: 1.2,
        ),
        boxShadow: widget.isUpcoming ? colors.cardShadow : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: _openDetailsModal,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Date Header & Status Pill
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          color: widget.isUpcoming ? colors.neonGreen : colors.textMuted,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatDateHeader(booking.startTime),
                          style: GoogleFonts.inter(
                            color: widget.isUpcoming ? colors.textPrimary : colors.textMuted,
                            fontSize: 12.5,
                            fontWeight: widget.isUpcoming ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withAlpha(35),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusColor.withAlpha(70)),
                      ),
                      child: Text(
                        booking.status.toUpperCase(),
                        style: GoogleFonts.inter(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 2. Court Badge & Price Info
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colors.surfaceHighlight,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isConfirmed
                              ? colors.neonGreenAlpha40
                              : colors.borderSubtle,
                        ),
                      ),
                      child: Icon(
                        Icons.sports_tennis_rounded,
                        color: isConfirmed ? colors.neonGreen : colors.textSecondary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            courtName,
                            style: GoogleFonts.inter(
                              color: colors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatTimeSlot(booking.startTime, booking.endTime),
                            style: GoogleFonts.inter(
                              color: colors.textMuted,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₱${booking.totalAmount.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(
                            color: isCompleted ? colors.textMuted : colors.neonLime,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          booking.id.length > 8 ? '${booking.id.substring(0, 8)}...' : booking.id,
                          style: GoogleFonts.robotoMono(
                            color: colors.textMuted,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // 3. Quick Action Buttons: Gate QR Check-In, PayMongo Receipt, & Add to Calendar
                const SizedBox(height: 12),
                Divider(color: colors.borderSubtle, height: 1),
                const SizedBox(height: 10),
                Row(
                  children: [
                    // QR Pass Action
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          side: BorderSide(color: colors.neonGreenAlpha50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _openCheckInQrModal,
                        icon: Icon(Icons.qr_code_2_rounded, size: 16, color: colors.neonGreen),
                        label: Text(
                          'Gate Pass',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: colors.neonGreen,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Receipt Action
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          side: BorderSide(color: colors.borderSubtle),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _openReceiptModal,
                        icon: Icon(Icons.receipt_long_rounded, size: 16, color: colors.textSecondary),
                        label: Text(
                          'Receipt',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    ),

                    if (widget.isUpcoming) ...[
                      const SizedBox(width: 8),
                      // Calendar Action Icon Button
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: colors.neonGreenAlpha12,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: colors.neonGreenAlpha40),
                          ),
                        ),
                        onPressed: _isAddingToCalendar ? null : _handleAddToCalendar,
                        icon: _isAddingToCalendar
                            ? SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(colors.neonGreen),
                                ),
                              )
                            : Icon(Icons.event_available_rounded, size: 18, color: colors.neonGreen),
                        tooltip: 'Add to Google Calendar',
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
