import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../models/booking_model.dart';
import '../../services/booking_service.dart';
import '../../widgets/neon_button.dart';
import '../../widgets/reservation_card.dart';

class MyBookingsScreen extends StatefulWidget {
  final VoidCallback? onBookCourtPressed;

  const MyBookingsScreen({super.key, this.onBookCourtPressed});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final BookingService _bookingService = BookingService.instance;
  late TabController _tabController;

  List<BookingModel> _upcomingBookings = [];
  List<BookingModel> _pastBookings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadBookings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBookings() async {
    setState(() => _isLoading = true);
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
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Status / Target Banner Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                      decoration: BoxDecoration(
                        gradient: AppTheme.cardGradient,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: AppTheme.borderSubtle),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppTheme.neonGreen.withOpacity(0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.neonGreen.withOpacity(0.4),
                              ),
                            ),
                            child: const Icon(
                              Icons.calendar_month_rounded,
                              color: AppTheme.neonGreen,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Court Schedule & Pass',
                                  style: GoogleFonts.inter(
                                    color: AppTheme.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _upcomingBookings.isNotEmpty
                                      ? '${_upcomingBookings.length} active reservation${_upcomingBookings.length > 1 ? 's' : ''} scheduled'
                                      : 'No active reservations currently scheduled',
                                  style: GoogleFonts.inter(
                                    color: AppTheme.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_upcomingBookings.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.neonLime.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppTheme.neonLime.withOpacity(0.35)),
                              ),
                              child: Text(
                                'ACTIVE',
                                style: GoogleFonts.inter(
                                  color: AppTheme.neonLime,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 2. Custom Styled TabBar (Upcoming vs Past)
                    Container(
                      height: 48,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.borderSubtle),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicator: BoxDecoration(
                          color: AppTheme.neonGreen.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.neonGreen.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        labelColor: Colors.white,
                        unselectedLabelColor: AppTheme.textMuted,
                        labelStyle: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                        unselectedLabelStyle: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w400,
                        ),
                        dividerColor: Colors.transparent,
                        tabs: [
                          Tab(text: 'Upcoming (${_upcomingBookings.length})'),
                          Tab(text: 'Past & Completed (${_pastBookings.length})'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildBookingsList(_upcomingBookings, isUpcoming: true),
            _buildBookingsList(_pastBookings, isUpcoming: false),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingsList(List<BookingModel> bookings, {required bool isUpcoming}) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.neonGreen),
        ),
      );
    }

    if (bookings.isEmpty) {
      return RefreshIndicator(
        color: AppTheme.neonGreen,
        backgroundColor: AppTheme.surfaceElevated,
        onRefresh: _loadBookings,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceHighlight,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: Icon(
                    isUpcoming ? Icons.calendar_today_outlined : Icons.history_rounded,
                    color: isUpcoming ? AppTheme.neonGreen : AppTheme.textMuted,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  isUpcoming ? 'No Upcoming Reservations' : 'No Past Reservations',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isUpcoming
                      ? 'Reserve a court from the booking screen to see your scheduled sessions with calendar sync.'
                      : 'Completed matches and historic reservations will automatically appear here.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: AppTheme.textMuted,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                if (isUpcoming && widget.onBookCourtPressed != null) ...[
                  const SizedBox(height: 22),
                  NeonButton(
                    text: 'Book a Court Now',
                    icon: Icons.flash_on_rounded,
                    onPressed: widget.onBookCourtPressed,
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.neonGreen,
      backgroundColor: AppTheme.surfaceElevated,
      onRefresh: _loadBookings,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        itemCount: bookings.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final booking = bookings[index];
          return ReservationCard(
            booking: booking,
            isUpcoming: isUpcoming,
            onRefresh: _loadBookings,
          );
        },
      ),
    );
  }
}
