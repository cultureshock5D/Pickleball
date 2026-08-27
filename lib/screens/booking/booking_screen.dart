import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../models/court_model.dart';
import '../../services/booking_service.dart';
import '../../widgets/neon_button.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final BookingService _bookingService = BookingService.instance;

  // State Variables
  List<CourtModel> _courts = [];
  bool _isLoadingCourts = true;
  CourtModel? _selectedCourt;

  late DateTime _selectedDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);

    // Default start time: next upcoming full hour
    int startHour = (now.hour + 1) % 24;
    _startTime = TimeOfDay(hour: startHour == 0 ? 9 : startHour, minute: 0);
    _endTime = TimeOfDay(hour: (_startTime.hour + 1) % 24, minute: 0);

    _loadCourts();
  }

  Future<void> _loadCourts() async {
    setState(() => _isLoadingCourts = true);
    final courts = await _bookingService.fetchActiveCourts();
    if (mounted) {
      setState(() {
        _courts = courts;
        if (_courts.isNotEmpty) {
          _selectedCourt = _courts.first;
        }
        _isLoadingCourts = false;
      });
    }
  }

  DateTime get _startDateTime {
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _startTime.hour,
      _startTime.minute,
    );
  }

  DateTime get _endDateTime {
    DateTime end = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _endTime.hour,
      _endTime.minute,
    );
    if (end.isBefore(_startDateTime) || end.isAtSameMomentAs(_startDateTime)) {
      end = end.add(const Duration(days: 1));
    }
    return end;
  }

  double get _durationHours {
    final diff = _endDateTime.difference(_startDateTime);
    final hours = diff.inMinutes / 60.0;
    return hours > 0 ? hours : 1.0;
  }

  double get _baseRate => _selectedCourt?.hourlyRate ?? 120.0;
  double get _totalAmount => _baseRate * _durationHours;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(now) ? now : _selectedDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 60)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.neonLime,
              onPrimary: Colors.black,
              surface: AppTheme.surfaceElevated,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.neonLime,
              onPrimary: Colors.black,
              surface: AppTheme.surfaceElevated,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _startTime = picked;
        // Auto adjust end time if it becomes before or same as start time
        final newStartMinutes = picked.hour * 60 + picked.minute;
        final currentEndMinutes = _endTime.hour * 60 + _endTime.minute;
        if (currentEndMinutes <= newStartMinutes) {
          _endTime = TimeOfDay(
            hour: (picked.hour + 1) % 24,
            minute: picked.minute,
          );
        }
      });
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.neonLime,
              onPrimary: Colors.black,
              surface: AppTheme.surfaceElevated,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _endTime = picked;
      });
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _formatDateFull(DateTime date) {
    const weekDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return '${weekDays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatDateShort(DateTime date) {
    const weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${weekDays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<void> _handleCreateBooking() async {
    if (_selectedCourt == null) return;

    final confirmed = await _showConfirmationDialog();
    if (confirmed != true) return;

    setState(() => _isSubmitting = true);

    try {
      final booking = await _bookingService.createBooking(
        courtId: _selectedCourt!.id,
        startTime: _startDateTime,
        endTime: _endDateTime,
        totalAmount: _totalAmount,
      );

      if (mounted) {
        _showSuccessDialog(booking.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.surfaceElevated,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppTheme.errorRed),
            ),
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: AppTheme.errorRed, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    e.toString().replaceAll('Exception: ', ''),
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<bool?> _showConfirmationDialog() {
    final durationStr = _durationHours == _durationHours.roundToDouble()
        ? '${_durationHours.toInt()} hr${_durationHours > 1 ? 's' : ''}'
        : '${_durationHours.toStringAsFixed(1)} hrs';

    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppTheme.surfaceElevated,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: AppTheme.borderSubtle, width: 1)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.borderSubtle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Confirm Court Booking',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Review your reservation details',
                style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 20),

              // Summary Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Column(
                  children: [
                    _buildSummaryRow('Court', _selectedCourt?.name ?? ''),
                    const Divider(color: AppTheme.borderSubtle, height: 16),
                    _buildSummaryRow('Date', _formatDateShort(_selectedDate)),
                    const Divider(color: AppTheme.borderSubtle, height: 16),
                    _buildSummaryRow(
                      'Time',
                      '${_formatTimeOfDay(_startTime)} - ${_formatTimeOfDay(_endTime)}',
                    ),
                    const Divider(color: AppTheme.borderSubtle, height: 16),
                    _buildSummaryRow('Duration', durationStr),
                    const Divider(color: AppTheme.borderSubtle, height: 16),
                    _buildSummaryRow(
                      'Rate',
                      '₱${_baseRate.toStringAsFixed(2)} / hr',
                    ),
                    const Divider(color: AppTheme.borderSubtle, height: 16),
                    _buildSummaryRow(
                      'Total Price',
                      '₱${_totalAmount.toStringAsFixed(2)}',
                      valueColor: AppTheme.neonLime,
                      isBold: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: AppTheme.borderSubtle),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text('Cancel', style: GoogleFonts.inter(color: AppTheme.textMuted)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: NeonButton(
                      text: 'Confirm & Book',
                      icon: Icons.check_circle_outline_rounded,
                      onPressed: () => Navigator.of(ctx).pop(true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSuccessDialog(String bookingId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppTheme.borderSubtle),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppTheme.neonLime.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppTheme.neonLime,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Court Reserved!',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your reservation has been booked successfully.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Text(
                'ID: $bookingId',
                style: GoogleFonts.robotoMono(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 20),
            NeonButton(
              text: 'Done',
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? valueColor, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            color: valueColor ?? Colors.white,
            fontSize: isBold ? 15 : 13,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final durationStr = _durationHours == _durationHours.roundToDouble()
        ? '${_durationHours.toInt()} hr${_durationHours > 1 ? 's' : ''}'
        : '${_durationHours.toStringAsFixed(1)} hrs';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Clean Title Header
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.neonLime.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.neonLime.withValues(alpha: 0.3)),
                ),
                child: const Icon(
                  Icons.sports_tennis_rounded,
                  color: AppTheme.neonLime,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Book a Pickleball Court',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Select date, time slot, and court to reserve',
                    style: GoogleFonts.inter(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 22),

          // 2. Available Courts Selector Card List
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Select Court',
                style: GoogleFonts.inter(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_isLoadingCourts)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.neonLime),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _courts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final court = _courts[index];
              final isSelected = _selectedCourt?.id == court.id;

              return GestureDetector(
                onTap: () => setState(() => _selectedCourt = court),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.surfaceHighlight : AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? AppTheme.neonLime : AppTheme.borderSubtle,
                      width: isSelected ? 1.6 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.neonLime.withValues(alpha: 0.2)
                              : const Color(0xFF26262E),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.sports_tennis_rounded,
                          color: isSelected ? AppTheme.neonLime : Colors.white70,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              court.name,
                              style: GoogleFonts.inter(
                                color: AppTheme.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${court.courtType} • ${court.surfaceType}',
                              style: GoogleFonts.inter(
                                color: AppTheme.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₱${court.hourlyRate.toStringAsFixed(0)}/hr',
                            style: GoogleFonts.inter(
                              color: isSelected ? AppTheme.neonLime : Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.neonLime.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'AVAILABLE',
                              style: GoogleFonts.inter(
                                color: AppTheme.neonLime,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // 3. Date & Time Selection Section (Native Pickers)
          Text(
            'Schedule & Time',
            style: GoogleFonts.inter(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),

          // Date Selection Input Box
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_month_rounded,
                    color: AppTheme.neonLime,
                    size: 22,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Booking Date',
                          style: GoogleFonts.inter(
                            color: AppTheme.textMuted,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDateFull(_selectedDate),
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.edit_calendar_rounded,
                    color: AppTheme.textMuted,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Start & End Time Pickers (Row)
          Row(
            children: [
              // Start Time
              Expanded(
                child: GestureDetector(
                  onTap: _pickStartTime,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.access_time_filled_rounded,
                          color: AppTheme.neonLime,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Start Time',
                                style: GoogleFonts.inter(
                                  color: AppTheme.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatTimeOfDay(_startTime),
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // End Time
              Expanded(
                child: GestureDetector(
                  onTap: _pickEndTime,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          color: AppTheme.neonLime,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'End Time',
                                style: GoogleFonts.inter(
                                  color: AppTheme.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatTimeOfDay(_endTime),
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 4. Price Calculation Breakdown Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppTheme.cardGradient,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Booking Summary',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                _buildSummaryRow(
                  'Court Rate',
                  '₱${_baseRate.toStringAsFixed(2)} / hr',
                ),
                const SizedBox(height: 8),
                _buildSummaryRow(
                  'Calculated Duration',
                  durationStr,
                ),
                const Divider(color: AppTheme.borderSubtle, height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Amount',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '₱${_totalAmount.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(
                        color: AppTheme.neonLime,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 5. Primary Neon CTA Button
          NeonButton(
            text: 'Book Court • ₱${_totalAmount.toStringAsFixed(2)}',
            isLoading: _isSubmitting,
            icon: Icons.flash_on_rounded,
            onPressed: _handleCreateBooking,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
