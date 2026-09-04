import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../data/mock_data.dart';
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
  double _selectedDurationHours = 1.0;
  int _selectedPlayerCount = 4;

  List<BookingModel> _bookedSlotsForCurrentDay = [];
  bool _isLoadingAvailability = false;

  // Operating time slots (8:00 AM to 10:00 PM from centralized data)
  static List<TimeOfDay> get _allStartTimes => MockData.operatingTimeSlots;

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
    int index = 0;
    return _allStartTimes.indexWhere((_) => !_isSlotBooked(index++));
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
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
  // VIEW 1: RESERVE COURT (HERO 3-SELECTION HUB + VENUE OVERVIEW)
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

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: QuickBookingCard(
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

    final bookings =
        _myReservationsFilterIndex == 0 ? _upcomingBookings : _pastBookings;

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
            color:
                isSelected ? colors.neonGreenAlpha20 : colors.surfaceElevated,
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
