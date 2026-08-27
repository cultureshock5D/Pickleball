import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../models/court_model.dart';
import '../../services/booking_service.dart';
import '../../widgets/neon_button.dart';
import 'booking_review_screen.dart';

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
  int _selectedCourtIndex = 0;
  late PageController _courtPageController;

  DateTime _selectedDate = DateTime.now();
  int _selectedTimeSlotIndex = 3; // Default 1:00 PM
  int _selectedTimeFilterIndex = 0; // 0: All, 1: Morning, 2: Afternoon, 3: Evening
  double _selectedDurationHours = 1.5;

  final List<TimeOfDay> _allStartTimes = [
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
    _courtPageController = PageController(viewportFraction: 0.90);
    _loadCourts();
  }

  @override
  void dispose() {
    _courtPageController.dispose();
    super.dispose();
  }

  Future<void> _loadCourts() async {
    setState(() => _isLoadingCourts = true);
    final courts = await _bookingService.fetchActiveCourts();
    if (mounted) {
      setState(() {
        _courts = courts;
        _isLoadingCourts = false;
      });
    }
  }

  CourtModel? get _currentCourt {
    if (_courts.isEmpty) return null;
    if (_selectedCourtIndex >= _courts.length) return _courts.first;
    return _courts[_selectedCourtIndex];
  }

  double get _baseRate => _currentCourt?.hourlyRate ?? 120.0;
  double get _subtotal => _baseRate * _selectedDurationHours;
  double get _serviceFee => 0.00;
  double get _totalAmount => _subtotal + _serviceFee;

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

  List<int> get _filteredTimeSlotIndices {
    if (_selectedTimeFilterIndex == 0) {
      return List.generate(_allStartTimes.length, (i) => i);
    } else if (_selectedTimeFilterIndex == 1) {
      // Morning (before 12:00 PM)
      return List.generate(_allStartTimes.length, (i) => i)
          .where((i) => _allStartTimes[i].hour < 12)
          .toList();
    } else if (_selectedTimeFilterIndex == 2) {
      // Afternoon (12:00 PM to 5:00 PM)
      return List.generate(_allStartTimes.length, (i) => i)
          .where((i) => _allStartTimes[i].hour >= 12 && _allStartTimes[i].hour < 17)
          .toList();
    } else {
      // Evening (5:00 PM onwards)
      return List.generate(_allStartTimes.length, (i) => i)
          .where((i) => _allStartTimes[i].hour >= 17)
          .toList();
    }
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
          onViewBookings: widget.onViewBookings,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoadingCourts) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.neonGreen),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Venue Badge & Live Status
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceElevated,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppTheme.borderSubtle),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppTheme.neonLime,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'SmashCourt Arena • Downtown',
                                  style: GoogleFonts.inter(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_courts.length} Courts Available',
                            style: GoogleFonts.inter(
                              color: AppTheme.neonGreen,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 1. Interactive Court Carousel
                    _buildCourtCarousel(),
                    const SizedBox(height: 22),

                    // 2. Horizontal Date Strip
                    _buildDateSelector(),
                    const SizedBox(height: 22),

                    // 3. Continuous Horizontal Time Roller
                    _buildTimeSlotRoller(),
                    const SizedBox(height: 22),

                    // 4. Session Duration Chips
                    _buildDurationSelector(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Persistent Floating Frosted-Glass Bottom Bar
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildCourtCarousel() {
    if (_courts.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 190,
          child: PageView.builder(
            controller: _courtPageController,
            itemCount: _courts.length,
            onPageChanged: (idx) {
              setState(() => _selectedCourtIndex = idx);
            },
            itemBuilder: (context, index) {
              final court = _courts[index];
              final isSelected = _selectedCourtIndex == index;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: isSelected ? AppTheme.cardGradient : null,
                  color: isSelected ? null : AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isSelected ? AppTheme.neonGreen.withOpacity(0.6) : AppTheme.borderSubtle,
                    width: isSelected ? 1.5 : 1,
                  ),
                  boxShadow: isSelected ? AppTheme.cardShadow : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.neonGreen.withOpacity(0.18)
                                : AppTheme.surfaceHighlight,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? AppTheme.neonGreen : AppTheme.borderSubtle,
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            Icons.sports_tennis_rounded,
                            color: isSelected ? AppTheme.neonGreen : AppTheme.textMuted,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                court.name,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                court.courtType ?? 'Championship Indoor',
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
                            color: AppTheme.neonLime.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.neonLime.withOpacity(0.35)),
                          ),
                          child: Text(
                            '\$${court.hourlyRate.toStringAsFixed(0)} / hr',
                            style: GoogleFonts.inter(
                              color: AppTheme.neonLime,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: AppTheme.borderSubtle, height: 1),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.layers_rounded, color: AppTheme.textMuted, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              court.surfaceType ?? 'Pro-Cushion Hardcourt',
                              style: GoogleFonts.inter(
                                color: AppTheme.textSecondary,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.neonGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'PRO SPECS',
                            style: GoogleFonts.inter(
                              color: AppTheme.neonGreenLight,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        // Carousel Page Indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_courts.length, (index) {
            final isSelected = _selectedCourtIndex == index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isSelected ? 22 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.neonGreen : AppTheme.surfaceHighlight,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildDateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Select Match Date',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                DateFormat('MMMM y').format(_selectedDate),
                style: GoogleFonts.inter(
                  color: AppTheme.textMuted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 82,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 14,
            itemBuilder: (context, index) {
              final date = DateTime.now().add(Duration(days: index));
              final isSelected = _selectedDate.year == date.year &&
                  _selectedDate.month == date.month &&
                  _selectedDate.day == date.day;
              final isToday = index == 0;

              return GestureDetector(
                onTap: () {
                  setState(() => _selectedDate = date);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 62,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.neonGreen.withOpacity(0.16) : AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected ? AppTheme.neonGreen : AppTheme.borderSubtle,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isToday ? 'TODAY' : DateFormat('E').format(date).toUpperCase(),
                        style: GoogleFonts.inter(
                          color: isSelected
                              ? AppTheme.neonGreen
                              : (isToday ? AppTheme.neonLime : AppTheme.textMuted),
                          fontSize: 10,
                          fontWeight: isToday || isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('d').format(date),
                        style: GoogleFonts.inter(
                          color: isSelected ? Colors.white : AppTheme.textSecondary,
                          fontSize: 18,
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

  Widget _buildTimeSlotRoller() {
    final filteredIndices = _filteredTimeSlotIndices;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Available Time Slots',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                _formatTimeOfDay(_allStartTimes[_selectedTimeSlotIndex]),
                style: GoogleFonts.inter(
                  color: AppTheme.neonLime,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Quick Period Jump Filter Tabs
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildTimeFilterChip(0, 'All Daytime Slots'),
              _buildTimeFilterChip(1, 'Morning (8AM - 12PM)'),
              _buildTimeFilterChip(2, 'Afternoon (12PM - 5PM)'),
              _buildTimeFilterChip(3, 'Evening (5PM - 10PM)'),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Continuous Horizontal Time Roller
        SizedBox(
          height: 86,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filteredIndices.length,
            itemBuilder: (context, idx) {
              final slotIndex = filteredIndices[idx];
              final time = _allStartTimes[slotIndex];
              final isSelected = _selectedTimeSlotIndex == slotIndex;
              final isPrimeTime = time.hour >= 17 && time.hour <= 20;

              return GestureDetector(
                onTap: () {
                  setState(() => _selectedTimeSlotIndex = slotIndex);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 106,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.neonGreen.withOpacity(0.18) : AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected ? AppTheme.neonGreen : AppTheme.borderSubtle,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _formatTimeOfDay(time),
                        style: GoogleFonts.inter(
                          color: isSelected ? Colors.white : AppTheme.textSecondary,
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isPrimeTime
                              ? AppTheme.neonLime.withOpacity(0.15)
                              : AppTheme.surfaceHighlight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isPrimeTime ? 'POPULAR' : 'AVAILABLE',
                          style: GoogleFonts.inter(
                            color: isPrimeTime ? AppTheme.neonLime : AppTheme.textMuted,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
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

  Widget _buildTimeFilterChip(int index, String label) {
    final isSelected = _selectedTimeFilterIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedTimeFilterIndex = index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.neonGreen.withOpacity(0.15) : AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.neonGreen : AppTheme.borderSubtle,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: isSelected ? AppTheme.neonGreenLight : AppTheme.textMuted,
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDurationSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Session Duration',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${_selectedDurationHours}h total match',
                style: GoogleFonts.inter(
                  color: AppTheme.neonGreen,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: _durations.map((duration) {
              final isSelected = _selectedDurationHours == duration;
              final subtotalForDuration = _baseRate * duration;

              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedDurationHours = duration),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.neonGreen.withOpacity(0.16) : AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(16),
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
                            fontSize: 13.5,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '\$${subtotalForDuration.toStringAsFixed(0)}',
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

  Widget _buildBottomBar() {
    final courtName = _currentCourt?.name ?? 'Court';
    final startTimeStr = _formatTimeOfDay(_allStartTimes[_selectedTimeSlotIndex]);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        border: const Border(top: BorderSide(color: AppTheme.borderSubtle)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
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
                  style: GoogleFonts.inter(
                    color: AppTheme.textMuted,
                    fontSize: 11.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '\$${_totalAmount.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(
                        color: AppTheme.neonLime,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '(${_selectedDurationHours}h session)',
                      style: GoogleFonts.inter(
                        color: AppTheme.textMuted,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: NeonButton(
              text: 'Review & Book',
              icon: Icons.arrow_forward_rounded,
              onPressed: _navigateToReviewScreen,
            ),
          ),
        ],
      ),
    );
  }
}
