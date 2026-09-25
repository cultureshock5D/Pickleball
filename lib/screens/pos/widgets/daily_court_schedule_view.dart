import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../data/mock_data.dart';
import '../../../models/booking_model.dart';
import '../../../models/court_model.dart';
import '../../../services/pos_service.dart';

class DailyCourtScheduleView extends StatefulWidget {
  final VoidCallback onBackToRegister;
  final VoidCallback? onToggleMenu;
  final String cashierId;
  final String cashierName;

  const DailyCourtScheduleView({
    super.key,
    required this.onBackToRegister,
    this.onToggleMenu,
    this.cashierId = 'cashier-01',
    this.cashierName = 'Cashier Staff',
  });

  @override
  State<DailyCourtScheduleView> createState() => _DailyCourtScheduleViewState();
}

class _DailyCourtScheduleViewState extends State<DailyCourtScheduleView> {
  final PosService _posService = PosService.instance;

  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  List<BookingModel> _bookings = [];
  List<CourtModel> _courts = [];
  StreamSubscription<void>? _updatesSub;

  final currencyFmt = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
  final timeFmt = DateFormat('hh:mm a');

  @override
  void initState() {
    super.initState();
    _initCourts();
    _loadScheduleData();
    _updatesSub = _posService.onPosUpdates.listen((_) {
      if (mounted) _loadScheduleData(isSilent: true);
    });
  }

  @override
  void dispose() {
    _updatesSub?.cancel();
    super.dispose();
  }

  void _initCourts() {
    final list = <CourtModel>[];
    list.addAll(MockData.defaultCourts);
    list.addAll(MockData.defaultBasketballCourts);
    list.add(
      const CourtModel(
        id: 'court-event-pavilion',
        name: 'Events Place — Grand Pavilion',
        type: 'event_space',
        hourlyRate: 1500.0,
      ),
    );
    _courts = list;
  }

  Future<void> _loadScheduleData({bool isSilent = false}) async {
    if (!isSilent) {
      setState(() => _isLoading = true);
    }
    try {
      final bookings = await _posService.fetchScheduleBookings(date: _selectedDate);
      if (mounted) {
        setState(() {
          _bookings = bookings;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppSnackBar.error(context, 'Failed to load court schedule: $e');
      }
    }
  }

  void _changeDate(int dayOffset) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: dayOffset));
    });
    _loadScheduleData();
  }

  void _setToday() {
    setState(() {
      _selectedDate = DateTime.now();
    });
    _loadScheduleData();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF10B981),
              onPrimary: Colors.white,
              surface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadScheduleData();
    }
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  BookingModel? _getBookingForSlot(String courtId, int hour) {
    for (final b in _bookings) {
      if (b.status == 'cancelled' || b.status == 'cancelled_refund_pending' || b.status == 'expired') {
        continue;
      }
      if (b.courtId == courtId) {
        final startH = b.startTime.hour;
        final endH = b.endTime.hour == 0 ? 24 : b.endTime.hour;
        if (hour >= startH && hour < endH) {
          return b;
        }
      }
    }
    return null;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'paid':
      case 'confirmed':
        return const Color(0xFF10B981); // Emerald
      case 'checked_in':
        return const Color(0xFF3B82F6); // Blue
      case 'walk_in':
        return const Color(0xFF00B4D8); // Teal
      case 'pending_payment':
      case 'pending':
        return const Color(0xFFF59E0B); // Amber
      case 'cancelled':
      case 'expired':
        return const Color(0xFF64748B); // Muted
      default:
        return const Color(0xFF10B981);
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'paid':
      case 'confirmed':
        return 'PAID';
      case 'checked_in':
        return 'CHECKED-IN';
      case 'walk_in':
        return 'WALK-IN';
      case 'pending_payment':
      case 'pending':
        return 'PENDING';
      case 'cancelled':
        return 'CANCELLED';
      default:
        return status.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);
    final isShortHeight = size.height < 550;
    final isCompactWidth = size.width < 768;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090E14) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Top Header Bar
            _buildHeaderBar(colors, isDark, isShortHeight, isCompactWidth),

            Divider(
              height: 1,
              thickness: 1,
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            ),

            // Date Toolbar & Action Controls
            _buildDateToolbar(colors, isDark, isShortHeight, isCompactWidth),

            Divider(
              height: 1,
              thickness: 1,
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            ),

            // Color-coded Status Legend
            _buildLegendBar(colors, isDark),

            // Main Schedule Grid Viewport
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF10B981)),
                    )
                  : _buildScheduleGrid(colors, isDark, isShortHeight, isCompactWidth),
            ),
          ],
        ),
      ),
    );
  }

  // --- HEADER BAR ---
  Widget _buildHeaderBar(
    dynamic colors,
    bool isDark,
    bool isShortHeight,
    bool isCompactWidth,
  ) {
    return Container(
      height: isShortHeight ? 44 : 56,
      padding: EdgeInsets.symmetric(horizontal: isShortHeight ? 10 : 16),
      color: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.menu_rounded),
            color: colors.textPrimary,
            tooltip: 'Navigation Menu',
            onPressed: widget.onToggleMenu ?? widget.onBackToRegister,
          ),
          const SizedBox(width: 8),

          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.calendar_month_outlined,
              color: Color(0xFF10B981),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),

          Expanded(
            child: Text(
              'Court Schedule & Walk-in Terminal',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: isShortHeight ? 13 : 16,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
          ),

          // Return to Register Quick Button
          OutlinedButton.icon(
            icon: const Icon(Icons.point_of_sale_rounded, size: 14),
            label: Text(
              isCompactWidth ? 'POS' : 'Register',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
            ),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              side: BorderSide(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
              ),
            ),
            onPressed: widget.onBackToRegister,
          ),
        ],
      ),
    );
  }

  // --- DATE TOOLBAR ---
  Widget _buildDateToolbar(
    dynamic colors,
    bool isDark,
    bool isShortHeight,
    bool isCompactWidth,
  ) {
    final isTodayDate = _isToday(_selectedDate);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isShortHeight ? 8 : (isCompactWidth ? 8 : 16),
        vertical: isShortHeight ? 4 : 8,
      ),
      color: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showFullDate = constraints.maxWidth > 480;
          final dateStr = showFullDate
              ? DateFormat('EEE, MMM d, yyyy').format(_selectedDate)
              : DateFormat('MMM d, yyyy').format(_selectedDate);

          return Row(
            children: [
              // Previous Day
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
                color: colors.textPrimary,
                tooltip: 'Previous Day',
                onPressed: () => _changeDate(-1),
              ),

              // Date Picker Button
              Flexible(
                child: InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isTodayDate
                            ? const Color(0xFF10B981)
                            : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.event_outlined,
                          size: 13,
                          color: isTodayDate ? const Color(0xFF10B981) : colors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            isTodayDate && showFullDate ? '$dateStr (Today)' : dateStr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isTodayDate ? const Color(0xFF10B981) : colors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Next Day
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
                color: colors.textPrimary,
                tooltip: 'Next Day',
                onPressed: () => _changeDate(1),
              ),

              if (!isTodayDate) ...[
                const SizedBox(width: 2),
                TextButton(
                  onPressed: _setToday,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: const Size(36, 32),
                  ),
                  child: Text(
                    'Today',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ),
              ],

              const Spacer(),

              // Walk-in Booking Action Button
              ElevatedButton.icon(
                icon: const Icon(Icons.add_circle_outline_rounded, size: 14),
                label: Text(
                  isCompactWidth ? 'Walk-In' : '+ Walk-In Booking',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.symmetric(horizontal: isCompactWidth ? 8 : 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _openWalkInModal(),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- LEGEND BAR ---
  Widget _buildLegendBar(dynamic colors, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: isDark ? const Color(0xFF090E14) : const Color(0xFFF1F5F9),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildLegendItem('Paid', const Color(0xFF10B981), colors),
            const SizedBox(width: 14),
            _buildLegendItem('Checked-In', const Color(0xFF3B82F6), colors),
            const SizedBox(width: 14),
            _buildLegendItem('Walk-In', const Color(0xFF00B4D8), colors),
            const SizedBox(width: 14),
            _buildLegendItem('Pending Payment', const Color(0xFFF59E0B), colors),
            const SizedBox(width: 14),
            _buildLegendItem('Available', isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1), colors),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, dynamic colors) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }

  // --- SCHEDULE GRID ---
  Widget _buildScheduleGrid(
    dynamic colors,
    bool isDark,
    bool isShortHeight,
    bool isCompactWidth,
  ) {
    const timeColWidth = 76.0;
    final courtColWidth = isCompactWidth ? 148.0 : 170.0;
    const rowHeight = 72.0;

    // Hours 6:00 to 23:00 (18 hours)
    final hours = List.generate(18, (i) => i + 6);

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: timeColWidth + (_courts.length * courtColWidth),
        child: Column(
          children: [
            // Sticky Court Header Row
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1),
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Time Column Header
                  SizedBox(
                    width: timeColWidth,
                    child: Center(
                      child: Text(
                        'TIME',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ),

                  // Court Column Headers
                  ..._courts.map((court) {
                    return Container(
                      width: courtColWidth,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1),
                          ),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            court.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '₱${court.hourlyRate.toStringAsFixed(0)}/hr',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),

            // Scrollable Timeline Rows
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  children: hours.map((hour) {
                    final isEven = hour % 2 == 0;
                    final slotTimeStr = DateFormat('hh:00 a').format(DateTime(2026, 1, 1, hour));

                    return Container(
                      height: rowHeight,
                      decoration: BoxDecoration(
                        color: isEven
                            ? (isDark ? const Color(0xFF0F172A).withValues(alpha: 0.4) : Colors.white)
                            : (isDark ? const Color(0xFF090E14) : const Color(0xFFF8FAFC)),
                        border: Border(
                          bottom: BorderSide(
                            color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.6) : const Color(0xFFE2E8F0),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Time Label
                          SizedBox(
                            width: timeColWidth,
                            child: Center(
                              child: Text(
                                slotTimeStr,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                          ),

                          // Court Slots
                          ..._courts.map((court) {
                            final booking = _getBookingForSlot(court.id, hour);

                            return Container(
                              width: courtColWidth,
                              height: rowHeight,
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                border: Border(
                                  left: BorderSide(
                                    color: isDark
                                        ? const Color(0xFF1E293B).withValues(alpha: 0.6)
                                        : const Color(0xFFE2E8F0),
                                  ),
                                ),
                              ),
                              child: booking != null
                                  ? _buildBookedTile(booking, colors, isDark)
                                  : _buildAvailableTile(court, hour, colors, isDark),
                            );
                          }),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- BOOKED SLOT TILE ---
  Widget _buildBookedTile(BookingModel booking, dynamic colors, bool isDark) {
    final statusColor = _getStatusColor(booking.status);
    final statusLabel = _getStatusLabel(booking.status);
    final hasBalance = booking.remainingBalance > 0.01;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openBookingDetailsModal(booking),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: isDark ? 0.16 : 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: statusColor.withValues(alpha: isDark ? 0.8 : 0.6),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      statusLabel,
                      style: GoogleFonts.inter(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (booking.isCheckedIn)
                    const Icon(Icons.check_circle, size: 12, color: Color(0xFF3B82F6)),
                ],
              ),

              Text(
                booking.guestName.isNotEmpty ? booking.guestName : 'Guest Player',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '₱${booking.totalPrice.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                  if (hasBalance)
                    Text(
                      'Bal: ₱${booking.remainingBalance.toStringAsFixed(0)}',
                      style: GoogleFonts.inter(
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFEF4444),
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

  // --- AVAILABLE SLOT TILE ---
  Widget _buildAvailableTile(CourtModel court, int hour, dynamic colors, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openWalkInModal(courtId: court.id, hour: hour),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF1E293B).withValues(alpha: 0.5)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add,
                  size: 13,
                  color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                ),
                const SizedBox(width: 3),
                Text(
                  'Book',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- BOOKING DETAILS & ACTION MODAL ---
  void _openBookingDetailsModal(BookingModel booking) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = _getStatusColor(booking.status);
    final statusLabel = _getStatusLabel(booking.status);
    final hasBalance = booking.remainingBalance > 0.01;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusLabel,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  booking.guestName.isNotEmpty ? booking.guestName : 'Guest Player',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildModalDetailRow('Court:', booking.displayCourtName, colors),
                _buildModalDetailRow(
                  'Schedule:',
                  '${DateFormat('MMM dd, yyyy').format(booking.startTime)} • ${timeFmt.format(booking.startTime)} - ${timeFmt.format(booking.endTime)}',
                  colors,
                ),
                _buildModalDetailRow('Duration:', '${booking.durationHours} hr(s)', colors),
                _buildModalDetailRow('Payment Mode:', booking.paymentMethod.toUpperCase(), colors),
                _buildModalDetailRow('Total Price:', '₱${booking.totalPrice.toStringAsFixed(2)}', colors),
                if (booking.downPaymentAmount > 0)
                  _buildModalDetailRow('Down Payment:', '₱${booking.downPaymentAmount.toStringAsFixed(2)}', colors),
                if (hasBalance)
                  _buildModalDetailRow('Remaining Bal:', '₱${booking.remainingBalance.toStringAsFixed(2)}', colors, isAlert: true),
                if (booking.guestPhone.isNotEmpty)
                  _buildModalDetailRow('Contact Phone:', booking.guestPhone, colors),
                if (booking.notes != null && booking.notes!.isNotEmpty)
                  _buildModalDetailRow('Staff Notes:', booking.notes!, colors),
              ],
            ),
          ),
          actions: [
            // Check-in action button
            if (!booking.isCheckedIn && booking.status != 'cancelled')
              ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: const Text('Check In Player'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  HapticFeedback.mediumImpact();
                  await _posService.checkInBooking(booking.id);
                  if (mounted) {
                    AppSnackBar.success(context, '${booking.guestName} marked as CHECKED-IN.');
                    _loadScheduleData(isSilent: true);
                  }
                },
              ),

            // Collect balance button
            if (hasBalance && booking.status != 'cancelled')
              ElevatedButton.icon(
                icon: const Icon(Icons.payment, size: 16),
                label: Text('Collect Bal (₱${booking.remainingBalance.toStringAsFixed(0)})'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _openCollectBalanceModal(booking);
                },
              ),

            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Close', style: GoogleFonts.inter(color: colors.textSecondary)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildModalDetailRow(String label, String value, dynamic colors, {bool isAlert = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 12, color: colors.textSecondary, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: isAlert ? const Color(0xFFEF4444) : colors.textPrimary,
                fontWeight: isAlert ? FontWeight.w800 : FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WALK-IN BOOKING CREATION MODAL ---
  void _openWalkInModal({String? courtId, int? hour}) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final initialCourtId = courtId ?? (_courts.isNotEmpty ? _courts.first.id : '');
    final initialHour = hour ?? (DateTime.now().hour < 22 ? DateTime.now().hour + 1 : 18);

    String selectedCourtId = initialCourtId;
    int selectedHour = initialHour.clamp(6, 22);
    int selectedDuration = 1;
    String guestName = '';
    String guestPhone = '';
    String paymentMethod = 'Cash';
    bool isDownPaymentOnly = false;
    double customDownPayment = 0.0;
    String? validationMsg;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setModalState) {
            final targetCourt = _courts.firstWhere(
              (c) => c.id == selectedCourtId,
              orElse: () => _courts.first,
            );
            final totalPrice = targetCourt.hourlyRate * selectedDuration;
            final downPayment = isDownPaymentOnly ? (customDownPayment > 0 ? customDownPayment : (totalPrice * 0.5)) : totalPrice;

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.flash_on_rounded, color: Color(0xFF10B981), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cashier Walk-in Reservation',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Court Selector
                      Text('Court Selection', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: colors.textSecondary)),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        initialValue: selectedCourtId,
                        isExpanded: true,
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: _courts.map((c) {
                          return DropdownMenuItem(
                            value: c.id,
                            child: Text(
                              '${c.name} (₱${c.hourlyRate.toStringAsFixed(0)}/hr)',
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(fontSize: 12, color: colors.textPrimary),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setModalState(() => selectedCourtId = val);
                        },
                      ),
                      const SizedBox(height: 12),

                      // Time Slot & Duration
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Start Time', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: colors.textSecondary)),
                                const SizedBox(height: 4),
                                DropdownButtonFormField<int>(
                                  initialValue: selectedHour,
                                  isExpanded: true,
                                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  items: List.generate(17, (i) => i + 6).map((h) {
                                    return DropdownMenuItem(
                                      value: h,
                                      child: Text(
                                        DateFormat('hh:00 a').format(DateTime(2026, 1, 1, h)),
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(fontSize: 12, color: colors.textPrimary),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) setModalState(() => selectedHour = val);
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Duration', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: colors.textSecondary)),
                                const SizedBox(height: 4),
                                DropdownButtonFormField<int>(
                                  initialValue: selectedDuration,
                                  isExpanded: true,
                                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  items: [1, 2, 3, 4].map((d) {
                                    return DropdownMenuItem(
                                      value: d,
                                      child: Text('$d hr(s)', overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 12, color: colors.textPrimary)),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) setModalState(() => selectedDuration = val);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Guest Name
                      Text('Guest Player Name *', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: colors.textSecondary)),
                      const SizedBox(height: 4),
                      TextFormField(
                        initialValue: guestName,
                        style: GoogleFonts.inter(fontSize: 12, color: colors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'e.g. Juan dela Cruz',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onChanged: (v) => guestName = v,
                      ),
                      const SizedBox(height: 10),

                      // Guest Phone
                      Text('Guest Contact Number', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: colors.textSecondary)),
                      const SizedBox(height: 4),
                      TextFormField(
                        initialValue: guestPhone,
                        keyboardType: TextInputType.phone,
                        style: GoogleFonts.inter(fontSize: 12, color: colors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'e.g. +63 917 123 4567',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onChanged: (v) => guestPhone = v,
                      ),
                      const SizedBox(height: 12),

                      // Payment Method
                      Text('Payment Method', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: colors.textSecondary)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(child: Text('Cash')),
                              selected: paymentMethod == 'Cash',
                              onSelected: (_) => setModalState(() => paymentMethod = 'Cash'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(child: Text('GCash / QR Ph')),
                              selected: paymentMethod == 'GCash / QR Ph',
                              onSelected: (_) => setModalState(() => paymentMethod = 'GCash / QR Ph'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Full vs Down Payment Toggle
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Down Payment Only (50%)',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textPrimary),
                          ),
                          Switch(
                            value: isDownPaymentOnly,
                            activeTrackColor: const Color(0xFF10B981),
                            onChanged: (v) => setModalState(() => isDownPaymentOnly = v),
                          ),
                        ],
                      ),

                      // Total Price Summary Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Total Amount:', style: GoogleFonts.inter(fontSize: 11, color: colors.textSecondary)),
                                Text(
                                  '₱${totalPrice.toStringAsFixed(2)}',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w900, color: colors.textPrimary),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  isDownPaymentOnly ? 'Tender Now (50%):' : 'Tender Now (Full):',
                                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF10B981), fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  '₱${downPayment.toStringAsFixed(2)}',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF10B981)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      if (validationMsg != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          validationMsg!,
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.redAccent),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('Cancel', style: GoogleFonts.inter(color: colors.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (guestName.trim().isEmpty) {
                      setModalState(() => validationMsg = 'Guest Name is required for walk-in booking.');
                      return;
                    }

                    Navigator.of(ctx).pop();
                    HapticFeedback.mediumImpact();

                    final startDt = DateTime(
                      _selectedDate.year,
                      _selectedDate.month,
                      _selectedDate.day,
                      selectedHour,
                    );

                    try {
                      await _posService.createWalkInBooking(
                        courtId: selectedCourtId,
                        startTime: startDt,
                        durationHours: selectedDuration,
                        totalPrice: totalPrice,
                        guestName: guestName.trim(),
                        guestPhone: guestPhone.trim(),
                        paymentMethod: paymentMethod,
                        cashierId: widget.cashierId,
                        downPaymentAmount: downPayment,
                      );
                      if (mounted) {
                        AppSnackBar.success(context, 'Walk-in booking confirmed for $guestName!');
                        _loadScheduleData(isSilent: true);
                      }
                    } catch (e) {
                      if (mounted) {
                        AppSnackBar.error(context, 'Booking creation error: $e');
                      }
                    }
                  },
                  child: const Text('Confirm Walk-In'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- COLLECT BALANCE MODAL ---
  void _openCollectBalanceModal(BookingModel booking) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String paymentMethod = 'Cash';

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Collect Remaining Balance',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Player: ${booking.guestName}',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: colors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'Amount to Collect: ₱${booking.remainingBalance.toStringAsFixed(2)}',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFF10B981)),
              ),
              const SizedBox(height: 14),
              Text('Payment Mode:', style: GoogleFonts.inter(fontSize: 11, color: colors.textSecondary)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: paymentMethod,
                isExpanded: true,
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: ['Cash', 'GCash / QR Ph', 'Card'].map((m) {
                  return DropdownMenuItem(value: m, child: Text(m, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 12, color: colors.textPrimary)));
                }).toList(),
                onChanged: (v) {
                  if (v != null) paymentMethod = v;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: GoogleFonts.inter(color: colors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.of(ctx).pop();
                HapticFeedback.mediumImpact();
                await _posService.collectBookingBalance(
                  bookingId: booking.id,
                  amountPaid: booking.remainingBalance,
                  paymentMethod: paymentMethod,
                );
                if (mounted) {
                  AppSnackBar.success(context, 'Balance of ₱${booking.remainingBalance.toStringAsFixed(2)} recorded!');
                  _loadScheduleData(isSilent: true);
                }
              },
              child: const Text('Confirm Payment'),
            ),
          ],
        );
      },
    );
  }
}
