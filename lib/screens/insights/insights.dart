import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../models/booking_model.dart';
import '../../services/booking_service.dart';
import '../../widgets/booking_success_modal.dart';
import '../../widgets/neon_button.dart';

class InsightsScreen extends StatefulWidget {
  final VoidCallback? onBookCourtPressed;

  const InsightsScreen({super.key, this.onBookCourtPressed});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

// Backwards compatibility alias
typedef AnalyticsScreen = InsightsScreen;

class _InsightsScreenState extends State<InsightsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final BookingService _bookingService = BookingService.instance;

  // Memoized formatters (zero allocation per frame)
  static final DateFormat _dateFormat = DateFormat('d MMM y');
  static final DateFormat _timeFormat = DateFormat('h:mm a');

  List<BookingModel> _bookings = [];
  bool _isLoading = true;
  int _selectedPeriodIndex = 1;
  static const List<String> _periods = ['This Week', 'This Month', 'All-Time'];

  // Cached calculated metrics (computed once on data fetch / filter switch)
  double _totalPlaytimeHours = 0.0;
  int _totalBookingsCount = 0;
  double _totalSpend = 0.0;
  double _avgSessionHours = 0.0;
  Map<int, double> _weeklyHoursMap = {1: 0.0, 2: 0.0, 3: 0.0, 4: 0.0, 5: 0.0, 6: 0.0, 7: 0.0};
  String _preferredCourtName = 'Court 1 - Center Championship';
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
      // Last 7 days
      final sevenDaysAgo = now.subtract(const Duration(days: 7));
      return _bookings.where((b) => b.startTime.isAfter(sevenDaysAgo)).toList();
    } else if (_selectedPeriodIndex == 1) {
      // This Month (last 30 days)
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

      final court = b.courtName ?? 'Court 1 - Center Championship';
      courtCounts[court] = (courtCounts[court] ?? 0) + 1;
    }

    _totalPlaytimeHours = totalMinutes / 60.0;
    _totalBookingsCount = filtered.length;
    _totalSpend = spend;
    _avgSessionHours = _totalPlaytimeHours / _totalBookingsCount;
    _weeklyHoursMap = map;

    String topCourt = filtered.first.courtName ?? 'Court 1 - Center Championship';
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
    _peakSlotTime = '${_timeFormat.format(filtered.first.startTime)} - ${_timeFormat.format(filtered.first.endTime)}';
  }

  double _calculateDurationHours(BookingModel b) {
    final diffMinutes = b.endTime.difference(b.startTime).inMinutes;
    return (diffMinutes / 60.0).clamp(0.5, 8.0);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.neonGreen),
        ),
      );
    }

    final hasData = _bookings.isNotEmpty;
    final weeklyMap = _weeklyHoursMap;
    final maxDayHours = weeklyMap.values.fold<double>(0.0, (m, val) => val > m ? val : m);
    final chartMax = maxDayHours > 0 ? maxDayHours : 3.0;

    return RefreshIndicator(
      color: AppTheme.neonGreen,
      backgroundColor: AppTheme.surfaceElevated,
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.neonGreenAlpha18
                            : AppTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? AppTheme.neonGreen : AppTheme.borderSubtle,
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _periods[index],
                          style: GoogleFonts.inter(
                            color: isSelected ? Colors.white : AppTheme.textMuted,
                            fontSize: 12.5,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
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
                gradient: AppTheme.cardGradient,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppTheme.borderSubtle),
                boxShadow: AppTheme.cardShadow,
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
                          color: AppTheme.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: AppTheme.neonGreenAlpha15,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.neonGreenAlpha30),
                        ),
                        child: Text(
                          hasData ? 'ACTIVE PLAYER' : 'PRO READY',
                          style: GoogleFonts.inter(
                            color: AppTheme.neonGreen,
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
                          color: AppTheme.textPrimary,
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'HOURS',
                        style: GoogleFonts.inter(
                          color: AppTheme.textSecondary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      if (hasData)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: AppTheme.neonLimeAlpha15,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.arrow_upward_rounded, color: AppTheme.neonLime, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                'LIVE',
                                style: GoogleFonts.inter(
                                  color: AppTheme.neonLime,
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
                        '\$${_totalSpend.toStringAsFixed(0)}',
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
            Text('Weekly Playtime Activity', style: AppTheme.fontSectionTitle),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Hours per Day', style: AppTheme.fontBody),
                      Text(
                        hasData ? 'Target: 8.0 hrs/wk' : 'Schedule your match',
                        style: GoogleFonts.inter(
                          color: AppTheme.neonGreen,
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
                      _buildDayBar('Sat', weeklyMap[6] ?? 0.0, chartMax, isPeak: (weeklyMap[6] ?? 0) > 0),
                      _buildDayBar('Sun', weeklyMap[7] ?? 0.0, chartMax),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 4. Booking Habits & Court Preferences
            Text('Court & Venue Specifications', style: AppTheme.fontSectionTitle),
            const SizedBox(height: 10),
            _buildCourtDistributionTile(
              _preferredCourtName,
              hasData ? 'Preferred Court • Pro-Cushion Surface' : 'Championship Indoor • Pro-Cushion Hardcourt',
              _preferredCourtSubtitle,
              hasData ? 1.0 : 0.0,
              AppTheme.neonGreen,
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
                    AppTheme.neonGreen,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricTile(
                    'Attendance Rate',
                    hasData ? '100%' : '0%',
                    hasData ? '0 Cancellations' : 'No Bookings Yet',
                    Icons.check_circle_outline_rounded,
                    AppTheme.neonLime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 6. Recent Booking & Session History Log
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent Booking History', style: AppTheme.fontSectionTitle),
                Text(
                  '${_bookings.length} Registered',
                  style: AppTheme.fontMuted,
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_bookings.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.history_toggle_off_rounded,
                      color: AppTheme.textMuted,
                      size: 32,
                    ),
                    const SizedBox(height: 10),
                    Text('No reservation history records yet.', style: AppTheme.fontSectionTitle),
                    const SizedBox(height: 4),
                    Text(
                      'Once you reserve courts, live play history and Google Calendar sync actions will show here.',
                      textAlign: TextAlign.center,
                      style: AppTheme.fontMuted,
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _bookings.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final booking = _bookings[index];
                  final durationHours = _calculateDurationHours(booking);
                  final isConfirmed = booking.status.toLowerCase() == 'confirmed';
                  final isCompleted = booking.status.toLowerCase() == 'completed';

                  Color badgeColor = isConfirmed
                      ? AppTheme.neonGreen
                      : (isCompleted ? AppTheme.neonLime : AppTheme.neonYellow);

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        BookingSuccessModal.show(
                          context,
                          booking: booking,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceElevated,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppTheme.borderSubtle),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: badgeColor.withAlpha(35),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.sports_tennis_rounded,
                                color: badgeColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    booking.courtName ?? 'Court 1 - Center Championship',
                                    style: AppTheme.fontCardTitle,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_dateFormat.format(booking.startTime)} • ${_timeFormat.format(booking.startTime)}',
                                    style: AppTheme.fontMuted,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: AppTheme.surfaceHighlight,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '${durationHours.toStringAsFixed(1)}h Session',
                                          style: GoogleFonts.inter(
                                            color: Colors.white70,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '\$${booking.totalAmount.toStringAsFixed(2)}',
                                        style: GoogleFonts.inter(
                                          color: AppTheme.neonGreen,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: badgeColor.withAlpha(30),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: badgeColor.withAlpha(70)),
                                  ),
                                  child: Text(
                                    booking.status.toUpperCase(),
                                    style: GoogleFonts.inter(
                                      color: badgeColor,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppTheme.textMuted,
                                  size: 16,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 20),

            // 7. Quick Book Session CTA
            NeonButton(
              text: 'Reserve Next Court Session',
              icon: Icons.add_circle_outline_rounded,
              onPressed: () {
                if (widget.onBookCourtPressed != null) {
                  widget.onBookCourtPressed!();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Navigate to Court Reservation tab to schedule your session.'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroStatPill(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          color: AppTheme.surfaceHighlight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderSubtle),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.neonGreen, size: 16),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: AppTheme.fontMuted,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayBar(String day, double hours, double maxHours, {bool isPeak = false}) {
    final ratio = (hours / maxHours).clamp(0.05, 1.0);
    return Column(
      children: [
        Text(
          hours > 0 ? '${hours.toStringAsFixed(1)}h' : '-',
          style: GoogleFonts.inter(
            color: isPeak ? AppTheme.neonGreen : AppTheme.textMuted,
            fontSize: 10,
            fontWeight: isPeak ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 22,
          height: 65,
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.bottomCenter,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            width: 22,
            height: 65 * ratio,
            decoration: BoxDecoration(
              gradient: isPeak ? AppTheme.neonGreenGradient : null,
              color: isPeak ? null : (hours > 0 ? AppTheme.neonGreenAlpha30 : Colors.transparent),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          day,
          style: GoogleFonts.inter(
            color: isPeak ? Colors.white : AppTheme.textSecondary,
            fontSize: 11.5,
            fontWeight: isPeak ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildCourtDistributionTile(
    String title,
    String subtitle,
    String statText,
    double ratio,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: AppTheme.fontCardTitle),
              Text(
                statText,
                style: GoogleFonts.inter(
                  color: color,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(subtitle, style: AppTheme.fontMuted),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 5,
              backgroundColor: AppTheme.background,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color accentColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accentColor, size: 18),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(title, style: AppTheme.fontBody),
          const SizedBox(height: 1),
          Text(subtitle, style: AppTheme.fontMuted),
        ],
      ),
    );
  }
}
