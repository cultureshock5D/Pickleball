import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../models/booking_model.dart';
import '../../models/court_model.dart';
import '../../services/booking_service.dart';
import '../../widgets/neon_button.dart';
import '../../widgets/reservation_card.dart';
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

  // Memoized static date formatters (zero allocation per frame)
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

  // Booking form state
  List<CourtModel> _courts = [];
  bool _isLoadingCourts = true;
  int _selectedCourtIndex = 0;

  DateTime _selectedDate = DateTime.now();
  int _selectedTimeSlotIndex = 0;
  double _selectedDurationHours = 1.5;

  List<BookingModel> _bookedSlotsForCurrentDay = [];
  bool _isLoadingAvailability = false;

  // Comprehensive straight-to-the-point operating time slots (8:00 AM to 10:00 PM)
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

    // Instant synchronous cache check (<1ms zero spinner latency)
    final cached = _bookingService.getCachedAvailability(court.id, _selectedDate);
    if (cached != null) {
      setState(() {
        _bookedSlotsForCurrentDay = cached;
        _autoAdjustSelectedSlot();
      });
    } else {
      setState(() => _isLoadingAvailability = true);
    }

    final booked = await _bookingService.fetchCourtBookingsForDate(court.id, _selectedDate);

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
    final slotEnd = slotStart.add(Duration(minutes: (_selectedDurationHours * 60).round()));

    // Also check if the slot is in the past for today
    final now = DateTime.now();
    if (slotStart.isBefore(now)) {
      return true;
    }

    // Check overlap with existing active bookings for this court
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

  void _navigateToReviewScreen() {
    final court = _currentCourt;
    if (court == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookingReviewScreen(
          court: court,
          startTime: _calculatedStartDateTime,
          endTime: _calculatedEndDateTime,
          durationHours: _selectedDurationHours,
          totalAmount: _totalAmount,
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

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            // Top Compact Segmented Controller
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 46,
        padding: const EdgeInsets.all(3.5),
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderSubtle),
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildModeTab(
                index: 0,
                label: 'Reserve Court',
                icon: Icons.sports_tennis_rounded,
                badgeText: '${_courts.length} Available',
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
          color: isSelected ? AppTheme.neonGreenAlpha18 : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.neonGreenAlpha50 : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: isSelected ? AppTheme.neonGreen : AppTheme.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                color: isSelected ? Colors.white : AppTheme.textMuted,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (badgeCount != null && badgeCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.neonLime : AppTheme.surfaceHighlight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount',
                  style: GoogleFonts.inter(
                    color: isSelected ? Colors.black : Colors.white70,
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
                  color: AppTheme.neonLimeAlpha20,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badgeText,
                  style: GoogleFonts.inter(
                    color: AppTheme.neonLime,
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
  // VIEW 1: RESERVE COURT (OPTIMIZED)
  // ==========================================
  Widget _buildReserveCourtContent() {
    if (_isLoadingCourts) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.neonGreen),
        ),
      );
    }

    final isSlotAvailable = !_isSlotBooked(_selectedTimeSlotIndex);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCourtSelector(),
                const SizedBox(height: 12),
                _buildDateSelector(),
                const SizedBox(height: 12),
                _buildTimeSlotsGrid(),
                const SizedBox(height: 12),
                _buildDurationSelector(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        _buildBottomBar(isSlotAvailable),
      ],
    );
  }

  Widget _buildCourtSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('1. Select Court', style: AppTheme.fontSectionTitle),
              Text(
                '${_courts.length} Available',
                style: GoogleFonts.inter(
                  color: AppTheme.neonLime,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.symmetric(horizontal: 12),
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
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.neonGreenAlpha12
                        : AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected ? AppTheme.neonGreen : AppTheme.borderSubtle,
                      width: isSelected ? 1.5 : 1,
                    ),
                    boxShadow: isSelected ? AppTheme.cardShadow : null,
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
                                  ? AppTheme.neonGreenAlpha20
                                  : AppTheme.surfaceHighlight,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.sports_tennis_rounded,
                              color: isSelected ? AppTheme.neonGreen : AppTheme.textMuted,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              court.name,
                              style: AppTheme.fontCardTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              Icons.check_circle_rounded,
                              color: AppTheme.neonGreen,
                              size: 16,
                            ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            court.courtType ?? 'Indoor',
                            style: AppTheme.fontMuted,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.neonLimeAlpha15,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '₱${court.hourlyRate.toStringAsFixed(0)}/hr',
                              style: GoogleFonts.inter(
                                color: AppTheme.neonLime,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('2. Select Date', style: AppTheme.fontSectionTitle),
              Text(
                _monthYearFormat.format(_selectedDate),
                style: AppTheme.fontMuted,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 74,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.symmetric(horizontal: 12),
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
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.neonGreenAlpha18
                        : AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppTheme.neonGreen : AppTheme.borderSubtle,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isToday ? 'TODAY' : _dayOfWeekFormat.format(date).toUpperCase(),
                        style: GoogleFonts.inter(
                          color: isSelected
                              ? AppTheme.neonGreen
                              : (isToday ? AppTheme.neonLime : AppTheme.textMuted),
                          fontSize: 9.5,
                          fontWeight: isToday || isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _dayNumberFormat.format(date),
                        style: GoogleFonts.inter(
                          color: isSelected ? Colors.white : AppTheme.textSecondary,
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

  // =======================================================
  // STRAIGHT-TO-THE-POINT TIME SLOTS GRID
  // =======================================================
  Widget _buildTimeSlotsGrid() {
    final selectedTime = _allStartTimes[_selectedTimeSlotIndex];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text('3. Available Time Slots', style: AppTheme.fontSectionTitle),
                  if (_isLoadingAvailability) ...[
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.neonGreen),
                      ),
                    ),
                  ],
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.neonGreenAlpha12,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.neonGreenAlpha30),
                ),
                child: Text(
                  _formatTimeOfDay(selectedTime),
                  style: GoogleFonts.inter(
                    color: AppTheme.neonGreen,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Direct Responsive Grid - Ultra-compact 4-column pills
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
                          ? AppTheme.neonGreenAlpha20
                          : isBooked
                              ? AppTheme.surfaceElevated.withAlpha(80)
                              : AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.neonGreen
                            : isBooked
                                ? AppTheme.borderSubtleAlpha30
                                : AppTheme.borderSubtle,
                        width: isSelected ? 1.5 : 1,
                      ),
                      boxShadow: isSelected ? AppTheme.cardShadow : null,
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
                                  ? AppTheme.neonGreen
                                  : isBooked
                                      ? AppTheme.errorRed.withAlpha(180)
                                      : AppTheme.neonLime.withAlpha(160),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Text(
                            _formatTimeOfDay(time),
                            style: GoogleFonts.inter(
                              color: isSelected
                                  ? Colors.white
                                  : isBooked
                                      ? AppTheme.textMuted.withAlpha(120)
                                      : AppTheme.textPrimary,
                              fontSize: 11.5,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
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
      ),
    );
  }

  Widget _buildDurationSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('4. Session Duration', style: AppTheme.fontSectionTitle),
              Text(
                '${_selectedDurationHours}h match',
                style: GoogleFonts.inter(
                  color: AppTheme.neonLime,
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
              final subtotalForDuration = _baseRate * duration;

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedDurationHours = duration);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.neonGreenAlpha18
                          : AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? AppTheme.neonGreen : AppTheme.borderSubtle,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${duration.toString().replaceAll('.0', '')} hrs',
                          style: GoogleFonts.inter(
                            color: isSelected ? Colors.white : AppTheme.textSecondary,
                            fontSize: 12.5,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₱${subtotalForDuration.toStringAsFixed(0)}',
                          style: GoogleFonts.inter(
                            color: isSelected ? AppTheme.neonLime : AppTheme.textMuted,
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
      ),
    );
  }

  Widget _buildBottomBar(bool isSlotAvailable) {
    final courtName = _currentCourt?.name ?? 'Court';
    final startTimeStr = _formatTimeOfDay(_allStartTimes[_selectedTimeSlotIndex]);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceElevated,
        border: Border(top: BorderSide(color: AppTheme.borderSubtle)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$courtName • $startTimeStr',
                  style: AppTheme.fontMuted,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '₱${_totalAmount.toStringAsFixed(2)}',
                      style: AppTheme.fontPriceHero,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '(${_selectedDurationHours}h)',
                      style: AppTheme.fontMuted,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: NeonButton(
              text: isSlotAvailable ? 'Review & Book' : 'Slot Unavailable',
              icon: isSlotAvailable ? Icons.arrow_forward_rounded : Icons.block_rounded,
              onPressed: isSlotAvailable ? _navigateToReviewScreen : null,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // VIEW 2: MY RESERVATIONS (OPTIMIZED)
  // ==========================================
  Widget _buildMyReservationsContent() {
    if (_isLoadingBookings) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.neonGreen),
        ),
      );
    }

    final activeList = _myReservationsFilterIndex == 0 ? _upcomingBookings : _pastBookings;
    final isUpcoming = _myReservationsFilterIndex == 0;

    return RefreshIndicator(
      color: AppTheme.neonGreen,
      backgroundColor: AppTheme.surfaceElevated,
      onRefresh: _loadCustomerBookings,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Active Schedule Banner Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: AppTheme.cardGradient,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.borderSubtle),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.neonGreenAlpha15,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.neonGreenAlpha40),
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      color: AppTheme.neonGreen,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Court Schedule & Pass', style: AppTheme.fontSectionTitle),
                        const SizedBox(height: 2),
                        Text(
                          _upcomingBookings.isNotEmpty
                              ? '${_upcomingBookings.length} active reservation${_upcomingBookings.length > 1 ? 's' : ''} scheduled'
                              : 'No active reservations scheduled',
                          style: AppTheme.fontMuted,
                        ),
                      ],
                    ),
                  ),
                  if (_upcomingBookings.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: AppTheme.neonLimeAlpha14,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.neonLimeAlpha35),
                      ),
                      child: Text(
                        'ACTIVE',
                        style: GoogleFonts.inter(
                          color: AppTheme.neonLime,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Sub-filter tabs (Upcoming vs Past)
            Container(
              height: 42,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildSubTab(
                      index: 0,
                      label: 'Upcoming (${_upcomingBookings.length})',
                    ),
                  ),
                  Expanded(
                    child: _buildSubTab(
                      index: 1,
                      label: 'Past (${_pastBookings.length})',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Reservations List or Empty State
            if (activeList.isEmpty)
              _buildEmptyReservations(isUpcoming)
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: activeList.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final booking = activeList[index];
                  return ReservationCard(
                    booking: booking,
                    isUpcoming: isUpcoming,
                    onRefresh: () {
                      _loadCustomerBookings();
                      _loadCourtAvailability();
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubTab({required int index, required String label}) {
    final isSelected = _myReservationsFilterIndex == index;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _myReservationsFilterIndex = index);
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.neonGreenAlpha18 : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.neonGreenAlpha50 : Colors.transparent,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: isSelected ? Colors.white : AppTheme.textMuted,
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyReservations(bool isUpcoming) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.surfaceHighlight,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Icon(
              isUpcoming ? Icons.calendar_today_outlined : Icons.history_rounded,
              color: isUpcoming ? AppTheme.neonGreen : AppTheme.textMuted,
              size: 26,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            isUpcoming ? 'No Upcoming Reservations' : 'No Past Reservations',
            style: AppTheme.fontSectionTitle,
          ),
          const SizedBox(height: 4),
          Text(
            isUpcoming
                ? 'Reserve a court from the "Reserve Court" tab above to get started.'
                : 'Completed reservations will appear in this history log.',
            textAlign: TextAlign.center,
            style: AppTheme.fontMuted,
          ),
          if (isUpcoming) ...[
            const SizedBox(height: 18),
            NeonButton(
              text: 'Book a Court Now',
              icon: Icons.sports_tennis_rounded,
              onPressed: () {
                setState(() => _activeModeIndex = 0);
              },
            ),
          ],
        ],
      ),
    );
  }
}
