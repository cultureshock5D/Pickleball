import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../models/court_model.dart';
import '../../services/booking_service.dart';
import '../../services/calendar_link_service.dart';
import '../../widgets/booking_success_modal.dart';
import '../../widgets/neon_button.dart';

class BookingReviewScreen extends StatefulWidget {
  final CourtModel court;
  final String venueName;
  final DateTime startTime;
  final DateTime endTime;
  final double durationHours;
  final double totalAmount;
  final int playerCount;
  final VoidCallback? onViewBookings;

  const BookingReviewScreen({
    super.key,
    required this.court,
    this.venueName = 'Barcelona Smash Club',
    required this.startTime,
    required this.endTime,
    required this.durationHours,
    required this.totalAmount,
    this.playerCount = 4,
    this.onViewBookings,
  });

  @override
  State<BookingReviewScreen> createState() => _BookingReviewScreenState();
}

class _BookingReviewScreenState extends State<BookingReviewScreen> {
  final BookingService _bookingService = BookingService.instance;
  bool _isSubmitting = false;
  bool _autoLaunchCalendar = true;
  int _selectedPaymentMethodIndex = 0;

  final List<Map<String, dynamic>> _paymentMethods = [
    {
      'title': 'Apple Pay / Google Pay',
      'subtitle': 'Instant 1-Tap Secure Checkout',
      'icon': Icons.payment_rounded,
      'isDefault': true,
    },
    {
      'title': 'Club Membership Card',
      'subtitle': 'Prepaid Luxury Account Balance',
      'icon': Icons.credit_card_rounded,
      'isDefault': false,
    },
  ];

  String _formatTime(DateTime dt) {
    return DateFormat('h:mm a').format(dt);
  }

  String _formatDateFull(DateTime dt) {
    return DateFormat('EEEE, MMMM d, y').format(dt);
  }

  Future<void> _handleConfirmBooking() async {
    setState(() => _isSubmitting = true);

    try {
      final booking = await _bookingService.createBooking(
        courtId: widget.court.id,
        startTime: widget.startTime,
        endTime: widget.endTime,
        totalAmount: widget.totalAmount,
      );

      if (mounted) {
        if (_autoLaunchCalendar) {
          CalendarLinkService.addBookingToCalendar(
            booking,
            context: context,
            venueName: widget.venueName,
          );
        }

        Navigator.of(context).pop();

        BookingSuccessModal.show(
          context,
          booking: booking,
          onViewBookings: widget.onViewBookings,
          venueName: widget.venueName,
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: colors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Review & Confirm',
          style: GoogleFonts.inter(
            color: colors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Court & Venue Overview Card
                    _buildCourtSummaryCard(),
                    const SizedBox(height: 16),

                    // 2. Date & Schedule Details Card
                    _buildScheduleCard(),
                    const SizedBox(height: 16),

                    // 3. Price Breakdown Ledger
                    _buildPricingBreakdownCard(),
                    const SizedBox(height: 16),

                    // 4. Google Calendar Auto-Sync Option
                    _buildCalendarSyncCard(),
                    const SizedBox(height: 16),

                    // 5. Payment Method Selector
                    _buildPaymentMethodSection(),
                    const SizedBox(height: 16),

                    // 6. Cancellation & Venue Policy
                    _buildPolicyCard(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Persistent Bottom Sticky CTA Action Bar
            _buildBottomCheckoutBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildCourtSummaryCard() {
    final colors = context.colors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.borderSubtle),
        boxShadow: colors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.neonGreenAlpha12,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.neonGreenAlpha30),
                ),
                child: Center(
                  child: Icon(
                    Icons.sports_tennis_rounded,
                    color: colors.neonGreen,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.court.name,
                      style: GoogleFonts.inter(
                        color: colors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${widget.venueName} • Championship Venue',
                      style: GoogleFonts.inter(
                        color: colors.textMuted,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.neonLimeAlpha12,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.neonLimeAlpha30),
                ),
                child: Text(
                  '₱${widget.court.hourlyRate.toStringAsFixed(0)}/hr',
                  style: GoogleFonts.inter(
                    color: colors.neonLime,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: colors.borderSubtle, height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildFeatureBadge(
                Icons.layers_rounded,
                widget.court.surfaceType ?? 'Pro-Cushion Hardcourt',
              ),
              const SizedBox(width: 8),
              _buildFeatureBadge(
                Icons.roofing_rounded,
                widget.court.courtType ?? 'Championship Indoor',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureBadge(IconData icon, String label) {
    final colors = context.colors;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: colors.surfaceHighlight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.borderSubtle),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: colors.textMuted, size: 14),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  color: colors.textSecondary,
                  fontSize: 11.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleCard() {
    final colors = context.colors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month_rounded, color: colors.neonGreen, size: 18),
              const SizedBox(width: 8),
              Text(
                'Date & Schedule Details',
                style: GoogleFonts.inter(
                  color: colors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.neonGreenAlpha12,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${widget.durationHours}h · ${widget.playerCount} Players',
                  style: GoogleFonts.inter(
                    color: colors.neonGreen,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surfaceHighlight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.borderSubtle),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Date', style: GoogleFonts.inter(color: colors.textMuted, fontSize: 13)),
                    Text(
                      _formatDateFull(widget.startTime),
                      style: GoogleFonts.inter(
                        color: colors.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Divider(color: colors.borderSubtle, height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Time Window', style: GoogleFonts.inter(color: colors.textMuted, fontSize: 13)),
                    Text(
                      '${_formatTime(widget.startTime)} – ${_formatTime(widget.endTime)}',
                      style: GoogleFonts.inter(
                        color: colors.neonLime,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingBreakdownCard() {
    final colors = context.colors;
    final subtotal = widget.court.hourlyRate * widget.durationHours;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long_rounded, color: colors.neonLime, size: 18),
              const SizedBox(width: 8),
              Text(
                'Price Breakdown',
                style: GoogleFonts.inter(
                  color: colors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildPriceRow(
            'Court Rate (${widget.court.name})',
            '₱${widget.court.hourlyRate.toStringAsFixed(2)} / hr',
          ),
          const SizedBox(height: 8),
          _buildPriceRow(
            'Duration Multiplier',
            '${widget.durationHours} hrs',
          ),
          const SizedBox(height: 8),
          _buildPriceRow(
            'Subtotal',
            '₱${subtotal.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 8),
          _buildPriceRow(
            'Club Service & Booking Fee',
            'FREE (₱0.00)',
            valueColor: colors.neonGreen,
          ),
          Divider(color: colors.borderSubtle, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Amount',
                style: GoogleFonts.inter(
                  color: colors.textPrimary,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '₱${widget.totalAmount.toStringAsFixed(2)}',
                style: GoogleFonts.inter(
                  color: colors.neonLime,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, {Color? valueColor}) {
    final colors = context.colors;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(color: colors.textMuted, fontSize: 13)),
        Text(
          value,
          style: GoogleFonts.inter(
            color: valueColor ?? colors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarSyncCard() {
    final colors = context.colors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.neonGreenAlpha12,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.event_available_rounded,
              color: colors.neonGreen,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '1-Tap Google Calendar Sync',
                  style: GoogleFonts.inter(
                    color: colors.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Auto-generate calendar event with zero auth',
                  style: GoogleFonts.inter(color: colors.textMuted, fontSize: 11.5),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _autoLaunchCalendar,
            activeTrackColor: colors.neonGreen,
            onChanged: (val) => setState(() => _autoLaunchCalendar = val),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSection() {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Payment Method',
          style: GoogleFonts.inter(
            color: colors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        ...List.generate(_paymentMethods.length, (index) {
          final method = _paymentMethods[index];
          final isSelected = _selectedPaymentMethodIndex == index;

          return GestureDetector(
            onTap: () => setState(() => _selectedPaymentMethodIndex = index),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isSelected
                    ? colors.neonGreenAlpha08
                    : colors.surfaceElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? colors.neonGreen : colors.borderSubtle,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    method['icon'] as IconData,
                    color: isSelected ? colors.neonGreen : colors.textMuted,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          method['title'] as String,
                          style: GoogleFonts.inter(
                            color: colors.textPrimary,
                            fontSize: 13.5,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                        Text(
                          method['subtitle'] as String,
                          style: GoogleFonts.inter(
                            color: colors.textMuted,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: isSelected ? colors.neonGreen : colors.textMuted,
                    size: 20,
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPolicyCard() {
    final colors = context.colors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: colors.neonLime, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Flexible Cancellation Guarantee',
                  style: GoogleFonts.inter(
                    color: colors.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Cancel up to 12 hours before start time for a 100% full refund to your payment method.',
                  style: GoogleFonts.inter(
                    color: colors.textMuted,
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCheckoutBar() {
    final colors = context.colors;
    final isDark = context.isDark;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111115) : Colors.white,
        border: Border(top: BorderSide(color: colors.borderSubtle)),
        boxShadow: colors.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TOTAL AMOUNT',
                    style: GoogleFonts.inter(
                      color: colors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  Text(
                    '₱${widget.totalAmount.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(
                      color: colors.neonLime,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.neonGreenAlpha12,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.neonGreenAlpha30),
                ),
                child: Text(
                  '${widget.durationHours}h Session',
                  style: GoogleFonts.inter(
                    color: colors.neonGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          NeonButton(
            text: 'Confirm & Lock Court Reservation',
            isLoading: _isSubmitting,
            icon: Icons.lock_outline_rounded,
            onPressed: _handleConfirmBooking,
          ),
        ],
      ),
    );
  }
}
