import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../models/booking_model.dart';
import '../../services/booking_service.dart';

class InsightsScreen extends StatefulWidget {
  final VoidCallback? onBookCourtPressed;

  const InsightsScreen({super.key, this.onBookCourtPressed});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

typedef AnalyticsScreen = InsightsScreen;

class _InsightsScreenState extends State<InsightsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final BookingService _bookingService = BookingService.instance;

  static final DateFormat _timeFormat = DateFormat('h:mm a');

  List<BookingModel> _bookings = [];
  bool _isLoading = true;
  int _selectedPeriodIndex = 1;
  static const List<String> _periods = ['This Week', 'This Month', 'All-Time'];

  double _totalPlaytimeHours = 0.0;
  int _totalBookingsCount = 0;
  double _totalSpend = 0.0;
  double _avgSessionHours = 0.0;
  Map<int, double> _weeklyHoursMap = {
    1: 0.0,
    2: 0.0,
    3: 0.0,
    4: 0.0,
    5: 0.0,
    6: 0.0,
    7: 0.0,
  };
  String _preferredCourtName = 'Center Championship Court';
  String _preferredCourtSubtitle = 'Reserve your first court to view venue insights';
  String _peakSlotName = 'Flexible';
  String _peakSlotTime = 'Flexible';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final bookings = await _bookingService.fetchCustomerBookings();
    if (mounted) {
      setState(() {
        _bookings = bookings;
        _recalculateMetrics();
        _isLoading = false;
      });
    }
  }

  void _onPeriodChanged(int index) {
    setState(() {
      _selectedPeriodIndex = index;
      _recalculateMetrics();
    });
  }

  List<BookingModel> get _filteredBookings {
    if (_bookings.isEmpty) return [];
    final now = DateTime.now();

    if (_selectedPeriodIndex == 0) {
      final sevenDaysAgo = now.subtract(const Duration(days: 7));
      return _bookings.where((b) => b.startTime.isAfter(sevenDaysAgo)).toList();
    } else if (_selectedPeriodIndex == 1) {
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      return _bookings.where((b) => b.startTime.isAfter(thirtyDaysAgo)).toList();
    }
    return _bookings;
  }

  void _recalculateMetrics() {
    final filtered = _filteredBookings;
    if (filtered.isEmpty) {
      _totalPlaytimeHours = 0.0;
      _totalBookingsCount = 0;
      _totalSpend = 0.0;
      _avgSessionHours = 0.0;
      _weeklyHoursMap = {1: 0.0, 2: 0.0, 3: 0.0, 4: 0.0, 5: 0.0, 6: 0.0, 7: 0.0};
      _preferredCourtName = 'No Court History';
      _preferredCourtSubtitle = 'Reserve your first court to view venue insights';
      _peakSlotName = 'No Peak Data';
      _peakSlotTime = 'Flexible';
      return;
    }

    double totalMinutes = 0;
    double spend = 0.0;
    final map = {1: 0.0, 2: 0.0, 3: 0.0, 4: 0.0, 5: 0.0, 6: 0.0, 7: 0.0};
    final courtCounts = <String, int>{};

    for (final b in filtered) {
      final durationMin = b.endTime.difference(b.startTime).inMinutes;
      totalMinutes += durationMin;
      spend += b.totalAmount;

      final weekday = b.startTime.weekday;
      map[weekday] = (map[weekday] ?? 0.0) + (durationMin / 60.0);

      final court = b.courtName ?? 'Center Championship Court';
      courtCounts[court] = (courtCounts[court] ?? 0) + 1;
    }

    _totalPlaytimeHours = totalMinutes / 60.0;
    _totalBookingsCount = filtered.length;
    _totalSpend = spend;
    _avgSessionHours = _totalPlaytimeHours / _totalBookingsCount;
    _weeklyHoursMap = map;

    String topCourt = filtered.first.courtName ?? 'Center Championship Court';
    int maxCount = 0;
    courtCounts.forEach((court, count) {
      if (count > maxCount) {
        maxCount = count;
        topCourt = court;
      }
    });
    _preferredCourtName = topCourt;
    final percentage = ((maxCount / filtered.length) * 100).toStringAsFixed(0);
    _preferredCourtSubtitle = '$percentage% of Playtime ($maxCount Sessions)';

    final firstHour = filtered.first.startTime.hour;
    if (firstHour < 12) {
      _peakSlotName = 'Morning Sessions';
    } else if (firstHour < 17) {
      _peakSlotName = 'Afternoon Sessions';
    } else {
      _peakSlotName = 'Evening Sessions';
    }
    _peakSlotTime =
        '${_timeFormat.format(filtered.first.startTime)} - ${_timeFormat.format(filtered.first.endTime)}';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colors = context.colors;

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(colors.neonGreen),
        ),
      );
    }

    final hasData = _bookings.isNotEmpty;
    final weeklyMap = _weeklyHoursMap;
    final maxDayHours =
        weeklyMap.values.fold<double>(0.0, (m, val) => val > m ? val : m);
    final chartMax = maxDayHours > 0 ? maxDayHours : 3.0;

    return RefreshIndicator(
      color: colors.neonGreen,
      backgroundColor: colors.surfaceElevated,
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Period Horizon Filter
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _periods.length,
                itemBuilder: (context, index) {
                  final isSelected = index == _selectedPeriodIndex;
                  return GestureDetector(
                    onTap: () => _onPeriodChanged(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colors.neonGreenAlpha18
                            : colors.surfaceElevated,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? colors.neonGreen
                              : colors.borderSubtle,
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _periods[index],
                          style: GoogleFonts.inter(
                            color: isSelected
                                ? colors.textPrimary
                                : colors.textMuted,
                            fontSize: 12.5,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // 2. Hero Playtime & Activity Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: colors.cardGradient,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: colors.borderSubtle),
                boxShadow: colors.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TOTAL COURT PLAYTIME',
                        style: GoogleFonts.inter(
                          color: colors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3.5,
                        ),
                        decoration: BoxDecoration(
                          color: colors.neonGreenAlpha15,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colors.neonGreenAlpha30),
                        ),
                        child: Text(
                          hasData ? 'ACTIVE PLAYER' : 'PRO READY',
                          style: GoogleFonts.inter(
                            color: colors.neonGreen,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        _totalPlaytimeHours.toStringAsFixed(1),
                        style: GoogleFonts.inter(
                          color: colors.textPrimary,
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'HOURS',
                        style: GoogleFonts.inter(
                          color: colors.textSecondary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      if (hasData)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: colors.neonLimeAlpha15,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.arrow_upward_rounded,
                                color: colors.neonLime,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'LIVE',
                                style: GoogleFonts.inter(
                                  color: colors.neonLime,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Hero Stat Counters
                  Row(
                    children: [
                      _buildHeroStatPill(
                        'Reservations',
                        '$_totalBookingsCount Bookings',
                        Icons.calendar_month_rounded,
                      ),
                      const SizedBox(width: 8),
                      _buildHeroStatPill(
                        'Total Spend',
                        '₱${_totalSpend.toStringAsFixed(0)}',
                        Icons.account_balance_wallet_outlined,
                      ),
                      const SizedBox(width: 8),
                      _buildHeroStatPill(
                        'Avg Session',
                        '${_avgSessionHours.toStringAsFixed(1)} hrs',
                        Icons.timer_outlined,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 3. Weekly Playtime Distribution Chart
            Text(
              'Weekly Playtime Activity',
              style: GoogleFonts.inter(
                color: colors.textPrimary,
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Hours per Day',
                        style: GoogleFonts.inter(
                          color: colors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        hasData ? 'Target: 8.0 hrs/wk' : 'Schedule your match',
                        style: GoogleFonts.inter(
                          color: colors.neonGreen,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildDayBar('Mon', weeklyMap[1] ?? 0.0, chartMax),
                      _buildDayBar('Tue', weeklyMap[2] ?? 0.0, chartMax),
                      _buildDayBar('Wed', weeklyMap[3] ?? 0.0, chartMax),
                      _buildDayBar('Thu', weeklyMap[4] ?? 0.0, chartMax),
                      _buildDayBar('Fri', weeklyMap[5] ?? 0.0, chartMax),
                      _buildDayBar(
                        'Sat',
                        weeklyMap[6] ?? 0.0,
                        chartMax,
                        isPeak: (weeklyMap[6] ?? 0) > 0,
                      ),
                      _buildDayBar('Sun', weeklyMap[7] ?? 0.0, chartMax),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 4. Booking Habits & Court Preferences
            Text(
              'Court & Venue Specifications',
              style: GoogleFonts.inter(
                color: colors.textPrimary,
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            _buildCourtDistributionTile(
              _preferredCourtName,
              hasData
                  ? 'Preferred Court • Pro-Cushion Surface'
                  : 'Championship Indoor • Pro-Cushion Hardcourt',
              _preferredCourtSubtitle,
              hasData ? 1.0 : 0.0,
              colors.neonGreen,
            ),
            const SizedBox(height: 18),

            // 5. Booking Behavior Grid
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    'Peak Play Slot',
                    _peakSlotTime,
                    _peakSlotName,
                    Icons.nights_stay_rounded,
                    colors.neonGreen,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricTile(
                    'Attendance Rate',
                    hasData ? '100%' : '0%',
                    hasData ? '0 Cancellations' : 'No Bookings Yet',
                    Icons.check_circle_outline_rounded,
                    colors.neonLime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroStatPill(String label, String value, IconData icon) {
    final colors = context.colors;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          color: colors.surfaceHighlight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.borderSubtle),
        ),
        child: Column(
          children: [
            Icon(icon, color: colors.neonGreen, size: 16),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.inter(
                color: colors.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: GoogleFonts.inter(
                color: colors.textMuted,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayBar(
    String day,
    double hours,
    double maxHours, {
    bool isPeak = false,
  }) {
    final colors = context.colors;
    final fillFraction = (hours / maxHours).clamp(0.08, 1.0);
    final hasHours = hours > 0;

    return Column(
      children: [
        Text(
          hasHours ? '${hours.toStringAsFixed(1)}h' : '-',
          style: GoogleFonts.inter(
            color: hasHours ? colors.textPrimary : colors.textMuted,
            fontSize: 10,
            fontWeight: hasHours ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 24,
          height: 80,
          decoration: BoxDecoration(
            color: colors.surfaceHighlight,
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.bottomCenter,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            height: 80 * fillFraction,
            decoration: BoxDecoration(
              gradient: isPeak
                  ? LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [colors.neonLime, colors.neonGreen],
                    )
                  : (hasHours
                      ? LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [colors.neonGreenLight, colors.neonGreenDark],
                        )
                      : null),
              color: hasHours ? null : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          day,
          style: GoogleFonts.inter(
            color: isPeak ? colors.neonGreen : colors.textMuted,
            fontSize: 11,
            fontWeight: isPeak ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildCourtDistributionTile(
    String title,
    String type,
    String subtitle,
    double progress,
    Color color,
  ) {
    final colors = context.colors;

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
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors.neonGreenAlpha15,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.sports_tennis_rounded,
                  color: colors.neonGreen,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        color: colors.textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      type,
                      style: GoogleFonts.inter(
                        color: colors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: colors.surfaceHighlight,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              color: colors.textSecondary,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(
    String title,
    String mainValue,
    String subValue,
    IconData icon,
    Color accentColor,
  ) {
    final colors = context.colors;

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
          Icon(icon, color: accentColor, size: 20),
          const SizedBox(height: 10),
          Text(
            mainValue,
            style: GoogleFonts.inter(
              color: colors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subValue,
            style: GoogleFonts.inter(
              color: colors.textMuted,
              fontSize: 11.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
