import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../models/court_model.dart';
import '../../services/booking_service.dart';
import '../../services/calendar_link_service.dart';
import '../../widgets/booking_success_modal.dart';
import '../../widgets/neon_button.dart';

class BookingScreen extends StatefulWidget {
  final VoidCallback? onViewBookings;

  const BookingScreen({super.key, this.onViewBookings});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final BookingService _bookingService = BookingService.instance;

  // State Variables
  List<CourtModel> _courts = [];
  bool _isLoadingCourts = true;
  CourtModel? _selectedCourt;

  DateTime _selectedDate = DateTime.now();
  int _selectedTimeSlotIndex = 3; // Default 1:00 PM slot
  double _selectedDurationHours = 1.5;
  bool _isSubmitting = false;
  bool _autoLaunchCalendar = true;

  final List<TimeOfDay> _availableStartTimes = [
    const TimeOfDay(hour: 8, minute: 0),
    const TimeOfDay(hour: 9, minute: 30),
    const TimeOfDay(hour: 11, minute: 0),
    const TimeOfDay(hour: 13, minute: 0),
    const TimeOfDay(hour: 14, minute: 30),
    const TimeOfDay(hour: 16, minute: 0),
    const TimeOfDay(hour: 17, minute: 30),
    const TimeOfDay(hour: 19, minute: 0),
    const TimeOfDay(hour: 20, minute: 30),
  ];

  final List<double> _durations = [1.0, 1.5, 2.0, 3.0];

  @override
  void initState() {
    super.initState();
    _loadCourts();
  }

  Future<void> _loadCourts() async {
    setState(() => _isLoadingCourts = true);
    final courts = await _bookingService.fetchActiveCourts();
    if (mounted) {
      setState(() {
        _courts = courts;
        if (_courts.isNotEmpty) {
          _selectedCourt = _courts.first;
        }
        _isLoadingCourts = false;
      });
    }
  }

  double get _baseRate => _selectedCourt?.hourlyRate ?? 120.0;
  double get _subtotal => _baseRate * _selectedDurationHours;
  double get _serviceFee => 0.00; // Free VIP booking fee
  double get _totalAmount => _subtotal + _serviceFee;

  DateTime get _calculatedStartDateTime {
    final time = _availableStartTimes[_selectedTimeSlotIndex];
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      time.hour,
      time.minute,
    );
  }

  DateTime get _calculatedEndDateTime {
    final start = _calculatedStartDateTime;
    final totalMinutes = (_selectedDurationHours * 60).round();
    return start.add(Duration(minutes: totalMinutes));
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _formatDateLong(DateTime date) {
    return DateFormat('EEEE, MMMM d, y').format(date);
  }

  Future<void> _handleCreateBooking() async {
    if (_selectedCourt == null) return;

    final confirmed = await _showConfirmationDialog();
    if (confirmed != true) return;

    setState(() => _isSubmitting = true);

    try {
      final booking = await _bookingService.createBooking(
        courtId: _selectedCourt!.id,
        startTime: _calculatedStartDateTime,
        endTime: _calculatedEndDateTime,
        totalAmount: _totalAmount,
      );

      if (mounted) {
        // Automatically trigger Google Calendar deep link if enabled
        if (_autoLaunchCalendar) {
          CalendarLinkService.addBookingToCalendar(
            booking,
            context: context,
            venueName: 'SmashCourt Arena',
          );
        }

        // Present luxury success modal with direct calendar action and schedule view
        BookingSuccessModal.show(
          context,
          booking: booking,
          onViewBookings: widget.onViewBookings,
          venueName: 'SmashCourt Arena',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.surfaceElevated,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppTheme.errorRed),
            ),
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: AppTheme.errorRed, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    e.toString().replaceAll('Exception: ', ''),
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<bool?> _showConfirmationDialog() {
    final courtName = _selectedCourt?.name ?? 'SmashCourt - Court 1';
    final startTimeStr = _formatTimeOfDay(_availableStartTimes[_selectedTimeSlotIndex]);
    final endTimeStr = _formatTimeOfDay(TimeOfDay.fromDateTime(_calculatedEndDateTime));

    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppTheme.surfaceElevated,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: AppTheme.borderSubtle, width: 1)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.borderSubtle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Confirm Court Reservation',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Review booking details & Google Calendar sync',
                style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 20),

              // Summary Breakdown Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Column(
                  children: [
                    _buildSummaryRow('Venue', 'SmashCourt Arena'),
                    const Divider(color: AppTheme.borderSubtle, height: 16),
                    _buildSummaryRow('Court', courtName),
                    const Divider(color: AppTheme.borderSubtle, height: 16),
                    _buildSummaryRow('Date', _formatDateLong(_selectedDate)),
                    const Divider(color: AppTheme.borderSubtle, height: 16),
                    _buildSummaryRow('Time Slot', '$startTimeStr - $endTimeStr ($_selectedDurationHours hrs)'),
                    const Divider(color: AppTheme.borderSubtle, height: 16),
                    _buildSummaryRow(
                      'Calendar Sync',
                      'Google Calendar (Zero-Auth)',
                      valueColor: AppTheme.neonGreen,
                      isBold: true,
                    ),
                    const Divider(color: AppTheme.borderSubtle, height: 16),
                    _buildSummaryRow(
                      'Total Price',
                      '\$${_totalAmount.toStringAsFixed(2)}',
                      valueColor: AppTheme.neonLime,
                      isBold: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: AppTheme.borderSubtle),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text('Cancel', style: GoogleFonts.inter(color: AppTheme.textMuted)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: NeonButton(
                      text: 'Confirm & Reserve',
                      icon: Icons.event_available_rounded,
                      onPressed: () => Navigator.of(ctx).pop(true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? valueColor, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13),
        ),
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final courtName = _selectedCourt?.name ?? 'SmashCourt - Court 1';
    final startTimeStr = _formatTimeOfDay(_availableStartTimes[_selectedTimeSlotIndex]);
    final endTimeStr = _formatTimeOfDay(TimeOfDay.fromDateTime(_calculatedEndDateTime));

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Clean Court Hero Card (Single Active Court)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppTheme.cardGradient,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: AppTheme.neonGreen.withOpacity(0.5), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.neonGreen.withOpacity(0.18),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppTheme.neonGreen.withOpacity(0.18),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.neonGreen, width: 1.8),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.sports_tennis_rounded,
                          color: AppTheme.neonGreen,
                          size: 26,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                courtName,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.neonLime.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppTheme.neonLime.withOpacity(0.4)),
                                ),
                                child: Text(
                                  'ACTIVE',
                                  style: GoogleFonts.inter(
                                    color: AppTheme.neonLime,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'SmashCourt Arena • Championship Indoor Hardcourt',
                            style: GoogleFonts.inter(
                              color: AppTheme.textSecondary,
                              fontSize: 12.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '\$${_baseRate.toStringAsFixed(0)} / hour',
                            style: GoogleFonts.inter(
                              color: AppTheme.neonLime,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: AppTheme.borderSubtle, height: 1),
                const SizedBox(height: 14),

                // Google Calendar Badge Feature
                Row(
                  children: [
                    const Icon(
                      Icons.event_available_rounded,
                      color: AppTheme.neonGreen,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '1-Tap Google Calendar Deep Link Included',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Switch.adaptive(
                      value: _autoLaunchCalendar,
                      activeColor: AppTheme.neonGreen,
                      onChanged: (val) => setState(() => _autoLaunchCalendar = val),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // 2. Date Picker Strip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '1. Select Booking Date',
                style: GoogleFonts.inter(
                  color: AppTheme.textPrimary,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                DateFormat('MMMM y').format(_selectedDate),
                style: GoogleFonts.inter(
                  color: AppTheme.neonGreen,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 78,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: 14,
              itemBuilder: (context, index) {
                final date = DateTime.now().add(Duration(days: index));
                final isSelected = date.year == _selectedDate.year &&
                    date.month == _selectedDate.month &&
                    date.day == _selectedDate.day;

                final dayName = DateFormat('E').format(date);
                final monthName = DateFormat('MMM').format(date);

                return GestureDetector(
                  onTap: () => setState(() => _selectedDate = date),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 62,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.neonGreen.withOpacity(0.18)
                          : AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected ? AppTheme.neonGreen : AppTheme.borderSubtle,
                        width: isSelected ? 1.8 : 1.0,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppTheme.neonGreen.withOpacity(0.25),
                                blurRadius: 10,
                              ),
                            ]
                          : [],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          dayName,
                          style: GoogleFonts.inter(
                            color: isSelected ? AppTheme.neonGreen : AppTheme.textMuted,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${date.day}',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 16.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          monthName,
                          style: GoogleFonts.inter(
                            color: isSelected ? AppTheme.neonGreenLight : AppTheme.textMuted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // 3. Start Time Slot Picker
          Text(
            '2. Choose Start Time Slot',
            style: GoogleFonts.inter(
              color: AppTheme.textPrimary,
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_availableStartTimes.length, (index) {
              final slot = _availableStartTimes[index];
              final isSelected = _selectedTimeSlotIndex == index;

              return ChoiceChip(
                label: Text(_formatTimeOfDay(slot)),
                selected: isSelected,
                onSelected: (_) => setState(() => _selectedTimeSlotIndex = index),
                backgroundColor: AppTheme.surfaceElevated,
                selectedColor: AppTheme.neonGreen.withOpacity(0.22),
                labelStyle: GoogleFonts.inter(
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: isSelected ? AppTheme.neonGreen : AppTheme.borderSubtle,
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 22),

          // 4. Duration Selector
          Text(
            '3. Match Duration',
            style: GoogleFonts.inter(
              color: AppTheme.textPrimary,
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: _durations.map((duration) {
              final isSelected = _selectedDurationHours == duration;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedDurationHours = duration),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.neonGreen.withOpacity(0.18)
                            : AppTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? AppTheme.neonGreen : AppTheme.borderSubtle,
                          width: isSelected ? 1.6 : 1.0,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${duration.toStringAsFixed(duration % 1 == 0 ? 0 : 1)}h',
                          style: GoogleFonts.inter(
                            color: isSelected ? Colors.white : AppTheme.textMuted,
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // 5. Reservation & Google Calendar Summary Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppTheme.cardGradient,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.borderSubtle, width: 1.2),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Reservation Summary',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.neonGreen.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '1 COURT RESERVED',
                        style: GoogleFonts.inter(
                          color: AppTheme.neonGreen,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildSummaryRow('Date', DateFormat('EEE, MMM d, y').format(_selectedDate)),
                const SizedBox(height: 8),
                _buildSummaryRow('Time Slot', '$startTimeStr - $endTimeStr'),
                const SizedBox(height: 8),
                _buildSummaryRow('Duration', '$_selectedDurationHours Hours'),
                const SizedBox(height: 8),
                _buildSummaryRow('Rate', '\$${_baseRate.toStringAsFixed(0)}/hr × $_selectedDurationHours = \$${_subtotal.toStringAsFixed(2)}'),
                const SizedBox(height: 8),
                _buildSummaryRow('VIP Booking Fee', 'FREE', valueColor: AppTheme.neonLime),
                const Divider(color: AppTheme.borderSubtle, height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Price',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '\$${_totalAmount.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(
                        color: AppTheme.neonLime,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 6. Direct Google Calendar Preview CTA Option
          GestureDetector(
            onTap: () {
              CalendarLinkService.openGoogleCalendar(
                title: 'Pickleball @ $courtName',
                startTime: _calculatedStartDateTime,
                endTime: _calculatedEndDateTime,
                location: 'SmashCourt Arena • $courtName',
                details: 'SmashCourt Court Reservation\nDate: ${_formatDateLong(_selectedDate)}\nSlot: $startTimeStr - $endTimeStr\nTotal: \$${_totalAmount.toStringAsFixed(2)}',
                context: context,
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.neonGreen.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.calendar_month_rounded, color: AppTheme.neonGreen, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Preview Google Calendar Deep Link Event',
                    style: GoogleFonts.inter(
                      color: AppTheme.neonGreenLight,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 7. Primary Neon CTA Submit Button
          NeonButton(
            text: 'Reserve Court & Sync Calendar • \$${_totalAmount.toStringAsFixed(2)}',
            isLoading: _isSubmitting,
            icon: Icons.flash_on_rounded,
            onPressed: _handleCreateBooking,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
