import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/pagination/pagination_controller.dart';
import '../../core/pagination/pagination_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/booking_repository.dart';
import '../../models/venue_model.dart';
import '../../widgets/brand_logo_painter.dart';
import '../../widgets/court_visualizer.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/tap_collapse.dart';
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

  @override
  void initState() {
    super.initState();
    _venuesController = PaginationController<VenueModel>(
      fetchPageChunk: (cursor, pageSize) =>
          BookingRepository.forFlavor().fetchPaginatedVenues(
        cursor: cursor,
        pageSize: pageSize,
      ),
      idExtractor: (v) => v.id,
    );
  }

  @override
  void dispose() {
    _venuesController.dispose();
    super.dispose();
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
      body: CustomScrollView(
        slivers: [
          // 1. Utility Strip Top Bar
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(bottom: BorderSide(color: colors.border)),
              ),
              child: const Row(
                children: [
                  BrandLogoWidget(
                    size: 32,
                    showText: true,
                    withSubtitle: true,
                  ),
                ],
              ),
            ),
          ),

          // 2. Hero Action Banner
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
                  // Geometric Background Watermark Monogram
                  const Positioned(
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
                  Padding(
                    padding: const EdgeInsets.all(24),
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
                            'C&J CHAMPIONSHIP ARENA',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: isDark ? AppTheme.neonLime : Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'SERVE WITH FORCE.\nOWN THE COURT.',
                          style: GoogleFonts.bebasNeue(
                            fontSize: 44,
                            letterSpacing: -0.5,
                            height: 0.92,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Two USA Pickleball 8mm Cushioned Courts • ₱300/hr Flat Rate with 24h Cancellation Guarantee.',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: Color(0xFFCACACB),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: TapCollapse(
                                onTap: widget.onBookCourtPressed,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppTheme.neonLime : Colors.white,
                                    borderRadius: BorderRadius.circular(9999),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Book Court — ₱300/hr',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
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
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => RatesAndSpecScreen(
                                        onBookCourtPressed: widget.onBookCourtPressed,
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(9999),
                                    border: Border.all(color: const Color(0xFF707072)),
                                  ),
                                  alignment: Alignment.center,
                                  child: const Text(
                                    'Rates & Spec',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
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
              ),
            ),
          ),

          // 3. Featured Arena Catalog (Courts 1 & 2)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ARENA CATALOG',
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
                    'FEATURED TOURNAMENT COURTS',
                    style: TextStyle(
                      fontFamily: 'BebasNeue',
                      fontSize: 26,
                      letterSpacing: -0.3,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildCourtCard(
                          title: 'Court 1 — Pro Cushion',
                          subtitle: '8mm Shock-Absorbing Acrylic',
                          badge: 'HIGH DEMAND',
                          badgeVariant: BadgeVariant.dark,
                          rate: '₱300 / hour',
                          surfaceColor: AppColors.courtBlue,
                          colors: colors,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildCourtCard(
                          title: 'Court 2 — Tournament Spec',
                          subtitle: 'USAP Tension Net & Headband',
                          badge: 'POPULAR',
                          badgeVariant: BadgeVariant.success,
                          rate: '₱300 / hour',
                          surfaceColor: AppColors.courtNavy,
                          colors: colors,
                        ),
                      ),
                    ],
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

          // 4. Pro Shop & Equipment Rentals (4-Up Rail)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EQUIPMENT & GEAR',
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
                    'PRO SHOP ADD-ONS',
                    style: TextStyle(
                      fontFamily: 'BebasNeue',
                      fontSize: 26,
                      letterSpacing: -0.3,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildProShopCard(
                          name: 'C&J Pro 16mm Raw Carbon',
                          category: 'PADDLE RENTAL',
                          price: '₱150 / session',
                          icon: Icons.sports_tennis_rounded,
                          colors: colors,
                        ),
                        const SizedBox(width: 10),
                        _buildProShopCard(
                          name: 'Franklin X-40 Balls (3-Pack)',
                          category: 'BALL BUNDLE',
                          price: '₱150 flat',
                          icon: Icons.sports_baseball_outlined,
                          colors: colors,
                        ),
                        const SizedBox(width: 10),
                        _buildProShopCard(
                          name: 'Doubles Squad Bundle',
                          category: 'FULL SET (4 PADDLES)',
                          price: '₱300 flat',
                          icon: Icons.group_outlined,
                          colors: colors,
                        ),
                        const SizedBox(width: 10),
                        _buildProShopCard(
                          name: 'Microfiber Court Towel',
                          category: 'OFFICIAL ACCESSORY',
                          price: '₱250 flat',
                          icon: Icons.dry_cleaning_outlined,
                          colors: colors,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 5. Campaign Split Tile: "THE KITCHEN HAS RULES."
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF141A16) : AppColors.softCloud,
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.courtSuccess,
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: const Text(
                          'USAP STANDARDS',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'NON-VOLLEY ZONE DISCIPLINE',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'THE KITCHEN HAS RULES. PLAY BY THEM.',
                    style: GoogleFonts.bebasNeue(
                      fontSize: 30,
                      letterSpacing: -0.3,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'No volleying inside the 7-foot Non-Volley Zone. Master the dink, preserve momentum, and construct winning tournament points.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.5,
                      color: colors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 6. Technical USAP Court Blueprint Visualizer
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: CourtVisualizerWidget(courtName: 'C&J Courts 1 & 2'),
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
    );
  }

  Widget _buildCourtCard({
    required String title,
    required String subtitle,
    required String badge,
    required BadgeVariant badgeVariant,
    required String rate,
    required Color surfaceColor,
    required AppPalette colors,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: surfaceColor,
                  shape: BoxShape.circle,
                ),
              ),
              StatusBadge(label: badge, variant: badgeVariant),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            rate,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          TapCollapse(
            onTap: widget.onBookCourtPressed,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: colors.textPrimary,
                borderRadius: BorderRadius.circular(9999),
              ),
              alignment: Alignment.center,
              child: Text(
                'Book Now',
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
    );
  }

  Widget _buildProShopCard({
    required String name,
    required String category,
    required String price,
    required IconData icon,
    required AppPalette colors,
  }) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: colors.textPrimary),
          ),
          const SizedBox(height: 10),
          Text(
            category,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            price,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.courtSuccess,
            ),
          ),
        ],
      ),
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
