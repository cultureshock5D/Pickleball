import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/utils/validators.dart';
import '../../models/booking_model.dart';
import '../../models/court_model.dart';
import '../../services/booking_service.dart';
import '../../widgets/date_range_picker_modal.dart';
import '../../widgets/reservation_card.dart';
import '../../widgets/tap_collapse.dart';
import '../../widgets/time_player_picker_modal.dart';
import 'booking_review_screen.dart';

class CourtReservationScreen extends StatefulWidget {
  final int initialSubTab; // 0 = Reserve Court, 1 = My Reservations

  const CourtReservationScreen({
    super.key,
    this.initialSubTab = 0,
  });

  @override
  State<CourtReservationScreen> createState() => _CourtReservationScreenState();
}

class _CourtReservationScreenState extends State<CourtReservationScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final BookingService _bookingService = BookingService.instance;

  // View state: 0 = Reserve Court, 1 = My Reservations
  late int _activeModeIndex;

  // Reservations state
  List<BookingModel> _upcomingBookings = [];
  List<BookingModel> _pastBookings = [];
  bool _isLoadingBookings = true;
  int _myReservationsFilterIndex = 0; // 0 = Upcoming, 1 = Past

  // Courts state
  List<CourtModel> _courts = [];
  bool _isLoadingCourts = true;
  int _selectedCourtIndex = 0;

  // Booking details state
  DateTime _selectedDate = DateTime.now();
  Set<int> _selectedSlotIndices = {2}; // Default 8:00 AM (index 2: 0=6am, 1=7am, 2=8am)
  bool _paddleRental = false; // +₱150 flat
  bool _ballThrowerRental = false; // +₱150/hr

  List<BookingModel> _bookedSlotsForCurrentDay = [];
  bool _isLoadingAvailability = false;

  /// Operating time slots (6:00 AM to 10:00 PM, hours 6 to 21)
  static const List<TimeOfDay> _allStartTimes = [
    TimeOfDay(hour: 6, minute: 0),
    TimeOfDay(hour: 7, minute: 0),
    TimeOfDay(hour: 8, minute: 0),
    TimeOfDay(hour: 9, minute: 0),
    TimeOfDay(hour: 10, minute: 0),
    TimeOfDay(hour: 11, minute: 0),
    TimeOfDay(hour: 12, minute: 0),
    TimeOfDay(hour: 13, minute: 0),
    TimeOfDay(hour: 14, minute: 0),
    TimeOfDay(hour: 15, minute: 0),
    TimeOfDay(hour: 16, minute: 0),
    TimeOfDay(hour: 17, minute: 0),
    TimeOfDay(hour: 18, minute: 0),
    TimeOfDay(hour: 19, minute: 0),
    TimeOfDay(hour: 20, minute: 0),
    TimeOfDay(hour: 21, minute: 0),
  ];

  @override
  void initState() {
    super.initState();
    _activeModeIndex = widget.initialSubTab;
    _initializeData();
  }

  Future<void> _initializeData() async {
    await Future.wait([
      _loadCourts(),
      _loadCustomerBookings(),
    ]);
  }

  Future<void> _loadCourts() async {
    setState(() => _isLoadingCourts = true);
    final courts = await _bookingService.fetchActiveCourts();

    if (mounted) {
      setState(() {
        _courts = courts;
        _selectedCourtIndex = 0;
        _isLoadingCourts = false;
      });
      _loadCourtAvailability();
    }
  }

  Future<void> _loadCustomerBookings() async {
    setState(() => _isLoadingBookings = true);
    final bookings = await _bookingService.fetchCustomerBookings();
    final now = DateTime.now();

    final upcoming = bookings.where((b) {
      return b.endTime.isAfter(now) &&
          b.status != 'cancelled' &&
          b.status != 'expired';
    }).toList(growable: false);

    final past = bookings.where((b) {
      return b.endTime.isBefore(now) ||
          b.status == 'cancelled' ||
          b.status == 'expired';
    }).toList(growable: false);

    if (mounted) {
      setState(() {
        _upcomingBookings = upcoming;
        _pastBookings = past;
        _isLoadingBookings = false;
      });
    }
  }

  Future<void> _loadCourtAvailability() async {
    final court = _currentCourt;
    if (court == null) return;

    final cached =
        _bookingService.getCachedAvailability(court.id, _selectedDate);
    if (cached != null) {
      setState(() {
        _bookedSlotsForCurrentDay = cached;
        _autoAdjustSelectedSlot();
      });
    } else {
      setState(() => _isLoadingAvailability = true);
    }

    final booked = await _bookingService.fetchCourtBookingsForDate(
      court.id,
      _selectedDate,
    );

    if (mounted) {
      setState(() {
        _bookedSlotsForCurrentDay = booked;
        _isLoadingAvailability = false;
        _autoAdjustSelectedSlot();
      });
    }
  }

  void _autoAdjustSelectedSlot() {
    _selectedSlotIndices.removeWhere((idx) => _isSlotBooked(idx));
    if (_selectedSlotIndices.isEmpty) {
      final firstAvail = _findFirstAvailableSlotIndex();
      if (firstAvail != -1) {
        _selectedSlotIndices = {firstAvail};
      }
    }
  }

  CourtModel? get _currentCourt {
    if (_courts.isEmpty) return null;
    if (_selectedCourtIndex >= _courts.length) return _courts.first;
    return _courts[_selectedCourtIndex];
  }

  int get _selectedDurationHours => _selectedSlotIndices.length;

  int get _earliestSlotIndex {
    if (_selectedSlotIndices.isEmpty) return 0;
    return _selectedSlotIndices.reduce((a, b) => a < b ? a : b);
  }

  int get _latestSlotIndex {
    if (_selectedSlotIndices.isEmpty) return 0;
    return _selectedSlotIndices.reduce((a, b) => a > b ? a : b);
  }

  TimeOfDay get _selectedStartTime {
    if (_earliestSlotIndex >= _allStartTimes.length) {
      return _allStartTimes.first;
    }
    return _allStartTimes[_earliestSlotIndex];
  }

  TimeOfDay get _selectedEndTime {
    final latestStart = _allStartTimes[_latestSlotIndex.clamp(0, _allStartTimes.length - 1)];
    return TimeOfDay(hour: (latestStart.hour + 1).clamp(0, 23), minute: latestStart.minute);
  }

  double get _currentRate => _currentCourt?.hourlyRate ?? 300.0;

  double get _totalAmount {
    return BookingService.calculateTotalPrice(
      hourlyRate: _currentRate,
      durationHours: _selectedDurationHours,
      paddleRental: _paddleRental,
      ballThrowerRental: _ballThrowerRental,
    );
  }

  DateTime get _calculatedStartDateTime {
    final time = _selectedStartTime;
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      time.hour,
      time.minute,
    );
  }

  DateTime get _calculatedEndDateTime {
    final time = _selectedEndTime;
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      time.hour,
      time.minute,
    );
  }

  bool _isSlotBooked(int slotIndex) {
    if (slotIndex >= _allStartTimes.length) return true;
    final time = _allStartTimes[slotIndex];

    // Operating hours boundary: last slot cannot extend past 10:00 PM (hour 22)
    if (time.hour + 1 > 22) {
      return true;
    }

    final slotStart = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      time.hour,
      time.minute,
    );
    final slotEnd = slotStart.add(const Duration(hours: 1));

    final now = DateTime.now();
    final isToday = _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
    if (isToday && slotStart.isBefore(now)) {
      return true;
    }

    for (final b in _bookedSlotsForCurrentDay) {
      if (b.status == 'cancelled' || b.status == 'expired') continue;
      if (b.status == 'pending_payment' && b.isHoldExpired) continue;

      if (Validators.hasTimeOverlap(
        newStart: slotStart,
        newEnd: slotEnd,
        existingStart: b.startTime,
        existingEnd: b.endTime,
      )) {
        return true;
      }
    }
    return false;
  }

  int _findFirstAvailableSlotIndex() {
    for (int i = 0; i < _allStartTimes.length; i++) {
      if (!_isSlotBooked(i)) return i;
    }
    return -1;
  }

  Future<void> _openDatePicker() async {
    final selected = await DateRangePickerModal.show(
      context,
      initialDate: _selectedDate,
    );
    if (selected != null) {
      setState(() => _selectedDate = selected);
      _loadCourtAvailability();
    }
  }

  void _resetBooking() {
    HapticFeedback.mediumImpact();
    setState(() {
      _selectedDate = DateTime.now();
      _selectedCourtIndex = 0;
      _selectedSlotIndices = {2};
      _paddleRental = false;
      _ballThrowerRental = false;
    });
    _loadCourtAvailability();
    AppSnackBar.info(context, 'Booking selection reset.');
  }

  Future<void> _openTimePicker() async {
    final sel = await TimePlayerPickerModal.show(
      context,
      availableTimes: _allStartTimes,
      initialTimeSlotIndex: _earliestSlotIndex,
      initialDuration: _selectedDurationHours.toDouble(),
      hourlyRate: _currentRate,
      peakHourlyRate: _currentRate,
      isSlotDisabled: (index) => _isSlotBooked(index),
    );

    if (sel != null) {
      setState(() {
        _selectedSlotIndices = {
          for (int i = 0; i < sel.durationHours.round().clamp(1, 16); i++)
            (sel.timeSlotIndex + i).clamp(0, _allStartTimes.length - 1)
        };
      });
      _loadCourtAvailability();
    }
  }

  void _navigateToReviewScreen() {
    final court = _currentCourt;
    if (court == null || _selectedSlotIndices.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookingReviewScreen(
          court: court,
          startTime: _calculatedStartDateTime,
          endTime: _calculatedEndDateTime,
          durationHours: _selectedDurationHours.toDouble(),
          totalAmount: _totalAmount,
          paddleRental: _paddleRental,
          ballThrowerRental: _ballThrowerRental,
          onViewBookings: () {
            _loadCustomerBookings();
            _loadCourtAvailability();
            setState(() {
              _activeModeIndex = 1; // Switch to My Reservations view
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            // Top Mode Switcher (Reserve Court vs My Reservations)
            _buildTopModeSwitcher(),
            const SizedBox(height: 8),

            // Content Area
            Expanded(
              child: _activeModeIndex == 0
                  ? _buildReserveCourtContent()
                  : _buildMyReservationsContent(),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TOP COMPACT MODE SWITCHER
  // ==========================================
  Widget _buildTopModeSwitcher() {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 54,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.borderSubtle),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _buildModeTab(
                index: 0,
                label: 'Reserve Court',
                icon: Icons.sports_tennis_rounded,
                badgeText: '${_courts.length} Courts',
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _buildModeTab(
                index: 1,
                label: 'My Bookings',
                icon: Icons.calendar_month_rounded,
                badgeCount: _upcomingBookings.length,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeTab({
    required int index,
    required String label,
    required IconData icon,
    String? badgeText,
    int? badgeCount,
  }) {
    final colors = context.colors;
    final isSelected = _activeModeIndex == index;

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _activeModeIndex = index);
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          constraints: const BoxConstraints(minHeight: 48),
          decoration: BoxDecoration(
            color: isSelected ? colors.textPrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? colors.textPrimary : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: isSelected ? colors.background : colors.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: isSelected ? colors.background : colors.textMuted,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              if (badgeCount != null && badgeCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color:
                        isSelected ? colors.surfaceHighlight : colors.surfaceHighlight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: GoogleFonts.inter(
                      color: isSelected ? colors.textPrimary : colors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ] else if (badgeText != null && isSelected) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: colors.surfaceHighlight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badgeText,
                    style: GoogleFonts.inter(
                      color: colors.textPrimary,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // VIEW 1: RESERVE COURT
  // ==========================================
  Widget _buildReserveCourtContent() {
    final colors = context.colors;

    if (_isLoadingCourts && _courts.isEmpty) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(colors.textPrimary),
        ),
      );
    }

    final isSlotAvailable = _selectedSlotIndices.isNotEmpty &&
        _selectedSlotIndices.every((idx) => !_isSlotBooked(idx));

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Court Selector (Clean Side-by-Side Placement for Court 1, Court 2)
          _buildCourtPickerTabs(colors),
          const SizedBox(height: 16),

          // 2. Schedule Match Time with Interactive Multi-Slot Grid (Duration 1-4 removed)
          _buildScheduleAndMatchTimeCard(colors),
          const SizedBox(height: 16),

          // 3. Equipment Add-ons
          _buildAddonsCard(colors),
          const SizedBox(height: 20),

          // 4. Checkout CTA Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isSlotAvailable
                    ? colors.textPrimary
                    : colors.surfaceHighlight,
                foregroundColor: isSlotAvailable ? colors.background : colors.textMuted,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              onPressed: isSlotAvailable
                  ? _navigateToReviewScreen
                  : () => _openTimePicker(),
              child: Text(
                isSlotAvailable
                    ? 'Reserve Court • ₱${_totalAmount.toStringAsFixed(0)}'
                    : 'Choose Available Time Slot',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCourtPickerTabs(AppPalette colors) {
    if (_courts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.borderSubtle),
        ),
        child: Text(
          'No active courts found.',
          style: GoogleFonts.inter(color: colors.textMuted),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'SELECT COURT',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: colors.textMuted,
              ),
            ),
            Text(
              '${_courts.length} Pro Courts Available',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: _courts.asMap().entries.map((entry) {
            final index = entry.key;
            final court = entry.value;
            final isSel = _selectedCourtIndex == index;

            // Extract display names
            String displayName = court.name;
            String surfaceName = court.type.toUpperCase();
            if (court.name.contains('—')) {
              final parts = court.name.split('—');
              displayName = parts.first.trim();
              surfaceName = parts.last.replaceAll('(', '').replaceAll(')', '').trim();
            } else if (court.name.contains('-')) {
              final parts = court.name.split('-');
              displayName = parts.first.trim();
              surfaceName = parts.last.replaceAll('(', '').replaceAll(')', '').trim();
            }

            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: index < _courts.length - 1 ? 6 : 0,
                  left: index > 0 ? 6 : 0,
                ),
                child: TapCollapse(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedCourtIndex = index);
                    _loadCourtAvailability();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: isSel ? colors.surfaceElevated : colors.surfaceElevated,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSel ? colors.textPrimary : colors.borderSubtle,
                        width: isSel ? 2.0 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: isSel
                                    ? colors.textPrimary
                                    : colors.surfaceHighlight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                court.type.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: isSel ? colors.background : colors.textMuted,
                                ),
                              ),
                            ),
                            Text(
                              '₱${court.hourlyRate.toStringAsFixed(0)}/hr',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          displayName,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          surfaceName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildScheduleAndMatchTimeCard(AppPalette colors) {
    final dateFormat = DateFormat('EEE, MMM d, y');
    final timeFormat = DateFormat('h:mm a');
    final isSlotAvailable = _selectedSlotIndices.isNotEmpty &&
        _selectedSlotIndices.every((idx) => !_isSlotBooked(idx));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header with Court Subtext & Quick Modal Trigger
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'SCHEDULE MATCH TIME',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: colors.textMuted,
                    ),
                  ),
                  if (_isLoadingAvailability) ...[
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 11,
                      height: 11,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.8,
                        valueColor: AlwaysStoppedAnimation<Color>(colors.textPrimary),
                      ),
                    ),
                  ],
                ],
              ),
              InkWell(
                onTap: _resetBooking,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.restart_alt_rounded, size: 13, color: colors.textSecondary),
                      const SizedBox(width: 3),
                      Text(
                        'Reset Booking',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 2. Compact Date Selector Bar
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: colors.surfaceHighlight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.borderSubtle),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  height: 28,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      final prevDay = _selectedDate.subtract(const Duration(days: 1));
                      final today = DateTime.now();
                      if (prevDay.isAfter(today.subtract(const Duration(days: 1)))) {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedDate = prevDay);
                        _loadCourtAvailability();
                      }
                    },
                    icon: Icon(Icons.chevron_left_rounded,
                        size: 18, color: colors.textSecondary),
                    tooltip: 'Previous Day',
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: _openDatePicker,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              size: 13, color: colors.textPrimary),
                          const SizedBox(width: 6),
                          Text(
                            dateFormat.format(_selectedDate),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_drop_down_rounded,
                              size: 16, color: colors.textMuted),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedDate = _selectedDate.add(const Duration(days: 1));
                      });
                      _loadCourtAvailability();
                    },
                    icon: Icon(Icons.chevron_right_rounded,
                        size: 18, color: colors.textSecondary),
                    tooltip: 'Next Day',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 3. Perfectly Aligned Compact 4x4 Grid (16 Slots - Clickable multiple times)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _allStartTimes.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 5.0,
              crossAxisSpacing: 5.0,
              childAspectRatio: 2.35,
            ),
            itemBuilder: (context, idx) {
              final slotTime = _allStartTimes[idx];
              final isBooked = _isSlotBooked(idx);
              final isSel = _selectedSlotIndices.contains(idx);

              Color bg = colors.surfaceHighlight;
              Color border = colors.borderSubtle;
              Color textCol = colors.textPrimary;

              if (isBooked) {
                bg = colors.borderSubtleAlpha50;
                border = Colors.transparent;
                textCol = colors.textMuted;
              } else if (isSel) {
                bg = colors.textPrimary;
                border = colors.textPrimary;
                textCol = colors.background;
              }

              final slotDt = DateTime(2026, 1, 1, slotTime.hour, slotTime.minute);
              final formattedTime = timeFormat.format(slotDt);

              return Semantics(
                button: true,
                selected: isSel,
                enabled: !isBooked,
                label: '$formattedTime${isBooked ? ", Booked" : ""}',
                child: TapCollapse(
                  onTap: isBooked
                      ? null
                      : () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            if (_selectedSlotIndices.contains(idx)) {
                              if (_selectedSlotIndices.length > 1) {
                                _selectedSlotIndices.remove(idx);
                              }
                            } else {
                              _selectedSlotIndices.add(idx);
                            }
                          });
                        },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: border, width: isSel ? 1.4 : 1.0),
                    ),
                    child: Text(
                      formattedTime,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                        letterSpacing: -0.3,
                        color: textCol,
                        decoration: isBooked ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),

          // 4. Slim Selected Slots Summary Strip (Adds up total price dynamically)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: isSlotAvailable
                  ? colors.surfaceHighlight
                  : Colors.red.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSlotAvailable
                    ? colors.borderSubtle
                    : Colors.red.withAlpha(80),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isSlotAvailable
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      size: 14,
                      color: isSlotAvailable ? colors.textPrimary : Colors.redAccent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${timeFormat.format(_calculatedStartDateTime)} – ${timeFormat.format(_calculatedEndDateTime)} (${_selectedDurationHours}h)',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Text(
                  isSlotAvailable
                      ? '₱${(_currentRate * _selectedDurationHours).toStringAsFixed(0)}'
                      : 'UNAVAILABLE',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: isSlotAvailable ? colors.textPrimary : Colors.redAccent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddonsCard(AppPalette colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'EQUIPMENT RENTAL ADD-ONS',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: 6),

          // Rental Add-on Switches inside Material
          Material(
            color: Colors.transparent,
            child: Column(
              children: [
                // Paddle bundle switch
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: colors.textPrimary,
                  activeTrackColor: colors.textPrimary.withValues(alpha: 0.38),
                  title: Text(
                    'Pro Carbon Paddle Bundle (+₱150)',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Includes 2× Pro Paddles + 3× Match Pickleballs (flat fee)',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: colors.textMuted,
                    ),
                  ),
                  value: _paddleRental,
                  onChanged: (v) => setState(() => _paddleRental = v),
                ),

                // Ball thrower machine switch
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: colors.textPrimary,
                  activeTrackColor: colors.textPrimary.withValues(alpha: 0.38),
                  title: Text(
                    'Ball Thrower Machine (+₱150/hr)',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Automated training ball machine for the duration of match',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: colors.textMuted,
                    ),
                  ),
                  value: _ballThrowerRental,
                  onChanged: (v) => setState(() => _ballThrowerRental = v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // VIEW 2: MY BOOKINGS
  // ==========================================
  Widget _buildMyReservationsContent() {
    final colors = context.colors;

    if (_isLoadingBookings) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(colors.textPrimary),
        ),
      );
    }

    final bookings =
        _myReservationsFilterIndex == 0 ? _upcomingBookings : _pastBookings;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: _buildSubTab(
                  index: 0,
                  label: 'Upcoming (${_upcomingBookings.length})',
                  colors: colors,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSubTab(
                  index: 1,
                  label: 'Past / Cancelled (${_pastBookings.length})',
                  colors: colors,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: bookings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_month_outlined,
                          size: 48, color: colors.textMuted),
                      const SizedBox(height: 12),
                      Text(
                        _myReservationsFilterIndex == 0
                            ? 'No upcoming court reservations'
                            : 'No past booking records',
                        style: GoogleFonts.inter(
                          color: colors.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: bookings.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final b = bookings[index];
                    return ReservationCard(
                      booking: b,
                      isUpcoming: _myReservationsFilterIndex == 0,
                      onRefresh: _loadCustomerBookings,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSubTab({
    required int index,
    required String label,
    required AppPalette colors,
  }) {
    final isSelected = _myReservationsFilterIndex == index;
    return InkWell(
      onTap: () => setState(() => _myReservationsFilterIndex = index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? colors.textPrimary : colors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? colors.textPrimary : colors.borderSubtle,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? colors.background : colors.textMuted,
          ),
        ),
      ),
    );
  }
}
