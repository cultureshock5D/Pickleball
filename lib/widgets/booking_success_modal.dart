import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/validators.dart';
import '../models/booking_model.dart';
import '../services/calendar_link_service.dart';

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
      barrierColor: Colors.black54,
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
    with TickerProviderStateMixin {
  bool _isLaunchingCalendar = false;
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late AnimationController _entranceController;
  late Animation<double> _entranceScale;
  late Animation<double> _entranceFade;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.96,
      value: 1.0,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..forward();
    _entranceScale = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutBack,
    );
    _entranceFade = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _animController.dispose();
    super.dispose();
  }

  String _formatExactDate(DateTime dt) {
    return DateFormat('EEEE, MMMM d, y').format(dt);
  }

  String _formatTimeSlot(DateTime start, DateTime end) {
    return Validators.formatTimeSlotRange(start, end);
  }

  Future<void> _handleAddCalendar() async {
    HapticFeedback.lightImpact();
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
    final colors = context.colors;
    final isDark = context.isDark;
    final booking = widget.booking;
    final courtName = booking.courtName ?? 'C&J Pickleball - Court 1';
    final venue = widget.venueName ?? 'C&J Pickleball Court';
    final isConfirmed = booking.status.toLowerCase() == 'confirmed';
    final statusText = isConfirmed ? 'Confirmed' : booking.status.toUpperCase();
    final statusColor = isConfirmed ? colors.neonGreen : colors.neonLime;

    return Container(
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.paddingOf(context).bottom + 20,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(
          top: BorderSide(color: colors.borderSubtle, width: 1.5),
        ),
      ),
      child: FadeTransition(
        opacity: _entranceFade,
        child: ScaleTransition(
          scale: _entranceScale,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              // Drag Handle
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Glowing Success Badge Header with Electric Lime #CCFF00 Glow
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.neonGreenAlpha14,
                  border: Border.all(color: const Color(0xFFCCFF00), width: 2.2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFCCFF00).withAlpha(100),
                      blurRadius: 26,
                      spreadRadius: 3,
                    ),
                    BoxShadow(
                      color: colors.neonGreenAlpha35,
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFFCCFF00),
                    size: 42,
                  ),
                ),
              ),
          const SizedBox(height: 16),

          Text(
            'Reservation Confirmed!',
            style: GoogleFonts.inter(
              color: colors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your court has been successfully locked in.',
            style: GoogleFonts.inter(
              color: colors.textSecondary,
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 20),

          // Reservation Summary Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.surfaceElevated,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colors.borderSubtle, width: 1.2),
              boxShadow: colors.cardShadow,
            ),
            child: Column(
              children: [
                // Venue & Court Header Row
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colors.surfaceHighlight,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.sports_tennis_rounded,
                        color: colors.neonGreen,
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
                              color: colors.textPrimary,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            venue,
                            style: GoogleFonts.inter(
                              color: colors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withAlpha(38),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusColor.withAlpha(102)),
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
                Divider(color: colors.borderSubtle, height: 24),

                // Date Row
                _buildInfoRow(
                  colors: colors,
                  icon: Icons.calendar_today_rounded,
                  label: 'Date',
                  value: _formatExactDate(booking.startTime),
                ),
                const SizedBox(height: 12),

                // Time Slot Row
                _buildInfoRow(
                  colors: colors,
                  icon: Icons.schedule_rounded,
                  label: 'Time Slot',
                  value: _formatTimeSlot(booking.startTime, booking.endTime),
                ),
                const SizedBox(height: 12),

                // Total Price Row
                _buildInfoRow(
                  colors: colors,
                  icon: Icons.payments_outlined,
                  label: 'Total Paid',
                  value: '₱${booking.totalAmount.toStringAsFixed(2)}',
                  valueColor: colors.neonLime,
                  isBold: true,
                ),
                Divider(color: colors.borderSubtle, height: 24),

                // Booking Reference ID
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Booking Reference',
                      style: GoogleFonts.inter(
                        color: colors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: colors.surfaceHighlight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        booking.id,
                        style: GoogleFonts.robotoMono(
                          color: colors.textSecondary,
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

          // Primary CTA: Add to Google Calendar
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
                  color: colors.neonGreenAlpha12,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: colors.neonGreen,
                    width: 1.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.neonGreenAlpha22,
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
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  colors.neonGreen,
                                ),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.calendar_month_rounded,
                                  color: colors.neonGreen,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Add to Google Calendar',
                                  style: GoogleFonts.inter(
                                    color: isDark ? Colors.white : colors.neonGreenDark,
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
          const SizedBox(height: 10),

          // Multi-Calendar Direct Sync Actions (Apple, Outlook, .ics)
          Row(
            children: [
              Expanded(
                child: _buildCalendarQuickAction(
                  context,
                  label: 'Apple',
                  icon: Icons.apple,
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    final url = CalendarLinkService.buildAppleCalendarUrl(
                      title: 'Pickleball @ $courtName',
                      startTime: booking.startTime,
                      endTime: booking.endTime,
                      location: venue,
                    );
                    await CalendarLinkService.launchCalendarLink(url, context: context);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCalendarQuickAction(
                  context,
                  label: 'Outlook',
                  icon: Icons.mail_outline_rounded,
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    final url = CalendarLinkService.buildOutlookCalendarUrl(
                      title: 'Pickleball @ $courtName',
                      startTime: booking.startTime,
                      endTime: booking.endTime,
                      location: venue,
                    );
                    await CalendarLinkService.launchCalendarLink(url, context: context);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCalendarQuickAction(
                  context,
                  label: 'iCal (.ics)',
                  icon: Icons.file_download_outlined,
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    final ics = CalendarLinkService.buildIcsCalendarData(
                      title: 'Pickleball @ $courtName',
                      startTime: booking.startTime,
                      endTime: booking.endTime,
                      location: venue,
                    );
                    final url = 'data:text/calendar;charset=utf8,${Uri.encodeComponent(ics)}';
                    await CalendarLinkService.launchCalendarLink(url, context: context);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Secondary CTA: Done / View My Bookings
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).pop();
                if (widget.onViewBookings != null) {
                  widget.onViewBookings!();
                }
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: colors.borderSubtle),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'Done • View My Bookings',
                style: GoogleFonts.inter(
                  color: colors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    ),
    ),
  );
}

  Widget _buildCalendarQuickAction(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;
    return SizedBox(
      height: 48,
      child: Semantics(
        button: true,
        label: 'Sync to $label',
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            side: BorderSide(color: colors.borderSubtle),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: colors.textSecondary),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    color: colors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required AppPalette colors,
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    bool isBold = false,
  }) {
    return Row(
      children: [
        Icon(icon, color: colors.textMuted, size: 16),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            color: colors.textMuted,
            fontSize: 13,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.inter(
            color: valueColor ?? colors.textPrimary,
            fontSize: isBold ? 14.5 : 13,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
