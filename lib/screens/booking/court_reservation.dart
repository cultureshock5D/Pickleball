import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../models/booking_model.dart';
import '../../models/court_model.dart';
import '../../models/venue_model.dart';
import '../../services/booking_service.dart';
import '../../widgets/date_range_picker_modal.dart';
import '../../widgets/quick_booking_card.dart';
import '../../widgets/reservation_card.dart';
import '../../widgets/time_player_picker_modal.dart';
import '../../widgets/venue_picker_modal.dart';
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

  // Memoized static date formatters
  static final DateFormat _monthYearFormat = DateFormat('MMMM y');
  static final DateFormat _dayOfWeekFormat = DateFormat('E');
  static final DateFormat _dayNumberFormat = DateFormat('d');

  // View state: 0 = Reserve Court, 1 = My Reservations
  late int _activeModeIndex;

  // Reservations state
  List<BookingModel> _upcomingBookings = [];
  List<BookingModel> _pastBookings = [];
  bool _isLoadingBookings = true;
  int _myReservationsFilterIndex = 0; // 0 = Upcoming, 1 = Past

  // Venues & Courts state
  List<VenueModel> _venues = [];
  VenueModel? _selectedVenue;
  List<CourtModel> _courts = [];
  bool _isLoadingCourts = true;
  int _selectedCourtIndex = 0;

  // Booking details state
  DateTime _selectedDate = DateTime.now();
  int _selectedTimeSlotIndex = 2; // Default 10:00 AM
  double _selectedDurationHours = 1.5;
  int _selectedPlayerCount = 4;

  List<BookingModel> _bookedSlotsForCurrentDay = [];
  bool _isLoadingAvailability = false;

  // Operating time slots (8:00 AM to 10:00 PM)
  static const List<TimeOfDay> _allStartTimes = [
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
    TimeOfDay(hour: 22, minute: 0),
  ];

  static const List<double> _durations = [1.0, 1.5, 2.0, 3.0];
  static const List<int> _playerCounts = [2, 4, 6];

  @override
  void initState() {
    super.initState();
    _activeModeIndex = widget.initialSubTab;
    _initializeData();
  }

  Future<void> _initializeData() async {
    await Future.wait([
      _loadVenuesAndCourts(),
      _loadCustomerBookings(),
    ]);
  }

  Future<void> _loadVenuesAndCourts() async {
    setState(() => _isLoadingCourts = true);
    final venues = await _bookingService.fetchVenues();
    final defaultVenue = venues.isNotEmpty ? venues.first : null;

    final courts = await _bookingService.fetchActiveCourts(
      venueId: defaultVenue?.id,
    );

    if (mounted) {
      setState(() {
        _venues = venues;
        _selectedVenue = defaultVenue;
        _courts = courts;
        _selectedCourtIndex = 0;
        _isLoadingCourts = false;
      });
      _loadCourtAvailability();
    }
  }

  Future<void> _onVenueSelected(VenueModel venue) async {
    setState(() {
      _selectedVenue = venue;
      _isLoadingCourts = true;
    });

    final courts = await _bookingService.fetchActiveCourts(venueId: venue.id);

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
      return b.endTime.isAfter(now) && b.status.toLowerCase() != 'cancelled';
    }).toList(growable: false);

    final past = bookings.where((b) {
      return b.endTime.isBefore(now) ||
          b.status.toLowerCase() == 'completed' ||
          b.status.toLowerCase() == 'cancelled';
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

    final cached = _bookingService.getCachedAvailability(court.id, _selectedDate);
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
    if (_isSlotBooked(_selectedTimeSlotIndex)) {
      final firstAvail = _findFirstAvailableSlotIndex();
      if (firstAvail != -1) {
        _selectedTimeSlotIndex = firstAvail;
      }
    }
  }

  CourtModel? get _currentCourt {
    if (_courts.isEmpty) return null;
    if (_selectedCourtIndex >= _courts.length) return _courts.first;
    return _courts[_selectedCourtIndex];
  }

  double get _baseRate => _currentCourt?.hourlyRate ?? 120.0;
  double get _subtotal => _baseRate * _selectedDurationHours;
  double get _totalAmount => _subtotal;

  DateTime get _calculatedStartDateTime {
    final time = _allStartTimes[_selectedTimeSlotIndex];
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

  bool _isSlotBooked(int slotIndex) {
    final time = _allStartTimes[slotIndex];
    final slotStart = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      time.hour,
      time.minute,
    );
    final slotEnd = slotStart.add(
      Duration(minutes: (_selectedDurationHours * 60).round()),
    );

    final now = DateTime.now();
    if (slotStart.isBefore(now)) {
      return true;
    }

    for (final b in _bookedSlotsForCurrentDay) {
      if (b.status.toLowerCase() == 'cancelled') continue;
      if (slotStart.isBefore(b.endTime) && slotEnd.isAfter(b.startTime)) {
        return true;
      }
    }
    return false;
  }

  int _findFirstAvailableSlotIndex() {
    for (int i = 0; i < _allStartTimes.length; i++) {
      if (!_isSlotBooked(i)) {
        return i;
      }
    }
    return -1;
  }

  Future<void> _openVenuePicker() async {
    final selected = await VenuePickerModal.show(
      context,
      venues: _venues,
      selectedVenue: _selectedVenue,
    );
    if (selected != null) {
      _onVenueSelected(selected);
    }
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

  Future<void> _openTimePlayerPicker() async {
    final sel = await TimePlayerPickerModal.show(
      context,
      availableTimes: _allStartTimes,
      initialTimeSlotIndex: _selectedTimeSlotIndex,
      initialDuration: _selectedDurationHours,
      initialPlayerCount: _selectedPlayerCount,
      hourlyRate: _baseRate,
    );

    if (sel != null) {
      setState(() {
        _selectedTimeSlotIndex = sel.timeSlotIndex;
        _selectedDurationHours = sel.durationHours;
        _selectedPlayerCount = sel.playerCount;
      });
      _loadCourtAvailability();
    }
  }

  void _navigateToReviewScreen() {
    final court = _currentCourt;
    if (court == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookingReviewScreen(
          court: court,
          venueName: _selectedVenue?.name ?? 'Barcelona Smash Club',
          startTime: _calculatedStartDateTime,
          endTime: _calculatedEndDateTime,
          durationHours: _selectedDurationHours,
          totalAmount: _totalAmount,
          playerCount: _selectedPlayerCount,
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
        height: 46,
        padding: const EdgeInsets.all(3.5),
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.borderSubtle),
        ),
        child: Row(
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
                label: 'My Reservations',
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

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _activeModeIndex = index);
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isSelected ? colors.neonGreenAlpha18 : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? colors.neonGreenAlpha50 : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: isSelected ? colors.neonGreen : colors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                color: isSelected ? colors.textPrimary : colors.textMuted,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (badgeCount != null && badgeCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected ? colors.neonLime : colors.surfaceHighlight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount',
                  style: GoogleFonts.inter(
                    color: isSelected ? Colors.black : colors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ] else if (badgeText != null && isSelected) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: colors.neonLimeAlpha20,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badgeText,
                  style: GoogleFonts.inter(
                    color: colors.neonLime,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================
  // VIEW 1: RESERVE COURT (IMAGE-INSPIRED HERO HUB + INLINE CONTROLS)
  // ==========================================
  Widget _buildReserveCourtContent() {
    final colors = context.colors;

    if (_isLoadingCourts && _venues.isEmpty) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(colors.neonGreen),
        ),
      );
    }

    final isSlotAvailable = !_isSlotBooked(_selectedTimeSlotIndex);
    final selectedTime = _allStartTimes[_selectedTimeSlotIndex];

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. HERO QUICK-BOOKING CARD (Based on user's reference image!)
                QuickBookingCard(
                  selectedVenue: _selectedVenue,
                  selectedDate: _selectedDate,
                  selectedTime: selectedTime,
                  durationHours: _selectedDurationHours,
                  playerCount: _selectedPlayerCount,
                  totalAmount: _totalAmount,
                  onSelectVenue: _openVenuePicker,
                  onSelectDate: _openDatePicker,
                  onSelectTimeAndPlayers: _openTimePlayerPicker,
                  onSearchOrBook: () {
                    if (isSlotAvailable) {
                      _navigateToReviewScreen();
                    } else {
                      _openTimePlayerPicker();
                    }
                  },
                  actionButtonText: isSlotAvailable
                      ? 'Reserve Court • ₱${_totalAmount.toStringAsFixed(0)}'
                      : 'Choose Available Time Slot',
                  isLoading: _isLoadingAvailability,
                ),
                const SizedBox(height: 20),

                // 2. VENUE & COURT SELECTOR CAROUSEL
                _buildVenueCourtSelector(),
                const SizedBox(height: 18),

                // 3. INTERACTIVE 14-DAY DATE STRIP
                _buildDateSelector(),
                const SizedBox(height: 18),

                // 4. LIVE AVAILABLE TIME SLOTS GRID
                _buildTimeSlotsGrid(),
                const SizedBox(height: 18),

                // 5. DURATION SELECTOR
                _buildDurationSelector(),
                const SizedBox(height: 18),

                // 6. PLAYERS / MATCH FORMAT SELECTOR
                _buildPlayerFormatSelector(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),

        // Sticky Bottom Checkout Bar
        _buildBottomBar(isSlotAvailable),
      ],
    );
  }

  Widget _buildVenueCourtSelector() {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.sports_tennis_rounded,
                  color: colors.neonGreen,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  '1. Select Court at ${_selectedVenue?.name ?? "Club"}',
                  style: GoogleFonts.inter(
                    color: colors.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: _openVenuePicker,
              child: Text(
                'Change Club',
                style: GoogleFonts.inter(
                  color: colors.neonLime,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        SizedBox(
          height: 112,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _courts.length,
            itemBuilder: (context, index) {
              final court = _courts[index];
              final isSelected = _selectedCourtIndex == index;

              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedCourtIndex = index);
                  _loadCourtAvailability();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 220,
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colors.neonGreenAlpha12
                        : colors.surfaceElevated,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected ? colors.neonGreen : colors.borderSubtle,
                      width: isSelected ? 1.6 : 1,
                    ),
                    boxShadow: isSelected ? colors.cardShadow : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? colors.neonGreenAlpha20
                                  : colors.surfaceHighlight,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.sports_tennis_rounded,
                              color: isSelected
                                  ? colors.neonGreen
                                  : colors.textMuted,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              court.name,
                              style: GoogleFonts.inter(
                                color: colors.textPrimary,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle_rounded,
                              color: colors.neonGreen,
                              size: 16,
                            ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            court.courtType ?? 'Indoor',
                            style: GoogleFonts.inter(
                              color: colors.textMuted,
                              fontSize: 11.5,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.neonLimeAlpha15,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '₱${court.hourlyRate.toStringAsFixed(0)}/hr',
                              style: GoogleFonts.inter(
                                color: colors.neonLime,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDateSelector() {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  color: colors.neonGreen,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  '2. Select Match Date',
                  style: GoogleFonts.inter(
                    color: colors.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: _openDatePicker,
              child: Text(
                _monthYearFormat.format(_selectedDate),
                style: GoogleFonts.inter(
                  color: colors.neonLime,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 74,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: 14,
            itemBuilder: (context, index) {
              final date = DateTime.now().add(Duration(days: index));
              final isSelected = _selectedDate.year == date.year &&
                  _selectedDate.month == date.month &&
                  _selectedDate.day == date.day;
              final isToday = index == 0;

              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedDate = date);
                  _loadCourtAvailability();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 58,
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colors.neonGreenAlpha18
                        : colors.surfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? colors.neonGreen : colors.borderSubtle,
                      width: isSelected ? 1.6 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isToday ? 'TODAY' : _dayOfWeekFormat.format(date).toUpperCase(),
                        style: GoogleFonts.inter(
                          color: isSelected
                              ? colors.neonGreen
                              : (isToday ? colors.neonLime : colors.textMuted),
                          fontSize: 9.5,
                          fontWeight: isToday || isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _dayNumberFormat.format(date),
                        style: GoogleFonts.inter(
                          color: isSelected
                              ? colors.textPrimary
                              : colors.textSecondary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSlotsGrid() {
    final colors = context.colors;
    final selectedTime = _allStartTimes[_selectedTimeSlotIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  color: colors.neonGreen,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  '3. Available Time Slots',
                  style: GoogleFonts.inter(
                    color: colors.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (_isLoadingAvailability) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      valueColor: AlwaysStoppedAnimation<Color>(colors.neonGreen),
                    ),
                  ),
                ],
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: colors.neonGreenAlpha12,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.neonGreenAlpha30),
              ),
              child: Text(
                _formatTimeOfDay(selectedTime),
                style: GoogleFonts.inter(
                  color: colors.neonGreen,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _allStartTimes.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 2.65,
          ),
          itemBuilder: (context, index) {
            final time = _allStartTimes[index];
            final isBooked = _isSlotBooked(index);
            final isSelected = _selectedTimeSlotIndex == index;

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isBooked
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        setState(() => _selectedTimeSlotIndex = index);
                      },
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colors.neonGreenAlpha20
                        : isBooked
                            ? colors.surfaceElevated.withAlpha(80)
                            : colors.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? colors.neonGreen
                          : isBooked
                              ? colors.borderSubtleAlpha30
                              : colors.borderSubtle,
                      width: isSelected ? 1.6 : 1,
                    ),
                    boxShadow: isSelected ? colors.cardShadow : null,
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          margin: const EdgeInsets.only(right: 5),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colors.neonGreen
                                : isBooked
                                    ? colors.errorRed.withAlpha(180)
                                    : colors.neonLime.withAlpha(160),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Text(
                          _formatTimeOfDay(time),
                          style: GoogleFonts.inter(
                            color: isSelected
                                ? colors.textPrimary
                                : isBooked
                                    ? colors.textMuted.withAlpha(120)
                                    : colors.textPrimary,
                            fontSize: 11.5,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w600,
                            decoration: isBooked ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDurationSelector() {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.timelapse_rounded,
                  color: colors.neonGreen,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  '4. Match Duration',
                  style: GoogleFonts.inter(
                    color: colors.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            Text(
              '${_selectedDurationHours}h match',
              style: GoogleFonts.inter(
                color: colors.neonLime,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: _durations.map((duration) {
            final isSelected = _selectedDurationHours == duration;

            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedDurationHours = duration);
                  _loadCourtAvailability();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colors.neonGreenAlpha18
                        : colors.surfaceElevated,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? colors.neonGreen : colors.borderSubtle,
                      width: isSelected ? 1.6 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${duration.toString().replaceAll('.0', '')} hrs',
                        style: GoogleFonts.inter(
                          color: isSelected
                              ? colors.textPrimary
                              : colors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₱${(_baseRate * duration).toStringAsFixed(0)}',
                        style: GoogleFonts.inter(
                          color: isSelected ? colors.neonLime : colors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPlayerFormatSelector() {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.group_outlined,
              color: colors.neonGreen,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              '5. Players & Match Format',
              style: GoogleFonts.inter(
                color: colors.textPrimary,
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: _playerCounts.map((count) {
            final isSelected = _selectedPlayerCount == count;
            final icon = count == 2
                ? Icons.person_outline_rounded
                : count == 4
                    ? Icons.people_outline_rounded
                    : Icons.groups_outlined;
            final label = count == 2
                ? 'Singles (2p)'
                : count == 4
                    ? 'Doubles (4p)'
                    : 'Group (6p)';

            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedPlayerCount = count);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colors.neonGreenAlpha18
                        : colors.surfaceElevated,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? colors.neonGreen : colors.borderSubtle,
                      width: isSelected ? 1.6 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        icon,
                        color: isSelected ? colors.neonGreen : colors.textMuted,
                        size: 18,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: GoogleFonts.inter(
                          color: isSelected
                              ? colors.textPrimary
                              : colors.textSecondary,
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ==========================================
  // STICKY BOTTOM CHECKOUT BAR
  // ==========================================
  Widget _buildBottomBar(bool isSlotAvailable) {
    final colors = context.colors;
    final isDark = context.isDark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111115) : Colors.white,
        border: Border(top: BorderSide(color: colors.borderSubtle, width: 1)),
        boxShadow: colors.cardShadow,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'TOTAL AMOUNT',
                  style: GoogleFonts.inter(
                    color: colors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '₱${_totalAmount.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                    color: colors.neonLime,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: isSlotAvailable ? _navigateToReviewScreen : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.neonGreen,
                  disabledBackgroundColor: colors.surfaceElevated,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: colors.textMuted,
                  elevation: isSlotAvailable ? 4 : 0,
                  shadowColor: colors.neonGreenAlpha45,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  isSlotAvailable ? 'Proceed to Confirmation' : 'Slot Unavailable',
                  style: GoogleFonts.inter(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // VIEW 2: MY RESERVATIONS CONTENT
  // ==========================================
  Widget _buildMyReservationsContent() {
    final colors = context.colors;

    if (_isLoadingBookings) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(colors.neonGreen),
        ),
      );
    }

    final bookings = _myReservationsFilterIndex == 0
        ? _upcomingBookings
        : _pastBookings;

    return Column(
      children: [
        // Sub-filter tabs (Upcoming vs Past)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              _buildSubFilterTab(0, 'Upcoming (${_upcomingBookings.length})'),
              const SizedBox(width: 8),
              _buildSubFilterTab(1, 'Past History (${_pastBookings.length})'),
            ],
          ),
        ),

        Expanded(
          child: bookings.isEmpty
              ? _buildEmptyBookingsView()
              : RefreshIndicator(
                  color: colors.neonGreen,
                  onRefresh: _loadCustomerBookings,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    itemCount: bookings.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return ReservationCard(
                        booking: bookings[index],
                        isUpcoming: _myReservationsFilterIndex == 0,
                        onRefresh: _loadCustomerBookings,
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSubFilterTab(int index, String label) {
    final colors = context.colors;
    final isSelected = _myReservationsFilterIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _myReservationsFilterIndex = index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected
                ? colors.neonGreenAlpha20
                : colors.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? colors.neonGreen : colors.borderSubtle,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: isSelected ? colors.textPrimary : colors.textMuted,
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyBookingsView() {
    final colors = context.colors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                shape: BoxShape.circle,
                border: Border.all(color: colors.borderSubtle),
              ),
              child: Icon(
                Icons.calendar_today_rounded,
                color: colors.textMuted,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _myReservationsFilterIndex == 0
                  ? 'No Upcoming Reservations'
                  : 'No Past Match History',
              style: GoogleFonts.inter(
                color: colors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _myReservationsFilterIndex == 0
                  ? 'Book your next luxury championship court session using the booking hub.'
                  : 'Your completed bookings will show up here for performance review.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: colors.textMuted,
                fontSize: 13,
              ),
            ),
            if (_myReservationsFilterIndex == 0) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => setState(() => _activeModeIndex = 0),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.neonGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                child: const Text('Reserve a Court Now'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
