import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_theme.dart';
import '../models/venue_model.dart';

class VenuePickerModal extends StatefulWidget {
  final List<VenueModel> venues;
  final VenueModel? selectedVenue;
  final ValueChanged<VenueModel> onVenueSelected;

  const VenuePickerModal({
    super.key,
    required this.venues,
    this.selectedVenue,
    required this.onVenueSelected,
  });

  static Future<VenueModel?> show(
    BuildContext context, {
    required List<VenueModel> venues,
    VenueModel? selectedVenue,
  }) {
    return showModalBottomSheet<VenueModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VenuePickerModal(
        venues: venues,
        selectedVenue: selectedVenue,
        onVenueSelected: (venue) => Navigator.of(ctx).pop(venue),
      ),
    );
  }

  @override
  State<VenuePickerModal> createState() => _VenuePickerModalState();
}

class _VenuePickerModalState extends State<VenuePickerModal> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<VenueModel> get _filteredVenues {
    if (_searchQuery.isEmpty) return widget.venues;
    final q = _searchQuery.toLowerCase();
    return widget.venues.where((v) {
      return v.name.toLowerCase().contains(q) ||
          v.city.toLowerCase().contains(q) ||
          v.address.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;
    final size = MediaQuery.sizeOf(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceElevated : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: colors.borderSubtle,
          ),
        ),
        boxShadow: colors.cardShadow,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Drag Handle
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: colors.borderSubtle,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            color: colors.neonGreen,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Select Club & Venue',
                            style: GoogleFonts.inter(
                              color: colors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Choose from top championship pickleball clubs',
                        style: GoogleFonts.inter(
                          color: colors.textMuted,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close_rounded,
                      color: colors.textMuted,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Search Filter
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  color: colors.surfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.borderSubtle),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: GoogleFonts.inter(
                    color: colors.textPrimary,
                    fontSize: 13.5,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search venue or city (e.g. Barcelona)...',
                    hintStyle: GoogleFonts.inter(
                      color: colors.textMuted,
                      fontSize: 13,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: colors.textMuted,
                      size: 19,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Venues List
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                shrinkWrap: true,
                itemCount: _filteredVenues.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final venue = _filteredVenues[index];
                  final isSelected = widget.selectedVenue?.id == venue.id;

                  return Semantics(
                    button: true,
                    selected: isSelected,
                    label: '${venue.name}, ${venue.address}',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        widget.onVenueSelected(venue);
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
                          color: isSelected
                              ? colors.neonGreen
                              : colors.borderSubtle,
                          width: isSelected ? 1.6 : 1,
                        ),
                        boxShadow: isSelected ? colors.cardShadow : null,
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
                                            borderRadius:
                                                BorderRadius.circular(6),
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
                          const SizedBox(height: 10),

                          // Amenities / Badges Row
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
                          const SizedBox(height: 8),

                          // Bottom Rate & Select Row
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
                                    color: isSelected
                                        ? colors.neonGreen
                                        : colors.textMuted,
                                    size: 13,
                                  ),
                                ],
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
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniBadge({
    required IconData icon,
    required String label,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
