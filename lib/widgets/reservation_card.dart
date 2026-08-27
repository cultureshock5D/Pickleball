import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import '../models/booking_model.dart';
import '../services/calendar_link_service.dart';
import 'booking_success_modal.dart';

/// Reusable Luxury Reservation Card for booking feeds and schedules.
///
/// Features:
/// - Memoized date/time formatters for high frame-rate rendering.
/// - Venue / court identification with status chip.
/// - Integrated emerald "Add to Google Calendar" button with micro-animation.
/// - Tap to view full confirmation modal.
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
  static final DateFormat _timeFormat = DateFormat('h:mm a');

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
    final startStr = _timeFormat.format(start);
    final endStr = _timeFormat.format(end);
    return '$startStr - $endStr';
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

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final status = booking.status.toLowerCase();
    final isConfirmed = status == 'confirmed';
    final isPending = status == 'pending';
    final isCompleted = status == 'completed';

    Color statusColor = AppTheme.neonGreen;
    if (isPending) {
      statusColor = AppTheme.neonYellow;
    } else if (isCompleted) {
      statusColor = AppTheme.textMuted;
    } else if (status == 'cancelled') {
      statusColor = AppTheme.errorRed;
    }

    final courtName = booking.courtName ?? 'SmashCourt - Court 1';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: widget.isUpcoming ? AppTheme.borderSubtle : AppTheme.borderSubtleAlpha50,
          width: 1.2,
        ),
        boxShadow: widget.isUpcoming ? AppTheme.cardShadow : null,
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
                          color: widget.isUpcoming ? AppTheme.neonGreen : AppTheme.textMuted,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatDateHeader(booking.startTime),
                          style: GoogleFonts.inter(
                            color: widget.isUpcoming ? Colors.white : AppTheme.textMuted,
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
                        color: const Color(0xFF26262E),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isConfirmed
                              ? AppTheme.neonGreenAlpha40
                              : AppTheme.borderSubtle,
                        ),
                      ),
                      child: const Icon(
                        Icons.sports_tennis_rounded,
                        color: Colors.white,
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
                            style: AppTheme.fontCardTitle,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatTimeSlot(booking.startTime, booking.endTime),
                            style: AppTheme.fontMuted,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${booking.totalAmount.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(
                            color: isCompleted ? Colors.white70 : AppTheme.neonLime,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          booking.id.length > 8 ? '${booking.id.substring(0, 8)}...' : booking.id,
                          style: GoogleFonts.robotoMono(
                            color: AppTheme.textMuted,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // 3. Calendar Quick Action for upcoming bookings
                if (widget.isUpcoming) ...[
                  const SizedBox(height: 12),
                  const Divider(color: AppTheme.borderSubtle, height: 1),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ScaleTransition(
                          scale: _scaleAnimation,
                          child: GestureDetector(
                            onTapDown: (_) => _pressController.reverse(),
                            onTapUp: (_) => _pressController.forward(),
                            onTapCancel: () => _pressController.forward(),
                            child: Container(
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppTheme.neonGreenAlpha12,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppTheme.neonGreenAlpha50,
                                  width: 1.2,
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: _isAddingToCalendar ? null : _handleAddToCalendar,
                                  child: Center(
                                    child: _isAddingToCalendar
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                AppTheme.neonGreen,
                                              ),
                                            ),
                                          )
                                        : Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                Icons.event_available_rounded,
                                                color: AppTheme.neonGreen,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Add to Google Calendar',
                                                style: GoogleFonts.inter(
                                                  color: Colors.white,
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
