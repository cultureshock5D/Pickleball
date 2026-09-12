import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_theme.dart';
import '../models/venue_model.dart';

/// Luxury dark-themed venue discovery and selection card.
/// Designed with exact 130.0dp height and 140.0dp pitch (CLS = 0 with [SkeletonVenueCard]).
class VenueCard extends StatelessWidget {
  static const double cardHeight = 130.0;
  static const double cardPitch = 140.0;
  static const double verticalSpacing = 10.0; // cardPitch - cardHeight

  final VenueModel venue;
  final bool isSelected;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;
  final double? height;

  const VenueCard({
    super.key,
    required this.venue,
    this.isSelected = false,
    this.onTap,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
    this.height = cardHeight,
  });

  Widget _buildMiniBadge({
    required IconData icon,
    required String label,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      selected: isSelected,
      label: '${venue.name}, ${venue.address}',
      child: Container(
        margin: margin,
        height: height,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            onTap?.call();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSelected
                  ? colors.neonGreenAlpha12
                  : colors.surfaceElevated,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected ? colors.neonGreen : colors.borderSubtle,
                width: isSelected ? 1.6 : 1.0,
              ),
              boxShadow: isSelected ? colors.cardShadow : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Row 1: Icon container + Venue title/tag/address
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colors.neonGreenAlpha20
                            : colors.surfaceHighlight,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? colors.neonGreen
                              : Colors.transparent,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.sports_tennis_rounded,
                          color: isSelected
                              ? colors.neonGreen
                              : colors.textSecondary,
                          size: 22,
                        ),
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
                                  venue.name,
                                  style: GoogleFonts.inter(
                                    color: colors.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.neonLimeAlpha15,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  venue.tag,
                                  style: GoogleFonts.inter(
                                    color: colors.neonLime,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            venue.address,
                            style: GoogleFonts.inter(
                              color: colors.textMuted,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Row 2: Amenities / Badges Row
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildMiniBadge(
                      icon: Icons.star_rounded,
                      label: '${venue.rating} (${venue.reviewCount})',
                      color: const Color(0xFFF59E0B),
                      bg: const Color(0x1AF59E0B),
                    ),
                    _buildMiniBadge(
                      icon: Icons.grid_view_rounded,
                      label: '${venue.courtCount} Courts',
                      color: colors.neonGreen,
                      bg: colors.neonGreenAlpha12,
                    ),
                    _buildMiniBadge(
                      icon: Icons.wb_shade_rounded,
                      label: venue.courtType,
                      color: colors.textSecondary,
                      bg: colors.surfaceHighlight,
                    ),
                  ],
                ),

                // Row 3: Bottom Rate & Select Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'From ₱${venue.priceStartingAt.toStringAsFixed(0)} / hr',
                      style: GoogleFonts.inter(
                        color: colors.neonLime,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          isSelected ? 'Selected' : 'Select Venue',
                          style: GoogleFonts.inter(
                            color: isSelected
                                ? colors.neonGreen
                                : colors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          isSelected
                              ? Icons.check_circle_rounded
                              : Icons.arrow_forward_ios_rounded,
                          size: 13,
                          color: isSelected
                              ? colors.neonGreen
                              : colors.textMuted,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
