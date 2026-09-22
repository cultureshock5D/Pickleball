import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/pagination/pagination_controller.dart';
import '../../core/pagination/pagination_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/booking_repository.dart';
import '../../models/venue_model.dart';
import '../../widgets/brand_logo_painter.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/tap_collapse.dart';
import '../../core/utils/responsive_layout.dart';
import '../booking/event_place_booking_screen.dart';
import 'rates_and_spec_screen.dart';

class LandingHomeScreen extends StatefulWidget {
  final VoidCallback onBookCourtPressed;

  const LandingHomeScreen({
    super.key,
    required this.onBookCourtPressed,
  });

  @override
  State<LandingHomeScreen> createState() => _LandingHomeScreenState();
}

class _LandingHomeScreenState extends State<LandingHomeScreen> {
  int _expandedFaqIndex = -1;
  late final PaginationController<VenueModel> _venuesController;
  late final PageController _heroPageController;
  int _currentHeroPage = 0;
  Timer? _heroTimer;

  @override
  void initState() {
    super.initState();
    _heroPageController = PageController();
    _resetHeroTimer();
    _venuesController = PaginationController<VenueModel>(
      fetchPageChunk: (cursor, pageSize) =>
          BookingRepository.forFlavor().fetchPaginatedVenues(
        cursor: cursor,
        pageSize: pageSize,
      ),
      idExtractor: (v) => v.id,
    );
  }

  void _resetHeroTimer() {
    _heroTimer?.cancel();
    _heroTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_heroPageController.hasClients || _heroPageController.positions.length != 1) return;
      final nextPage = (_currentHeroPage + 1) % 4;
      _heroPageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _heroTimer?.cancel();
    _heroPageController.dispose();
    _venuesController.dispose();
    super.dispose();
  }

  void _goToPreviousHeroPage() {
    if (!_heroPageController.hasClients || _heroPageController.positions.length != 1) return;
    _resetHeroTimer();
    final prevPage = (_currentHeroPage - 1 + 4) % 4;
    _heroPageController.animateToPage(
      prevPage,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  void _goToNextHeroPage() {
    if (!_heroPageController.hasClients || _heroPageController.positions.length != 1) return;
    _resetHeroTimer();
    final nextPage = (_currentHeroPage + 1) % 4;
    _heroPageController.animateToPage(
      nextPage,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  final List<({String question, String answer})> _faqs = const [
    (
      question: "What is the 24-Hour Cancellation & Refund Policy?",
      answer:
          "All court bookings are 100% fully refundable if cancelled at least 24 hours prior to scheduled match start time. Cancellations inside 24 hours are non-refundable to maintain court scheduling integrity.",
    ),
    (
      question: "Are non-marking court shoes mandatory?",
      answer:
          "Yes. To protect our 8mm polyurethane cushioned acrylic surface, players must wear non-marking athletic court shoes. Street shoes, black-soled running shoes with carbon rubber, or sandals are strictly prohibited.",
    ),
    (
      question: "Can I book multiple consecutive hours?",
      answer:
          "Yes. You can reserve contiguous session blocks from 1 to 12 hours depending on court availability. Multi-hour sessions are ideal for doubles tournaments, training camps, or club social matches.",
    ),
    (
      question: "What equipment is provided with court reservations?",
      answer:
          "Court reservations include USAP official tournament nets, LED court lighting, and court-side benches. Paddles and balls can be rented or purchased via our Pro Shop add-ons during booking checkout.",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;

    return Scaffold(
      backgroundColor: colors.background,
      body: AdaptiveContainer(
        child: CustomScrollView(
          slivers: [
          // 1. Hero Action Banner (Auto-advancing 4-slide carousel every 5s)

          // 2. Hero Action Banner (Auto-advancing 4-slide carousel every 5s)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161616) : AppColors.ink,
                borderRadius: BorderRadius.zero,
                border: Border.all(color: colors.border),
              ),
              child: Stack(
                children: [
                  SizedBox(
                    height: 295,
                    child: PageView(
                      controller: _heroPageController,
                      onPageChanged: (index) {
                        setState(() {
                          _currentHeroPage = index;
                        });
                        _resetHeroTimer();
                      },
                      children: [
                        // Slide 1: Pickleball
                        _buildHeroSlide(
                          context: context,
                          tag: 'C&J CHAMPIONSHIP ARENA',
                          title: 'SERVE WITH FORCE.\nOWN THE COURT.',
                          subtitle:
                              'Two USA Pickleball 8mm Cushioned Courts • ₱300/hr Flat Rate with 24h Cancellation Guarantee.',
                          primaryButtonText: 'Book Court — ₱300/hr',
                          onPrimaryPressed: widget.onBookCourtPressed,
                          secondaryButtonText: 'Rates & Spec',
                          onSecondaryPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => RatesAndSpecScreen(
                                  onBookCourtPressed: widget.onBookCourtPressed,
                                ),
                              ),
                            );
                          },
                          watermark: const Positioned(
                            right: -30,
                            bottom: -30,
                            child: Opacity(
                              opacity: 0.08,
                              child: CustomPaint(
                                size: Size(220, 220),
                                painter: BrandLogoPainter(
                                  color: Colors.white,
                                  inverted: true,
                                ),
                              ),
                            ),
                          ),
                          colors: colors,
                          isDark: isDark,
                        ),
                        // Slide 2: Basketball
                        _buildHeroSlide(
                          context: context,
                          tag: 'INDOOR BASKETBALL ARENA',
                          title: 'DOMINATE THE PAINT.\nFULL COURT HOOPS.',
                          subtitle:
                              'FIBA Regulation Polyurethane Court • Pro Breakaway Rims, Glass Backboards & Digital Scoreboard.',
                          primaryButtonText: 'Book Hoops Court',
                          onPrimaryPressed: widget.onBookCourtPressed,
                          secondaryButtonText: 'Court Specs',
                          onSecondaryPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => RatesAndSpecScreen(
                                  onBookCourtPressed: widget.onBookCourtPressed,
                                ),
                              ),
                            );
                          },
                          watermark: const Positioned(
                            right: -20,
                            bottom: -20,
                            child: Opacity(
                              opacity: 0.07,
                              child: Icon(
                                Icons.sports_basketball_rounded,
                                size: 200,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          colors: colors,
                          isDark: isDark,
                        ),
                        // Slide 3: Events Place
                        _buildHeroSlide(
                          context: context,
                          tag: 'ARENA VENUES & PAVILIONS',
                          title: 'HOST EPIC MATCHES &\nPREMIER EVENTS.',
                          subtitle:
                              '500-sqm air-conditioned venue with 180 pax capacity, elevator access, lights & sound, and 15-car parking.',
                          primaryButtonText: 'Book Event — ₱30k / 4h',
                          onPrimaryPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const EventPlaceBookingScreen(),
                              ),
                            );
                          },
                          secondaryButtonText: 'Venue Specs',
                          onSecondaryPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const EventPlaceBookingScreen(),
                              ),
                            );
                          },
                          watermark: const Positioned(
                            right: -20,
                            bottom: -20,
                            child: Opacity(
                              opacity: 0.07,
                              child: Icon(
                                Icons.celebration_rounded,
                                size: 200,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          colors: colors,
                          isDark: isDark,
                        ),
                        // Slide 4: Cafe
                        _buildHeroSlide(
                          context: context,
                          tag: 'COURTSIDE RECOVERY & SOCIAL',
                          title: 'REFUEL & RECHARGE.\nPLAYER CAFE & LOUNGE.',
                          subtitle:
                              'Specialty espresso brews, cold electrolytes, protein recovery smoothies & match viewing lounge.',
                          primaryButtonText: 'Explore Cafe & Lounge',
                          onPrimaryPressed: () =>
                              _showCafeDetailsModal(context, colors, isDark),
                          secondaryButtonText: 'Open Daily 6AM–11PM',
                          onSecondaryPressed: () =>
                              _showCafeDetailsModal(context, colors, isDark),
                          watermark: const Positioned(
                            right: -20,
                            bottom: -20,
                            child: Opacity(
                              opacity: 0.07,
                              child: Icon(
                                Icons.local_cafe_rounded,
                                size: 200,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          colors: colors,
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                  // Left transparent button
                  Positioned(
                    left: 6,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Semantics(
                        button: true,
                        label: 'Previous slide',
                        child: TapCollapse(
                          onTap: _goToPreviousHeroPage,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withValues(alpha: 0.4),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.18),
                              ),
                            ),
                            child: const Icon(
                              Icons.chevron_left_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Right transparent button
                  Positioned(
                    right: 6,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Semantics(
                        button: true,
                        label: 'Next slide',
                        child: TapCollapse(
                          onTap: _goToNextHeroPage,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withValues(alpha: 0.4),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.18),
                              ),
                            ),
                            child: const Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    bottom: 10,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (index) {
                        final isActive = _currentHeroPage == index;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: isActive ? 22 : 6,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isActive
                                ? (isDark ? AppTheme.neonLime : Colors.white)
                                : Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),


          // 3.5. Popular Arenas & Club Venues (Paginated)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'POPULAR CLUBS',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: colors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'DISCOVER ARENAS',
                    style: TextStyle(
                      fontFamily: 'BebasNeue',
                      fontSize: 26,
                      letterSpacing: -0.3,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildVenuesSection(colors),
                ],
              ),
            ),
          ),


          // 7. FAQ Accordion Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FREQUENTLY ASKED QUESTIONS',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: colors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'POLICIES & VENUE GUIDELINES',
                    style: TextStyle(
                      fontFamily: 'BebasNeue',
                      fontSize: 26,
                      letterSpacing: -0.3,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(_faqs.length, (index) {
                    final faq = _faqs[index];
                    final isExpanded = _expandedFaqIndex == index;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        border: Border.all(color: colors.border),
                      ),
                      child: Column(
                        children: [
                          InkWell(
                            onTap: () {
                              setState(() {
                                _expandedFaqIndex = isExpanded ? -1 : index;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      faq.question,
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    isExpanded
                                        ? Icons.keyboard_arrow_up_rounded
                                        : Icons.keyboard_arrow_down_rounded,
                                    color: colors.textMuted,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (isExpanded)
                            Container(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              alignment: Alignment.centerLeft,
                              child: Text(
                                faq.answer,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12.5,
                                  color: colors.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildHeroSlide({
    required BuildContext context,
    required String tag,
    required String title,
    required String subtitle,
    required String primaryButtonText,
    required VoidCallback onPrimaryPressed,
    required String secondaryButtonText,
    required VoidCallback onSecondaryPressed,
    required Widget watermark,
    required AppPalette colors,
    required bool isDark,
  }) {
    return Stack(
      children: [
        watermark,
        Padding(
          padding: const EdgeInsets.fromLTRB(26, 20, 26, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.neonLime.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: isDark ? AppTheme.neonLime : Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: GoogleFonts.bebasNeue(
                  fontSize: 38,
                  letterSpacing: -0.5,
                  height: 0.94,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.5,
                  color: Color(0xFFCACACB),
                  height: 1.35,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: TapCollapse(
                      onTap: onPrimaryPressed,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.neonLime : Colors.white,
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          primaryButtonText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFF111111) : AppColors.ink,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TapCollapse(
                      onTap: onSecondaryPressed,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(9999),
                          border: Border.all(color: const Color(0xFF707072)),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          secondaryButtonText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showCafeDetailsModal(BuildContext context, AppPalette colors, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF141A16) : colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.neonLime.withValues(alpha: 0.15)
                            : colors.neonGreenAlpha15,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.local_cafe_rounded,
                        color: isDark ? AppTheme.neonLime : colors.textPrimary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'C&J COURTSIDE CAFE & LOUNGE',
                            style: GoogleFonts.bebasNeue(
                              fontSize: 22,
                              letterSpacing: -0.2,
                              color: colors.textPrimary,
                            ),
                          ),
                          Text(
                            'Open Daily: 6:00 AM – 11:00 PM • 2nd Floor Mezzanine',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              color: colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'MATCHDAY RECOVERY MENU',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: colors.textMuted,
                  ),
                ),
                const SizedBox(height: 10),
                _buildCafeMenuItem(
                  title: 'Cold-Pressed Match Electrolytes',
                  desc: 'Coconut water, lime, pink Himalayan salt',
                  price: '₱120',
                  colors: colors,
                ),
                const SizedBox(height: 8),
                _buildCafeMenuItem(
                  title: 'Whey Isolate Protein Recovery Shake',
                  desc: '30g protein, banana, peanut butter, oat milk',
                  price: '₱180',
                  colors: colors,
                ),
                const SizedBox(height: 8),
                _buildCafeMenuItem(
                  title: 'Single-Origin Artisan Cold Brew / Espresso',
                  desc: 'Locally roasted high-altitude Arabica beans',
                  price: '₱130',
                  colors: colors,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? AppTheme.neonLime : colors.textPrimary,
                      foregroundColor: isDark ? const Color(0xFF111111) : colors.background,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCafeMenuItem({
    required String title,
    required String desc,
    required String price,
    required AppPalette colors,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              Text(
                desc,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: colors.textMuted,
                ),
              ),
            ],
          ),
        ),
        Text(
          price,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.courtSuccess,
          ),
        ),
      ],
    );
  }


  Widget _buildVenuesSection(AppPalette colors) {
    return AnimatedBuilder(
      animation: _venuesController,
      builder: (context, _) {
        final state = _venuesController.state;
        if (state is PaginationInitialLoading<VenueModel>) {
          return const Column(
            children: [
              SkeletonVenueCard(margin: EdgeInsets.only(bottom: 10)),
              SkeletonVenueCard(margin: EdgeInsets.only(bottom: 10)),
            ],
          );
        }
        final venues = state.currentItems;
        if (venues.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          children: venues.map((venue) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: colors.surfaceElevated,
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.borderSubtle),
                        ),
                        child: Icon(Icons.location_on_rounded, color: colors.neonLime, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    venue.name,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: colors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                StatusBadge(
                                  label: venue.tag,
                                  variant: BadgeVariant.success,
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${venue.address}, ${venue.city}',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                color: colors.textMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: colors.surfaceElevated,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${venue.courtCount} Courts Available',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: colors.surfaceElevated,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, size: 12, color: Colors.amber),
                            const SizedBox(width: 2),
                            Text(
                              '${venue.rating} (${venue.reviewCount})',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'From ₱${venue.priceStartingAt.toStringAsFixed(0)}/hr',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      TapCollapse(
                        onTap: widget.onBookCourtPressed,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: colors.textPrimary,
                            borderRadius: BorderRadius.circular(9999),
                          ),
                          child: Text(
                            'Select Arena',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: colors.background,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
