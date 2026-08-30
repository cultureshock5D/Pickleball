import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_theme.dart';
import 'neon_button.dart';

class TimePlayerSelection {
  final int timeSlotIndex;
  final TimeOfDay time;
  final double durationHours;
  final int playerCount;
  final String formatLabel;

  const TimePlayerSelection({
    required this.timeSlotIndex,
    required this.time,
    required this.durationHours,
    required this.playerCount,
    required this.formatLabel,
  });
}

class TimePlayerPickerModal extends StatefulWidget {
  final List<TimeOfDay> availableTimes;
  final int initialTimeSlotIndex;
  final double initialDuration;
  final int initialPlayerCount;
  final double hourlyRate;
  final ValueChanged<TimePlayerSelection> onSelectionConfirmed;

  const TimePlayerPickerModal({
    super.key,
    required this.availableTimes,
    required this.initialTimeSlotIndex,
    required this.initialDuration,
    this.initialPlayerCount = 4,
    this.hourlyRate = 120.0,
    required this.onSelectionConfirmed,
  });

  static Future<TimePlayerSelection?> show(
    BuildContext context, {
    required List<TimeOfDay> availableTimes,
    required int initialTimeSlotIndex,
    required double initialDuration,
    int initialPlayerCount = 4,
    double hourlyRate = 120.0,
  }) {
    return showModalBottomSheet<TimePlayerSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TimePlayerPickerModal(
        availableTimes: availableTimes,
        initialTimeSlotIndex: initialTimeSlotIndex,
        initialDuration: initialDuration,
        initialPlayerCount: initialPlayerCount,
        hourlyRate: hourlyRate,
        onSelectionConfirmed: (sel) => Navigator.of(ctx).pop(sel),
      ),
    );
  }

  @override
  State<TimePlayerPickerModal> createState() => _TimePlayerPickerModalState();
}

class _TimePlayerPickerModalState extends State<TimePlayerPickerModal> {
  late int _selectedSlotIndex;
  late double _selectedDuration;
  late int _selectedPlayerCount;

  static const List<double> _durations = [1.0, 1.5, 2.0, 3.0];
  static const List<int> _playerOptions = [2, 4, 6];

  @override
  void initState() {
    super.initState();
    _selectedSlotIndex = widget.initialTimeSlotIndex;
    _selectedDuration = widget.initialDuration;
    _selectedPlayerCount = widget.initialPlayerCount;
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _getFormatLabel(int count) {
    switch (count) {
      case 2:
        return 'Singles (2 Players)';
      case 4:
        return 'Doubles (4 Players)';
      case 6:
        return 'Group Practice (6 Players)';
      default:
        return '$count Players';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;
    final size = MediaQuery.of(context).size;
    final totalAmount = widget.hourlyRate * _selectedDuration;
    final selectedTime = widget.availableTimes[_selectedSlotIndex];

    return Container(
      constraints: BoxConstraints(
        maxHeight: size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131317) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: colors.borderSubtle,
            width: 1,
          ),
        ),
        boxShadow: colors.cardShadow,
      ),
      padding: EdgeInsets.only(
        top: 14,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
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

          // Title Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.access_time_filled_rounded,
                    color: colors.neonGreen,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Time, Duration & Players',
                    style: GoogleFonts.inter(
                      color: colors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close_rounded, color: colors.textMuted, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Session Duration Selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '1. Session Duration',
                        style: GoogleFonts.inter(
                          color: colors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${_selectedDuration.toString().replaceAll('.0', '')} hr match',
                        style: GoogleFonts.inter(
                          color: colors.neonLime,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: _durations.map((duration) {
                      final isSelected = _selectedDuration == duration;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedDuration = duration);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? colors.neonGreenAlpha20
                                  : colors.surfaceElevated,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? colors.neonGreen
                                    : colors.borderSubtle,
                                width: isSelected ? 1.6 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '${duration.toString().replaceAll('.0', '')} hrs',
                                  style: GoogleFonts.inter(
                                    color: isSelected
                                        ? colors.textPrimary
                                        : colors.textSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '₱${(widget.hourlyRate * duration).toStringAsFixed(0)}',
                                  style: GoogleFonts.inter(
                                    color: isSelected
                                        ? colors.neonLime
                                        : colors.textMuted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // 2. Players & Match Format
                  Text(
                    '2. Players & Match Format',
                    style: GoogleFonts.inter(
                      color: colors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: _playerOptions.map((count) {
                      final isSelected = _selectedPlayerCount == count;
                      final label = count == 2
                          ? '2 Players (Singles)'
                          : count == 4
                              ? '4 Players (Doubles)'
                              : '6 Players (Group)';
                      final icon = count == 2
                          ? Icons.person_rounded
                          : count == 4
                              ? Icons.group_rounded
                              : Icons.groups_rounded;

                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedPlayerCount = count);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? colors.neonGreenAlpha20
                                  : colors.surfaceElevated,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? colors.neonGreen
                                    : colors.borderSubtle,
                                width: isSelected ? 1.6 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  icon,
                                  color: isSelected
                                      ? colors.neonGreen
                                      : colors.textMuted,
                                  size: 20,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$count Players',
                                  style: GoogleFonts.inter(
                                    color: isSelected
                                        ? colors.textPrimary
                                        : colors.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  count == 2
                                      ? 'Singles'
                                      : count == 4
                                          ? 'Doubles'
                                          : 'Group',
                                  style: GoogleFonts.inter(
                                    color: colors.textMuted,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // 3. Start Time Slot Grid
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '3. Match Start Time',
                        style: GoogleFonts.inter(
                          color: colors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: colors.neonGreenAlpha15,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _formatTimeOfDay(selectedTime),
                          style: GoogleFonts.inter(
                            color: colors.neonGreen,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: widget.availableTimes.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      childAspectRatio: 2.6,
                    ),
                    itemBuilder: (context, index) {
                      final time = widget.availableTimes[index];
                      final isSelected = _selectedSlotIndex == index;

                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _selectedSlotIndex = index);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colors.neonGreenAlpha20
                                : colors.surfaceElevated,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? colors.neonGreen
                                  : colors.borderSubtle,
                              width: isSelected ? 1.6 : 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              _formatTimeOfDay(time),
                              style: GoogleFonts.inter(
                                color: isSelected
                                    ? colors.textPrimary
                                    : colors.textSecondary,
                                fontSize: 11.5,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Total Summary & Confirm Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: colors.surfaceElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.borderSubtle),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ESTIMATED RATE',
                      style: GoogleFonts.inter(
                        color: colors.textMuted,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₱${totalAmount.toStringAsFixed(0)}',
                      style: GoogleFonts.inter(
                        color: colors.neonLime,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${_formatTimeOfDay(selectedTime)} · ${_selectedDuration}h · ${_selectedPlayerCount}p',
                  style: GoogleFonts.inter(
                    color: colors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          NeonButton(
            text: 'Confirm Time & Players',
            icon: Icons.check_circle_outline_rounded,
            onPressed: () {
              final sel = TimePlayerSelection(
                timeSlotIndex: _selectedSlotIndex,
                time: selectedTime,
                durationHours: _selectedDuration,
                playerCount: _selectedPlayerCount,
                formatLabel: _getFormatLabel(_selectedPlayerCount),
              );
              widget.onSelectionConfirmed(sel);
            },
          ),
        ],
      ),
    );
  }
}
