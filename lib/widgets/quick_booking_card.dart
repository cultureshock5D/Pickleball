import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import '../models/venue_model.dart';

class QuickBookingCard extends StatelessWidget {
  final VenueModel? selectedVenue;
  final DateTime selectedDate;
  final DateTime? selectedEndDate;
  final TimeOfDay selectedTime;
  final double durationHours;
  final int playerCount;
  final double totalAmount;
  final VoidCallback onSelectVenue;
  final VoidCallback onSelectDate;
  final VoidCallback onSelectTimeAndPlayers;
  final VoidCallback onSearchOrBook;
  final String actionButtonText;
  final bool isLoading;

  const QuickBookingCard({
    super.key,
    required this.selectedVenue,
    required this.selectedDate,
    this.selectedEndDate,
    required this.selectedTime,
    required this.durationHours,
    this.playerCount = 4,
    required this.totalAmount,
    required this.onSelectVenue,
    required this.onSelectDate,
    required this.onSelectTimeAndPlayers,
    required this.onSearchOrBook,
    this.actionButtonText = 'Search Available Courts',
    this.isLoading = false,
  });

  static final DateFormat _dateFormat = DateFormat('EEE, d MMM');
  static final DateFormat _dateRangeFormat = DateFormat('EEE d MMM');

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String get _formattedDateString {
    if (selectedEndDate != null && !DateUtils.isSameDay(selectedDate, selectedEndDate)) {
      return '${_dateRangeFormat.format(selectedDate)} - ${_dateRangeFormat.format(selectedEndDate!)}';
    }
    final now = DateTime.now();
    if (DateUtils.isSameDay(selectedDate, now)) {
      return 'Today · ${_dateFormat.format(selectedDate)}';
    } else if (DateUtils.isSameDay(selectedDate, now.add(const Duration(days: 1)))) {
      return 'Tomorrow · ${_dateFormat.format(selectedDate)}';
    }
    return _dateFormat.format(selectedDate);
  }

  String get _formattedPlayerTimeString {
    final timeStr = _formatTimeOfDay(selectedTime);
    final durStr = '${durationHours.toString().replaceAll('.0', '')}h';
    return '$timeStr · $durStr · $playerCount Players';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141418) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colors.neonGreen,
          width: 2.2, // Glowing prominent accent outline matching reference image
        ),
        boxShadow: [
          BoxShadow(
            color: colors.neonGreenAlpha30,
            blurRadius: 18,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
          ...colors.cardShadow,
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19.8),
        child: Column(
          children: [
            // Row 1: Venue / Location (Reference: Barcelona)
            _buildSelectionRow(
              context: context,
              icon: Icons.location_on_outlined,
              title: selectedVenue?.name ?? 'Barcelona Smash Club',
              subtitle: selectedVenue?.city ?? 'Diagonal Mar, Barcelona',
              onTap: onSelectVenue,
              showTopBorder: false,
              trailingWidget: selectedVenue != null
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.neonLimeAlpha15,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${selectedVenue!.rating} ★',
                        style: GoogleFonts.inter(
                          color: colors.neonLime,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : null,
            ),

            _buildDivider(colors),

            // Row 2: Date (Reference: Wed 12 Jun - Tue 18 Jun)
            _buildSelectionRow(
              context: context,
              icon: Icons.calendar_today_outlined,
              title: _formattedDateString,
              subtitle: 'Select match date or schedule',
              onTap: onSelectDate,
              showTopBorder: false,
              trailingWidget: Icon(
                Icons.calendar_month_rounded,
                color: colors.neonGreen,
                size: 18,
              ),
            ),

            _buildDivider(colors),

            // Row 3: Time, Court & Players (Reference: 1 room - 2 adults)
            _buildSelectionRow(
              context: context,
              icon: Icons.person_outline_rounded,
              title: _formattedPlayerTimeString,
              subtitle: '1 Court · ${durationHours}h Match Session',
              onTap: onSelectTimeAndPlayers,
              showTopBorder: false,
              trailingWidget: Text(
                '₱${totalAmount.toStringAsFixed(0)}',
                style: GoogleFonts.inter(
                  color: colors.neonLime,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),

            // Full-Width Primary Action Button (Reference: Search Button)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isLoading
                    ? null
                    : () {
                        HapticFeedback.mediumImpact();
                        onSearchOrBook();
                      },
                child: Ink(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colors.neonGreenDark,
                        colors.neonGreen,
                      ],
                    ),
                  ),
                  child: Center(
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.search_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                actionButtonText,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionRow({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool showTopBorder,
    Widget? trailingWidget,
  }) {
    final colors = context.colors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors.neonGreenAlpha12,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: colors.neonGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
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
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        color: colors.textMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (trailingWidget != null) ...[
                const SizedBox(width: 8),
                trailingWidget,
              ] else
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.textMuted,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(AppPalette colors) {
    return Container(
      height: 1,
      color: colors.borderSubtle,
      margin: const EdgeInsets.symmetric(horizontal: 16),
    );
  }
}
