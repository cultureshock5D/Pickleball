import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
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
  static const double _standardSlotDuration = 1.0; // 1.0 hour standard match slot

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

  TimeOfDay get _selectedTime => _allStartTimes[_selectedTimeSlotIndex];
  bool get _isSelectedSlotPeak => _currentCourt?.isPeakHour(_selectedTime.hour) ?? false;
  double get _currentRate => _isSelectedSlotPeak
      ? (_currentCourt?.peakHourlyRate ?? 180.0)
      : (_currentCourt?.hourlyRate ?? 120.0);
  double get _subtotal => _currentRate * _standardSlotDuration;
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
    final totalMinutes = (_standardSlotDuration * 60).round();
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
      Duration(minutes: (_standardSlotDuration * 60).round()),
    );

    final now = DateTime.now();
    if (slotEnd.isBefore(now)) {
      return true;
    }

    for (final b in _bookedSlotsForCurrentDay) {
      if (b.status.toLowerCase() == 'cancelled') continue;
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

  bool _isSlotBookedForCourt(CourtModel court, int slotIndex) {
    if (court.id == _currentCourt?.id) {
      return _isSlotBooked(slotIndex);
    }
    final time = _allStartTimes[slotIndex];
    final slotStart = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      time.hour,
      time.minute,
    );
    final slotEnd = slotStart.add(
      Duration(minutes: (_standardSlotDuration * 60).round()),
    );

    final now = DateTime.now();
    if (slotEnd.isBefore(now)) {
      return true;
    }

    final cached = _bookingService.getCachedAvailability(court.id, _selectedDate);
    if (cached != null) {
      for (final b in cached) {
        if (b.status.toLowerCase() == 'cancelled') continue;
        if (Validators.hasTimeOverlap(
          newStart: slotStart,
          newEnd: slotEnd,
          existingStart: b.startTime,
          existingEnd: b.endTime,
        )) {
          return true;
        }
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

  Future<void> _openTimePicker() async {
    final sel = await TimePlayerPickerModal.show(
      context,
      availableTimes: _allStartTimes,
      initialTimeSlotIndex: _selectedTimeSlotIndex,
      hourlyRate: _currentCourt?.hourlyRate ?? 120.0,
      peakHourlyRate: _currentCourt?.peakHourlyRate ?? 180.0,
      peakStartHour: _currentCourt?.peakStartHour ?? 17,
      peakEndHour: _currentCourt?.peakEndHour ?? 22,
      isSlotDisabled: (index) => _isSlotBooked(index),
    );

    if (sel != null) {
      setState(() {
        _selectedTimeSlotIndex = sel.timeSlotIndex;
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
          durationHours: _standardSlotDuration,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          QuickBookingCard(
            selectedVenue: _selectedVenue,
            selectedDate: _selectedDate,
            selectedTime: selectedTime,
            durationHours: _standardSlotDuration,
            totalAmount: _totalAmount,
            onSelectVenue: _openVenuePicker,
            onSelectDate: _openDatePicker,
            onSelectTimeAndPlayers: _openTimePicker,
            onSearchOrBook: () {
              if (isSlotAvailable) {
                _navigateToReviewScreen();
              } else {
                _openTimePicker();
              }
            },
            actionButtonText: isSlotAvailable
                ? 'Reserve Court • ₱${_totalAmount.toStringAsFixed(0)}'
                : 'Choose Available Time Slot',
            isLoading: _isLoadingAvailability,
          ),
          const SizedBox(height: 18),

          // Horizontal Multi-Court Visual Timeline (Playtomic benchmark)
          _buildMultiCourtVisualTimeline(colors),
          const SizedBox(height: 18),

          // Court specification & rate cards (Peak vs Off-Peak distinction)
          _buildCourtSelectionCards(colors),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildMultiCourtVisualTimeline(AppPalette colors) {
    final displayCourts = _courts.isNotEmpty ? _courts : <CourtModel>[];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.borderSubtle),
        boxShadow: colors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Title and Live Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: colors.neonLime,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: colors.neonLimeAlpha35,
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Multi-Court Visual Timeline',
                    style: GoogleFonts.plusJakartaSans(
                      color: colors.textPrimary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: colors.neonGreenAlpha15,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'LIVE LANES',
                  style: GoogleFonts.plusJakartaSans(
                    color: colors.neonGreen,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Timeline Heat Legend
          Row(
            children: [
              _buildLegendPip(colors.neonGreen, 'Off-Peak (₱120)'),
              const SizedBox(width: 12),
              _buildLegendPip(colors.neonYellow, 'Peak 17-22h (₱180)'),
              const SizedBox(width: 12),
              _buildLegendPip(colors.textMuted, 'Booked'),
            ],
          ),
          const SizedBox(height: 14),

          // Court Lanes
          if (displayCourts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No courts available for selected venue.',
                style: GoogleFonts.inter(color: colors.textMuted, fontSize: 12),
              ),
            )
          else
            ...List.generate(displayCourts.length, (courtIndex) {
              final court = displayCourts[courtIndex];
              final isCourtSelected = courtIndex == _selectedCourtIndex;
              final courtLabel = 'Court ${courtIndex + 1}';

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Lane Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isCourtSelected
                                ? colors.neonGreenAlpha20
                                : colors.surfaceHighlight,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isCourtSelected
                                  ? colors.neonGreen
                                  : colors.borderSubtle,
                              width: isCourtSelected ? 1.2 : 0.8,
                            ),
                          ),
                          child: Text(
                            courtLabel,
                            style: GoogleFonts.plusJakartaSans(
                              color: isCourtSelected
                                  ? colors.neonGreen
                                  : colors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            court.name,
                            style: GoogleFonts.inter(
                              color: colors.textMuted,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '₱${court.hourlyRate.toStringAsFixed(0)} / ₱${court.peakHourlyRate.toStringAsFixed(0)}',
                          style: GoogleFonts.plusJakartaSans(
                            color: colors.neonLime,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Horizontal Lane Time Slots Strip
                    SizedBox(
                      height: 64,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _allStartTimes.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemBuilder: (context, slotIndex) {
                          final time = _allStartTimes[slotIndex];
                          final isBooked = _isSlotBookedForCourt(court, slotIndex);
                          final isPeak = court.isPeakHour(time.hour);
                          final isSlotActive = isCourtSelected && slotIndex == _selectedTimeSlotIndex;
                          final formattedHour = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                          final rate = isPeak ? court.peakHourlyRate : court.hourlyRate;

                          Color slotBorderColor = isPeak ? colors.neonYellowAlpha28 : colors.neonGreenAlpha14;
                          Color slotBgColor = isPeak ? colors.neonYellowAlpha14 : colors.neonGreenAlpha08;
                          if (isBooked) {
                            slotBorderColor = colors.borderSubtle;
                            slotBgColor = colors.surfaceHighlight;
                          } else if (isSlotActive) {
                            slotBorderColor = colors.neonLime;
                            slotBgColor = colors.neonLimeAlpha20;
                          }

                          return Semantics(
                            button: !isBooked,
                            label: '$courtLabel at $formattedHour, ${isBooked ? 'Booked' : (isPeak ? 'Peak ₱${rate.toStringAsFixed(0)}' : 'Off-Peak ₱${rate.toStringAsFixed(0)}')}',
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: isBooked
                                  ? null
                                  : () {
                                      HapticFeedback.selectionClick();
                                      setState(() {
                                        _selectedCourtIndex = courtIndex;
                                        _selectedTimeSlotIndex = slotIndex;
                                      });
                                      _loadCourtAvailability();
                                    },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: 68,
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                                decoration: BoxDecoration(
                                  color: slotBgColor,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: slotBorderColor,
                                    width: isSlotActive ? 1.8 : 1.0,
                                  ),
                                  boxShadow: isSlotActive
                                      ? [
                                          BoxShadow(
                                            color: colors.neonLimeAlpha35,
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        formattedHour,
                                        style: GoogleFonts.plusJakartaSans(
                                          color: isBooked
                                              ? colors.textMuted
                                              : (isSlotActive ? colors.neonLime : colors.textPrimary),
                                          fontSize: 11,
                                          fontWeight: isSlotActive ? FontWeight.w800 : FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Container(
                                        height: 2.5,
                                        width: 24,
                                        decoration: BoxDecoration(
                                          color: isBooked
                                              ? colors.borderSubtle
                                              : (isPeak ? colors.neonYellow : colors.neonGreen),
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isBooked ? 'BOOKED' : '₱${rate.toStringAsFixed(0)}',
                                        style: GoogleFonts.inter(
                                          color: isBooked
                                              ? colors.textMuted
                                              : (isPeak ? colors.neonYellow : colors.neonGreen),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
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
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildLegendPip(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            color: context.colors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildCourtSelectionCards(AppPalette colors) {
    if (_courts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Championship Courts',
              style: GoogleFonts.plusJakartaSans(
                color: colors.textPrimary,
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            Text(
              '${_courts.length} Available',
              style: GoogleFonts.inter(
                color: colors.textMuted,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...List.generate(_courts.length, (index) {
          final court = _courts[index];
          final isSelected = index == _selectedCourtIndex;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Semantics(
              button: true,
              selected: isSelected,
              label: '${court.name}, Off-Peak ₱${court.hourlyRate.toStringAsFixed(0)}, Peak ₱${court.peakHourlyRate.toStringAsFixed(0)}',
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedCourtIndex = index);
                  _loadCourtAvailability();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected ? colors.surfaceElevated : colors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? colors.neonGreen : colors.borderSubtle,
                      width: isSelected ? 1.8 : 1.0,
                    ),
                    boxShadow: isSelected ? colors.cardShadow : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: isSelected ? colors.neonGreenAlpha15 : colors.surfaceHighlight,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? colors.neonGreenAlpha40 : colors.borderSubtle,
                          ),
                        ),
                        child: Icon(
                          Icons.sports_tennis_rounded,
                          color: isSelected ? colors.neonGreen : colors.textSecondary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    court.name,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: colors.textPrimary,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isSelected)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: colors.neonGreenAlpha15,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'SELECTED',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: colors.neonGreen,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              court.surfaceType ?? 'Pro-Cushion Hardcourt',
                              style: GoogleFonts.inter(
                                color: colors.textMuted,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: colors.neonGreenAlpha10,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: colors.neonGreenAlpha22, width: 0.8),
                                  ),
                                  child: Text(
                                    'Off-Peak: ₱${court.hourlyRate.toStringAsFixed(0)}/hr',
                                    style: GoogleFonts.inter(
                                      color: colors.neonGreen,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: colors.neonYellowAlpha14,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: colors.neonYellowAlpha28, width: 0.8),
                                  ),
                                  child: Text(
                                    'Peak: ₱${court.peakHourlyRate.toStringAsFixed(0)}/hr',
                                    style: GoogleFonts.inter(
                                      color: colors.neonYellow,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
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
      child: Semantics(
        button: true,
        selected: isSelected,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _myReservationsFilterIndex = index);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
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
