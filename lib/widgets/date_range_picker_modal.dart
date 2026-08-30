import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import 'neon_button.dart';

class DateRangePickerModal extends StatefulWidget {
  final DateTime initialDate;
  final DateTime? initialEndDate;
  final ValueChanged<DateTime> onDateSelected;

  const DateRangePickerModal({
    super.key,
    required this.initialDate,
    this.initialEndDate,
    required this.onDateSelected,
  });

  static Future<DateTime?> show(
    BuildContext context, {
    required DateTime initialDate,
    DateTime? initialEndDate,
  }) {
    return showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DateRangePickerModal(
        initialDate: initialDate,
        initialEndDate: initialEndDate,
        onDateSelected: (date) => Navigator.of(ctx).pop(date),
      ),
    );
  }

  @override
  State<DateRangePickerModal> createState() => _DateRangePickerModalState();
}

class _DateRangePickerModalState extends State<DateRangePickerModal> {
  late DateTime _selectedDate;
  int _selectedPresetIndex = 0;

  static final DateFormat _dayOfWeekFormat = DateFormat('EEE');
  static final DateFormat _dayNumberFormat = DateFormat('d');
  static final DateFormat _fullDateFormat = DateFormat('EEE, d MMM yyyy');

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
  }

  void _applyPreset(int index) {
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    setState(() {
      _selectedPresetIndex = index;
      if (index == 0) {
        // Today
        _selectedDate = now;
      } else if (index == 1) {
        // Tomorrow
        _selectedDate = now.add(const Duration(days: 1));
      } else if (index == 2) {
        // This Weekend (Next Saturday or Today if Saturday)
        final daysUntilSat = (DateTime.saturday - now.weekday + 7) % 7;
        _selectedDate = now.add(Duration(days: daysUntilSat == 0 ? 0 : daysUntilSat));
      } else if (index == 3) {
        // Next Week (+7 days)
        _selectedDate = now.add(const Duration(days: 7));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;

    return Container(
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
          // Drag Handle
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
                    Icons.calendar_month_rounded,
                    color: colors.neonGreen,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Select Booking Date',
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

          // Quick Presets Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildPresetChip(0, 'Today'),
                _buildPresetChip(1, 'Tomorrow'),
                _buildPresetChip(2, 'This Weekend'),
                _buildPresetChip(3, 'Next Week'),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Formatted Selected Date Banner (Styled like reference)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: colors.neonGreenAlpha12,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.neonGreenAlpha35),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.neonGreenAlpha20,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.event_available_rounded,
                    color: colors.neonGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Target Match Day',
                        style: GoogleFonts.inter(
                          color: colors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _fullDateFormat.format(_selectedDate),
                        style: GoogleFonts.inter(
                          color: colors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Next 14 Days Calendar Strip
          Text(
            'Or pick a specific day:',
            style: GoogleFonts.inter(
              color: colors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),

          SizedBox(
            height: 76,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: 14,
              itemBuilder: (context, index) {
                final date = DateTime.now().add(Duration(days: index));
                final isSelected = _selectedDate.year == date.year &&
                    _selectedDate.month == date.month &&
                    _selectedDate.day == date.day;
                final isToday = index == 0;

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selectedDate = date;
                      _selectedPresetIndex = -1;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 58,
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colors.neonGreenAlpha20
                          : colors.surfaceElevated,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? colors.neonGreen
                            : colors.borderSubtle,
                        width: isSelected ? 1.6 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isToday ? 'TODAY' : _dayOfWeekFormat.format(date).toUpperCase(),
                          style: GoogleFonts.inter(
                            color: isSelected
                                ? colors.neonGreen
                                : (isToday ? colors.neonLime : colors.textMuted),
                            fontSize: 10,
                            fontWeight: isSelected || isToday
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _dayNumberFormat.format(date),
                          style: GoogleFonts.inter(
                            color: isSelected
                                ? colors.textPrimary
                                : colors.textSecondary,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // Confirm Button
          NeonButton(
            text: 'Confirm Date',
            icon: Icons.check_circle_outline_rounded,
            onPressed: () {
              widget.onDateSelected(_selectedDate);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(int index, String label) {
    final colors = context.colors;
    final isSelected = _selectedPresetIndex == index;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => _applyPreset(index),
        selectedColor: colors.neonGreenAlpha20,
        backgroundColor: colors.surfaceElevated,
        labelStyle: GoogleFonts.inter(
          color: isSelected ? colors.neonGreen : colors.textSecondary,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        ),
        side: BorderSide(
          color: isSelected ? colors.neonGreen : colors.borderSubtle,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
    );
  }
}
