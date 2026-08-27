import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import '../models/booking_model.dart';
import '../services/calendar_link_service.dart';

/// Luxury dark-themed Booking Success Modal & Confirmation Card.
///
/// Features:
/// - Displays confirmed reservation details (Venue/Court, Date & Time Slot, Price, Status).
/// - Emerald-accented "Add to Google Calendar" primary CTA with smooth tap animation.
/// - Secondary "Done / View My Bookings" CTA.
class BookingSuccessModal extends StatefulWidget {
  final BookingModel booking;
  final VoidCallback? onViewBookings;
  final String? venueName;

  const BookingSuccessModal({
    super.key,
    required this.booking,
    this.onViewBookings,
    this.venueName,
  });

  /// Displays the modal as a modern, polished bottom sheet or dialog.
  static Future<void> show(
    BuildContext context, {
    required BookingModel booking,
    VoidCallback? onViewBookings,
    String? venueName,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.75),
      builder: (ctx) => BookingSuccessModal(
        booking: booking,
        onViewBookings: onViewBookings,
        venueName: venueName,
      ),
    );
  }

  @override
  State<BookingSuccessModal> createState() => _BookingSuccessModalState();
}

class _BookingSuccessModalState extends State<BookingSuccessModal>
    with SingleTickerProviderStateMixin {
  bool _isLaunchingCalendar = false;
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.96,
      upperBound: 1.0,
      value: 1.0,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  String _formatExactDate(DateTime dt) {
    return DateFormat('EEEE, MMMM d, y').format(dt);
  }

  String _formatTimeSlot(DateTime start, DateTime end) {
    final startStr = DateFormat('h:mm a').format(start);
    final endStr = DateFormat('h:mm a').format(end);
    return '$startStr - $endStr';
  }

  Future<void> _handleAddCalendar() async {
    _animController.forward(from: 0.96);
    setState(() => _isLaunchingCalendar = true);

    try {
      await CalendarLinkService.addBookingToCalendar(
        widget.booking,
        context: context,
        venueName: widget.venueName,
      );
    } finally {
      if (mounted) {
        setState(() => _isLaunchingCalendar = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final courtName = booking.courtName ?? 'SmashCourt - Court 1';
    final venue = widget.venueName ?? 'SmashCourt Arena';
    final isConfirmed = booking.status.toLowerCase() == 'confirmed';
    final statusText = isConfirmed ? 'Confirmed' : booking.status.toUpperCase();
    final statusColor = isConfirmed ? AppTheme.neonGreen : AppTheme.neonLime;

    return Container(
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(
          top: BorderSide(color: AppTheme.borderSubtle, width: 1.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Drag Handle
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.borderSubtle,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Glowing Success Badge Header
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.neonGreen.withOpacity(0.14),
              border: Border.all(color: AppTheme.neonGreen, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.neonGreen.withOpacity(0.35),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.check_circle_rounded,
                color: AppTheme.neonGreen,
                size: 40,
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'Reservation Confirmed!',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your court has been successfully locked in.',
            style: GoogleFonts.inter(
              color: AppTheme.textSecondary,
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 20),

          // Reservation Summary Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: AppTheme.cardGradient,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.borderSubtle, width: 1.2),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              children: [
                // Venue & Court Header Row
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFF26262E),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.sports_tennis_rounded,
                        color: AppTheme.neonGreen,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            courtName,
                            style: GoogleFonts.inter(
                              color: AppTheme.textPrimary,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            venue,
                            style: GoogleFonts.inter(
                              color: AppTheme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusColor.withOpacity(0.4)),
                      ),
                      child: Text(
                        statusText,
                        style: GoogleFonts.inter(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(color: AppTheme.borderSubtle, height: 24),

                // Date Row
                _buildInfoRow(
                  icon: Icons.calendar_today_rounded,
                  label: 'Date',
                  value: _formatExactDate(booking.startTime),
                ),
                const SizedBox(height: 12),

                // Time Slot Row
                _buildInfoRow(
                  icon: Icons.schedule_rounded,
                  label: 'Time Slot',
                  value: _formatTimeSlot(booking.startTime, booking.endTime),
                ),
                const SizedBox(height: 12),

                // Total Price Row
                _buildInfoRow(
                  icon: Icons.payments_outlined,
                  label: 'Total Paid',
                  value: '\$${booking.totalAmount.toStringAsFixed(2)}',
                  valueColor: AppTheme.neonLime,
                  isBold: true,
                ),
                const Divider(color: AppTheme.borderSubtle, height: 24),

                // Booking Reference ID
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Booking Reference',
                      style: GoogleFonts.inter(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceHighlight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        booking.id,
                        style: GoogleFonts.robotoMono(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // Primary CTA: Add to Google Calendar (Emerald outline/surface with animated tap)
          ScaleTransition(
            scale: _scaleAnimation,
            child: GestureDetector(
              onTapDown: (_) => _animController.reverse(),
              onTapUp: (_) => _animController.forward(),
              onTapCancel: () => _animController.forward(),
              child: Container(
                width: double.infinity,
                height: 54,
                decoration: BoxDecoration(
                  color: AppTheme.neonGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppTheme.neonGreen,
                    width: 1.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.neonGreen.withOpacity(0.22),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: _isLaunchingCalendar ? null : _handleAddCalendar,
                    child: Center(
                      child: _isLaunchingCalendar
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.neonGreen),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.calendar_month_rounded,
                                  color: AppTheme.neonGreen,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Add to Google Calendar',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
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
          const SizedBox(height: 12),

          // Secondary CTA: Done / View My Bookings
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (widget.onViewBookings != null) {
                  widget.onViewBookings!();
                }
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.borderSubtle),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'Done • View My Bookings',
                style: GoogleFonts.inter(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    bool isBold = false,
  }) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.textMuted, size: 16),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            color: AppTheme.textMuted,
            fontSize: 13,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.inter(
            color: valueColor ?? Colors.white,
            fontSize: isBold ? 14.5 : 13,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
