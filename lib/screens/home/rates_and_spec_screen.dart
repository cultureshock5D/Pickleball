import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

class RatesAndSpecScreen extends StatelessWidget {
  final VoidCallback? onBookCourtPressed;

  const RatesAndSpecScreen({
    super.key,
    this.onBookCourtPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: colors.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'RATES & SPECIFICATIONS',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: colors.textPrimary,
              ),
            ),
            Text(
              'C&J Championship Arena Hardware',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: colors.textMuted,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: colors.borderSubtle,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Hero Summary Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF141A16) : AppColors.softCloud,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.courtSuccess.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.courtSuccess.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(
                      Icons.verified_outlined,
                      color: AppColors.courtSuccess,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'USA PICKLEBALL CERTIFIED',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: AppColors.courtSuccess,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Pro Tournament Engineering',
                          style: GoogleFonts.bebasNeue(
                            fontSize: 22,
                            letterSpacing: -0.2,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Two championship courts designed for precision bounce and joint protection.',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: colors.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 2. Court Specifications Section
            _buildSectionHeader(colors, title: 'COURT HARDWARE & SPECS', badge: 'USAP RULEBOOK 2026'),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.borderSubtle),
              ),
              child: Column(
                children: [
                  _buildSpecRow(
                    colors,
                    icon: Icons.layers_outlined,
                    label: 'Playing Surface',
                    value: '8mm Polyurethane Cushion Acrylic',
                    subtext: 'Multi-layered shock absorption reducing knee & ankle impact.',
                  ),
                  _buildDivider(colors),
                  _buildSpecRow(
                    colors,
                    icon: Icons.straighten_rounded,
                    label: 'Court Dimensions',
                    value: '20 ft × 44 ft (Regulation)',
                    subtext: 'Official tournament boundaries with 7ft Non-Volley Zone (Kitchen).',
                  ),
                  _buildDivider(colors),
                  _buildSpecRow(
                    colors,
                    icon: Icons.horizontal_rule_rounded,
                    label: 'Net Rigging & Tension',
                    value: '36" Sidelines • 34" Center',
                    subtext: 'Heavy-duty steel posts with USAP tournament center strap.',
                  ),
                  _buildDivider(colors),
                  _buildSpecRow(
                    colors,
                    icon: Icons.wb_incandescent_outlined,
                    label: 'Court Lighting',
                    value: '750+ Lux Anti-Glare LED',
                    subtext: 'High-CRI overhead sports lighting with zero blind-spot coverage.',
                  ),
                  _buildDivider(colors),
                  _buildSpecRow(
                    colors,
                    icon: Icons.air_rounded,
                    label: 'Arena Climate',
                    value: 'Semi-Indoor Acoustic Airflow',
                    subtext: 'Protected wind barriers and high-ceiling cross ventilation.',
                    isLast: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 3. Hourly Rates & Pricing Breakdown
            _buildSectionHeader(colors, title: 'HOURLY COURT RATES', badge: 'FLAT PRICING'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.borderSubtle),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Standard & Peak Hours',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '6:00 AM – 10:00 PM Daily',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: colors.neonLimeAlpha15,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colors.neonLimeAlpha30),
                        ),
                        child: Text(
                          '₱300 / hr',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: colors.neonLime,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lock_clock_outlined, size: 18, color: colors.neonGreen),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Contiguous bookings available from 1 to 12 hours. Instant confirmation with calendar sync.',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: colors.textSecondary,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 4. Equipment Rental & Pro Shop Add-Ons
            _buildSectionHeader(colors, title: 'PRO SHOP & RENTAL ADD-ONS', badge: 'PER SESSION'),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.borderSubtle),
              ),
              child: Column(
                children: [
                  _buildRentalRow(
                    colors,
                    name: 'C&J Pro 16mm Raw Carbon Paddle',
                    category: 'Individual Paddle Rental',
                    price: '₱150 / session',
                    icon: Icons.sports_tennis_rounded,
                  ),
                  _buildDivider(colors),
                  _buildRentalRow(
                    colors,
                    name: 'Doubles Squad Full Set (4 Paddles)',
                    category: 'Squad Bundle (+ 3 Balls)',
                    price: '₱300 flat',
                    icon: Icons.group_outlined,
                  ),
                  _buildDivider(colors),
                  _buildRentalRow(
                    colors,
                    name: 'Franklin X-40 Tournament Balls',
                    category: '3-Pack Official Balls',
                    price: '₱150 flat',
                    icon: Icons.sports_baseball_outlined,
                  ),
                  _buildDivider(colors),
                  _buildRentalRow(
                    colors,
                    name: 'Microfiber Performance Court Towel',
                    category: 'Locker & Court Add-on',
                    price: '₱250 flat',
                    icon: Icons.dry_cleaning_outlined,
                  ),
                  _buildDivider(colors),
                  _buildRentalRow(
                    colors,
                    name: 'Automated Ball Launcher Machine',
                    category: 'Solo Training / Drill Session',
                    price: '₱150 / hr',
                    icon: Icons.sports_rounded,
                    isLast: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 5. Arena Guidelines & Policies
            _buildSectionHeader(colors, title: 'ARENA POLICIES & GUARANTEE', badge: '100% REFUNDABLE'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.borderSubtle),
              ),
              child: Column(
                children: [
                  _buildPolicyTile(
                    colors,
                    icon: Icons.history_rounded,
                    title: '24-Hour Free Cancellation',
                    description:
                        'Cancel 24+ hours in advance for a 100% instant refund to your GCash, Maya, or bank account.',
                  ),
                  const SizedBox(height: 12),
                  _buildPolicyTile(
                    colors,
                    icon: Icons.directions_walk_rounded,
                    title: 'Non-Marking Footwear Only',
                    description:
                        'To preserve the 8mm cushioned acrylic court, non-marking athletic court shoes are strictly required.',
                  ),
                  const SizedBox(height: 12),
                  _buildPolicyTile(
                    colors,
                    icon: Icons.qr_code_scanner_rounded,
                    title: 'Contactless QR Check-In',
                    description:
                        'Scan your dynamic digital kiosk QR ticket upon arrival at the clubhouse entry gate.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // 6. Primary CTA
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.neonLime,
                  foregroundColor: const Color(0xFF111111),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  onBookCourtPressed?.call();
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Book a Court • ₱300 / hr',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(AppPalette colors, {required String title, required String badge}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
            color: colors.textMuted,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: colors.borderSubtle),
          ),
          child: Text(
            badge,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: colors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpecRow(
    AppPalette colors, {
    required IconData icon,
    required String label,
    required String value,
    required String subtext,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 14, 16, isLast ? 14 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.borderSubtle),
            ),
            child: Icon(icon, size: 18, color: colors.neonLime),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: colors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtext,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: colors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRentalRow(
    AppPalette colors, {
    required String name,
    required String category,
    required String price,
    required IconData icon,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, isLast ? 12 : 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: colors.textPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category,
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: colors.textMuted,
                  ),
                ),
                Text(
                  name,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            price,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.courtSuccess,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyTile(
    AppPalette colors, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: colors.neonGreen),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: colors.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDivider(AppPalette colors) {
    return Divider(
      height: 1,
      thickness: 1,
      color: colors.borderSubtle,
      indent: 16,
      endIndent: 16,
    );
  }
}
