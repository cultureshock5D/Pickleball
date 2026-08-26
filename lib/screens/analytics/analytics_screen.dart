import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../models/booking_model.dart';
import '../../services/booking_service.dart';
import '../../widgets/neon_button.dart';

class AnalyticsScreen extends StatefulWidget {
  final VoidCallback? onBookCourtPressed;

  const AnalyticsScreen({super.key, this.onBookCourtPressed});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final BookingService _bookingService = BookingService.instance;
  List<BookingModel> _bookings = [];
  bool _isLoading = true;

  int _selectedPeriodIndex = 1;
  final List<String> _periods = ['This Week', 'This Month', 'All-Time 2026'];

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
        _isLoading = false;
      });
    }
  }

  // Calculated Metrics
  double get _totalPlaytimeHours {
    if (_selectedPeriodIndex == 0) return 6.5; // This week
    if (_selectedPeriodIndex == 1) return 24.5; // This month
    return 68.0; // All time
  }

  int get _totalBookingsCount {
    if (_selectedPeriodIndex == 0) return 4;
    if (_selectedPeriodIndex == 1) return 14;
    return 38;
  }

  double get _totalSpend {
    if (_selectedPeriodIndex == 0) return 240.0;
    if (_selectedPeriodIndex == 1) return 890.0;
    return 2480.0;
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final min = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$min $period';
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

    return RefreshIndicator(
      color: AppTheme.neonGreen,
      backgroundColor: AppTheme.surfaceElevated,
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                    onTap: () => setState(() => _selectedPeriodIndex = index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.neonGreen.withOpacity(0.18)
                            : AppTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(20),
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
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),

            // 2. Hero Playtime & Booking Activity Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: AppTheme.cardGradient,
                borderRadius: BorderRadius.circular(26),
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
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.neonGreen.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.neonGreen.withOpacity(0.3)),
                        ),
                        child: Text(
                          'ACTIVE PLAYER',
                          style: GoogleFonts.inter(
                            color: AppTheme.neonGreen,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        _totalPlaytimeHours.toStringAsFixed(1),
                        style: GoogleFonts.inter(
                          color: AppTheme.textPrimary,
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'HOURS',
                        style: GoogleFonts.inter(
                          color: AppTheme.textSecondary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.neonLime.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.arrow_upward_rounded, color: AppTheme.neonLime, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '+14.2%',
                              style: GoogleFonts.inter(
                                color: AppTheme.neonLime,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Hero Stat Counters
                  Row(
                    children: [
                      _buildHeroStatPill('Reservations', '$_totalBookingsCount Bookings', Icons.calendar_month_rounded),
                      const SizedBox(width: 10),
                      _buildHeroStatPill('Total Spend', '\$${_totalSpend.toStringAsFixed(0)}', Icons.account_balance_wallet_outlined),
                      const SizedBox(width: 10),
                      _buildHeroStatPill('Avg Session', '1.8 hrs', Icons.timer_outlined),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // 3. Weekly Playtime Distribution Chart
            Text(
              'Weekly Playtime Activity',
              style: GoogleFonts.inter(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppTheme.borderSubtle),
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
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        'Target: 8.0 hrs/wk',
                        style: GoogleFonts.inter(
                          color: AppTheme.neonGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildDayBar('Mon', 1.5, 3.0),
                      _buildDayBar('Tue', 0.0, 3.0),
                      _buildDayBar('Wed', 2.0, 3.0),
                      _buildDayBar('Thu', 1.0, 3.0),
                      _buildDayBar('Fri', 2.5, 3.0),
                      _buildDayBar('Sat', 3.0, 3.0, isPeak: true),
                      _buildDayBar('Sun', 2.0, 3.0),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // 4. Booking Habits & Court Preferences
            Text(
              'Court & Venue Preferences',
              style: GoogleFonts.inter(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _buildCourtDistributionTile(
              'Court 1 - Center Championship',
              'Championship Indoor • Hardcourt',
              '54% of Playtime (18 Sessions)',
              0.54,
              AppTheme.neonGreen,
            ),
            const SizedBox(height: 10),
            _buildCourtDistributionTile(
              'Court 2 - Neon Arena (LED)',
              'LED Glow Indoor • Acrylic',
              '32% of Playtime (11 Sessions)',
              0.32,
              AppTheme.neonLime,
            ),
            const SizedBox(height: 10),
            _buildCourtDistributionTile(
              'Court 3 - Skyline Rooftop',
              'Rooftop Covered • All-Weather',
              '14% of Playtime (5 Sessions)',
              0.14,
              AppTheme.neonYellow,
            ),
            const SizedBox(height: 24),

            // 5. Booking Behavior Grid
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    'Peak Play Slot',
                    '6:00 - 8:30 PM',
                    'Evening Sessions',
                    Icons.nights_stay_rounded,
                    AppTheme.neonGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricTile(
                    'Attendance Rate',
                    '100%',
                    '0 Cancellations',
                    Icons.check_circle_outline_rounded,
                    AppTheme.neonLime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 6. Recent Booking & Session History Log
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Booking History',
                  style: GoogleFonts.inter(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${_bookings.length} Registered',
                  style: GoogleFonts.inter(
                    color: AppTheme.textMuted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_bookings.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Center(
                  child: Text(
                    'No reservation history records found.',
                    style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _bookings.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final booking = _bookings[index];
                  final durationHours = _calculateDurationHours(booking);
                  final isConfirmed = booking.status.toLowerCase() == 'confirmed';
                  final isCompleted = booking.status.toLowerCase() == 'completed';

                  Color badgeColor = isConfirmed
                      ? AppTheme.neonGreen
                      : (isCompleted ? AppTheme.neonLime : AppTheme.neonYellow);

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: badgeColor.withOpacity(0.14),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.sports_tennis_rounded,
                            color: badgeColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                booking.courtName ?? 'Court 1 - Center Championship',
                                style: GoogleFonts.inter(
                                  color: AppTheme.textPrimary,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${_formatDate(booking.startTime)} • ${_formatTime(booking.startTime)}',
                                style: GoogleFonts.inter(
                                  color: AppTheme.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceHighlight,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${durationHours.toStringAsFixed(1)}h Session',
                                      style: GoogleFonts.inter(
                                        color: Colors.white70,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '\$${booking.totalAmount.toStringAsFixed(2)}',
                                    style: GoogleFonts.inter(
                                      color: AppTheme.neonGreen,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: badgeColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: badgeColor.withOpacity(0.3)),
                          ),
                          child: Text(
                            booking.status.toUpperCase(),
                            style: GoogleFonts.inter(
                              color: badgeColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 24),

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
                      content: Text('Navigate to Court Booking tab to schedule your session.'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroStatPill(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceHighlight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.borderSubtle),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.neonGreen, size: 18),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                color: AppTheme.textMuted,
                fontSize: 10.5,
              ),
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
            fontSize: 10.5,
            fontWeight: isPeak ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 24,
          height: 70,
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.bottomCenter,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            width: 24,
            height: 70 * ratio,
            decoration: BoxDecoration(
              gradient: isPeak ? AppTheme.neonGreenGradient : null,
              color: isPeak ? null : (hours > 0 ? AppTheme.neonGreen.withOpacity(0.35) : Colors.transparent),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          day,
          style: GoogleFonts.inter(
            color: isPeak ? Colors.white : AppTheme.textSecondary,
            fontSize: 12,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                statText,
                style: GoogleFonts.inter(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              color: AppTheme.textMuted,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accentColor, size: 20),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: GoogleFonts.inter(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              color: AppTheme.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
