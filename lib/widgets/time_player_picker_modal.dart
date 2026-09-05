import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/validators.dart';
import 'neon_button.dart';

class MatchTimeSelection {
  final int timeSlotIndex;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final double durationHours;
  final double totalAmount;

  const MatchTimeSelection({
    required this.timeSlotIndex,
    required this.startTime,
    required this.endTime,
    this.durationHours = 1.0,
    required this.totalAmount,
  });

  // Backwards compatibility getters
  TimeOfDay get time => startTime;
  int get playerCount => 4;
  String get formatLabel => '1 Court Match (${durationHours.toString().replaceAll('.0', '')}h)';
}

/// Backwards compatibility alias
typedef TimePlayerSelection = MatchTimeSelection;

class TimePlayerPickerModal extends StatefulWidget {
  final List<TimeOfDay> availableTimes;
  final int initialTimeSlotIndex;
  final double initialDuration;
  final int initialPlayerCount;
  final double hourlyRate;
  final double peakHourlyRate;
  final int peakStartHour;
  final int peakEndHour;
  final bool Function(int slotIndex)? isSlotDisabled;
  final ValueChanged<MatchTimeSelection> onSelectionConfirmed;

  const TimePlayerPickerModal({
    super.key,
    required this.availableTimes,
    required this.initialTimeSlotIndex,
    this.initialDuration = 1.0,
    this.initialPlayerCount = 4,
    this.hourlyRate = 120.0,
    this.peakHourlyRate = 180.0,
    this.peakStartHour = 17,
    this.peakEndHour = 22,
    this.isSlotDisabled,
    required this.onSelectionConfirmed,
  });

  static Future<MatchTimeSelection?> show(
    BuildContext context, {
    required List<TimeOfDay> availableTimes,
    required int initialTimeSlotIndex,
    double initialDuration = 1.0,
    int initialPlayerCount = 4,
    double hourlyRate = 120.0,
    double peakHourlyRate = 180.0,
    int peakStartHour = 17,
    int peakEndHour = 22,
    bool Function(int slotIndex)? isSlotDisabled,
  }) {
    return showModalBottomSheet<MatchTimeSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TimePlayerPickerModal(
        availableTimes: availableTimes,
        initialTimeSlotIndex: initialTimeSlotIndex,
        initialDuration: initialDuration,
        initialPlayerCount: initialPlayerCount,
        hourlyRate: hourlyRate,
        peakHourlyRate: peakHourlyRate,
        peakStartHour: peakStartHour,
        peakEndHour: peakEndHour,
        isSlotDisabled: isSlotDisabled,
        onSelectionConfirmed: (sel) => Navigator.of(ctx).pop(sel),
      ),
    );
  }

  @override
  State<TimePlayerPickerModal> createState() => _TimePlayerPickerModalState();
}

class _TimePlayerPickerModalState extends State<TimePlayerPickerModal> {
  late int _selectedSlotIndex;

  static const double _standardSlotDuration = 1.0; // 1 hour standard court session

  @override
  void initState() {
    super.initState();
    _selectedSlotIndex = widget.initialTimeSlotIndex.clamp(0, widget.availableTimes.length - 1);
  }

  bool _isPeak(TimeOfDay time) {
    return time.hour >= widget.peakStartHour && time.hour < widget.peakEndHour;
  }

  double _slotRate(TimeOfDay time) {
    return _isPeak(time) ? widget.peakHourlyRate : widget.hourlyRate;
  }

  TimeOfDay _computeEndTime(TimeOfDay start, double durationHours) {
    final totalMinutes = start.hour * 60 + start.minute + (durationHours * 60).round();
    final endHour = (totalMinutes ~/ 60) % 24;
    final endMinute = totalMinutes % 60;
    return TimeOfDay(hour: endHour, minute: endMinute);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;
    final size = MediaQuery.sizeOf(context);

    final selectedStartTime = widget.availableTimes[_selectedSlotIndex];
    final selectedEndTime = _computeEndTime(selectedStartTime, _standardSlotDuration);
    final isSelectedPeak = _isPeak(selectedStartTime);
    final autoComputedPrice = _slotRate(selectedStartTime) * _standardSlotDuration;

    return Container(
      constraints: BoxConstraints(
        maxHeight: size.height * 0.88,
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
      padding: EdgeInsets.only(
        top: 14,
        left: 20,
        right: 20,
        bottom: MediaQuery.paddingOf(context).bottom + 20,
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

          // Header Title Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colors.neonGreenAlpha15,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.schedule_rounded,
                        color: colors.neonGreen,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Match Time Slot',
                            style: GoogleFonts.inter(
                              color: colors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            'Court Match Duration: 1-hour slot • Auto-computes fee',
                            style: GoogleFonts.inter(
                              color: colors.textMuted,
                              fontSize: 11.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: colors.textMuted, size: 22),
                  tooltip: 'Close',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Time Slots Grid (All Slots directly, no period filter widgets)
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: widget.availableTimes.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 2.2,
                    ),
                    itemBuilder: (context, index) {
                      final time = widget.availableTimes[index];
                      final isSelected = _selectedSlotIndex == index;
                      final endTime = _computeEndTime(time, _standardSlotDuration);
                      final isBooked = widget.isSlotDisabled?.call(index) ?? false;
                      final slotLabel = Validators.formatTimeOfDaySlotRange(time, endTime);
                      final slotIsPeak = _isPeak(time);
                      final slotPrice = _slotRate(time) * _standardSlotDuration;

                      return Semantics(
                        button: true,
                        selected: isSelected,
                        enabled: !isBooked,
                        label: '$slotLabel, ${slotIsPeak ? "Peak rate" : "Off-Peak rate"}${isBooked ? ", Booked" : ""}',
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: isBooked
                                ? null
                                : () {
                                    HapticFeedback.selectionClick();
                                    setState(() => _selectedSlotIndex = index);
                                  },
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 180),
                              opacity: isBooked ? 0.45 : 1.0,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                decoration: BoxDecoration(
                                  color: isBooked
                                      ? colors.surfaceHighlight.withAlpha(80)
                                      : isSelected
                                          ? (slotIsPeak ? Colors.amber.withAlpha(45) : const Color(0xFFCCFF00).withAlpha(30))
                                          : colors.surfaceElevated,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isBooked
                                        ? colors.borderSubtle
                                        : isSelected
                                            ? (slotIsPeak ? const Color(0xFFFACC15) : const Color(0xFFCCFF00))
                                            : (slotIsPeak ? Colors.amber.withAlpha(80) : colors.borderSubtle),
                                    width: isSelected ? 2.0 : 1.0,
                                  ),
                                  boxShadow: (isSelected && !isBooked)
                                      ? [
                                          BoxShadow(
                                            color: (slotIsPeak ? const Color(0xFFFACC15) : const Color(0xFFCCFF00)).withAlpha(90),
                                            blurRadius: 12,
                                            spreadRadius: 1,
                                          ),
                                        ]
                                      : const [],
                                ),
                                child: Stack(
                                  children: [
                                    // Top Peak Hour Visual Ribbon Accent Strip
                                    if (slotIsPeak && !isBooked)
                                      Positioned(
                                        top: 0,
                                        left: 12,
                                        right: 12,
                                        child: Container(
                                          height: 2.5,
                                          decoration: BoxDecoration(
                                            color: isSelected ? Colors.amberAccent : Colors.amber.withAlpha(150),
                                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(2)),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.amber.withAlpha(120),
                                                blurRadius: 4,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  slotLabel,
                                                  style: GoogleFonts.inter(
                                                    color: isBooked
                                                        ? colors.textMuted
                                                        : isSelected
                                                            ? (slotIsPeak ? Colors.amberAccent : const Color(0xFFCCFF00))
                                                            : colors.textPrimary,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: -0.2,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (isBooked)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                  decoration: BoxDecoration(
                                                    color: Colors.red.withAlpha(25),
                                                    borderRadius: BorderRadius.circular(5),
                                                    border: Border.all(color: Colors.red.withAlpha(60)),
                                                  ),
                                                  child: Text(
                                                    'BOOKED',
                                                    style: GoogleFonts.inter(
                                                      color: Colors.redAccent,
                                                      fontSize: 8.5,
                                                      fontWeight: FontWeight.w800,
                                                    ),
                                                  ),
                                                )
                                              else if (slotIsPeak)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                  decoration: BoxDecoration(
                                                    color: Colors.amber.withAlpha(40),
                                                    borderRadius: BorderRadius.circular(5),
                                                    border: Border.all(color: Colors.amber.withAlpha(90)),
                                                  ),
                                                  child: Text(
                                                    'PEAK',
                                                    style: GoogleFonts.inter(
                                                      color: Colors.amber,
                                                      fontSize: 8.5,
                                                      fontWeight: FontWeight.w800,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                isBooked
                                                    ? 'Unavailable'
                                                    : (slotIsPeak ? 'Peak Hour' : 'Off-Peak'),
                                                style: GoogleFonts.inter(
                                                  color: isBooked
                                                      ? colors.textMuted
                                                      : (slotIsPeak ? Colors.amber.withAlpha(220) : colors.textMuted),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              Text(
                                                '₱${slotPrice.toStringAsFixed(0)}',
                                                style: GoogleFonts.inter(
                                                  color: isBooked
                                                      ? colors.textMuted
                                                      : isSelected
                                                          ? (slotIsPeak ? Colors.amberAccent : const Color(0xFFCCFF00))
                                                          : colors.textSecondary,
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w700,
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
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),

          // Live Auto-Computed Match Time & Price Ledger
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              gradient: colors.cardGradient,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelectedPeak ? Colors.amber.withAlpha(120) : colors.borderSubtle,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'SELECTED TIME SLOT',
                              style: GoogleFonts.inter(
                                color: colors.textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: isSelectedPeak
                                    ? Colors.amber.withAlpha(30)
                                    : colors.neonLimeAlpha15,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isSelectedPeak ? 'PEAK' : 'OFF-PEAK',
                                style: GoogleFonts.inter(
                                  color: isSelectedPeak ? Colors.amber : colors.neonLime,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          Validators.formatTimeOfDaySlotRange(selectedStartTime, selectedEndTime),
                          style: GoogleFonts.inter(
                            color: colors.textPrimary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'AUTO-COMPUTED FEE',
                          style: GoogleFonts.inter(
                            color: isSelectedPeak ? Colors.amber : colors.neonGreen,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₱${autoComputedPrice.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(
                            color: isSelectedPeak ? Colors.amberAccent : colors.neonLime,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.timelapse_rounded,
                          size: 13,
                          color: colors.neonLime,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Court Match Duration: 1.0 Hour',
                          style: GoogleFonts.inter(
                            color: colors.textSecondary,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      isSelectedPeak ? 'Peak Hour Rate' : 'Off-Peak Rate',
                      style: GoogleFonts.inter(
                        color: isSelectedPeak ? Colors.amber : colors.neonGreen,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.lock_clock_rounded,
                      size: 12,
                      color: colors.textMuted,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '5-minute transient lock applied upon confirmation',
                      style: GoogleFonts.inter(
                        color: colors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          NeonButton(
            text: 'Confirm Match Time Slot',
            icon: Icons.check_circle_outline_rounded,
            onPressed: () {
              final sel = MatchTimeSelection(
                timeSlotIndex: _selectedSlotIndex,
                startTime: selectedStartTime,
                endTime: selectedEndTime,
                totalAmount: autoComputedPrice,
              );
              widget.onSelectionConfirmed(sel);
            },
          ),
        ],
      ),
    );
  }
}


