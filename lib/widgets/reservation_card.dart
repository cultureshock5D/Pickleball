import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/snackbar_helper.dart';
import '../core/utils/validators.dart';
import '../models/booking_model.dart';
import '../services/booking_service.dart';
import '../services/calendar_link_service.dart';
import 'booking_success_modal.dart';
import 'check_in_qr_modal.dart';
import 'downloadable_receipt_modal.dart';

class ReservationCard extends StatefulWidget {
  final BookingModel booking;
  final bool isUpcoming;
  final VoidCallback? onRefresh;

  const ReservationCard({
    super.key,
    required this.booking,
    this.isUpcoming = true,
    this.onRefresh,
  });

  @override
  State<ReservationCard> createState() => _ReservationCardState();
}

class _ReservationCardState extends State<ReservationCard>
    with SingleTickerProviderStateMixin {
  bool _isAddingToCalendar = false;
  bool _isCancelling = false;
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;

  static final DateFormat _monthDayYearFormat = DateFormat('MMMM d, y');
  static final DateFormat _fullDayFormat = DateFormat('EEEE, MMMM d, y');

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.95,
      value: 1.0,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _pressController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  String _formatDateHeader(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final target = DateTime(dt.year, dt.month, dt.day);

    if (target == today) {
      return 'Today • ${_monthDayYearFormat.format(dt)}';
    } else if (target == tomorrow) {
      return 'Tomorrow • ${_monthDayYearFormat.format(dt)}';
    }
    return _fullDayFormat.format(dt);
  }

  String _formatTimeSlot(DateTime start, DateTime end) {
    return Validators.formatTimeSlotRange(start, end);
  }

  Future<void> _handleAddToCalendar() async {
    HapticFeedback.lightImpact();
    _pressController.forward(from: 0.95);
    setState(() => _isAddingToCalendar = true);
    try {
      await CalendarLinkService.addBookingToCalendar(
        widget.booking,
        context: context,
      );
    } finally {
      if (mounted) {
        setState(() => _isAddingToCalendar = false);
      }
    }
  }

  void _openDetailsModal() {
    HapticFeedback.selectionClick();
    BookingSuccessModal.show(
      context,
      booking: widget.booking,
    );
  }

  void _openCheckInQrModal() {
    HapticFeedback.mediumImpact();
    CheckInQrModal.show(context, booking: widget.booking);
  }

  void _openReceiptModal() {
    HapticFeedback.lightImpact();
    DownloadableReceiptModal.show(context, booking: widget.booking);
  }

  Future<void> _openRefundDialog() async {
    final colors = context.colors;
    final booking = widget.booking;

    String selectedWallet = 'gcash';
    final nameController = TextEditingController(text: booking.guestName);
    final accountController = TextEditingController(text: booking.guestPhone);
    final reasonController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Request Booking Refund',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'C&J 24-Hour Policy: Cancellations are permitted 24+ hours in advance. Amount: ₱${booking.totalPrice.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Select E-Wallet / Bank',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _walletChip('GCash', 'gcash', selectedWallet, (v) {
                      setModalState(() => selectedWallet = v);
                    }, colors),
                    _walletChip('Maya', 'maya', selectedWallet, (v) {
                      setModalState(() => selectedWallet = v);
                    }, colors),
                    _walletChip('Bank Transfer', 'bank_transfer', selectedWallet, (v) {
                      setModalState(() => selectedWallet = v);
                    }, colors),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Account Holder Name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: accountController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Account Number / Mobile',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: reasonController,
                  decoration: InputDecoration(
                    labelText: 'Reason for Cancellation (Optional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.neonGreen,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () async {
                      if (nameController.text.trim().isEmpty ||
                          accountController.text.trim().isEmpty) {
                        AppSnackBar.error(
                          ctx,
                          'Please provide account name and number.',
                        );
                        return;
                      }

                      Navigator.of(ctx).pop();
                      setState(() => _isCancelling = true);

                      try {
                        await BookingService.instance.requestRefund(
                          bookingId: booking.id,
                          amount: booking.totalPrice,
                          walletType: selectedWallet,
                          accountName: nameController.text.trim(),
                          accountNumber: accountController.text.trim(),
                          reason: reasonController.text.trim(),
                        );
                        if (mounted) {
                          AppSnackBar.success(
                            context,
                            'Refund request submitted for admin review.',
                          );
                          widget.onRefresh?.call();
                        }
                      } catch (e) {
                        if (mounted) {
                          AppSnackBar.error(context, e.toString());
                        }
                      } finally {
                        if (mounted) {
                          setState(() => _isCancelling = false);
                        }
                      }
                    },
                    child: Text(
                      'Confirm Refund Request (₱${booking.totalPrice.toStringAsFixed(2)})',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _walletChip(
    String label,
    String value,
    String selected,
    ValueChanged<String> onSelected,
    AppPalette colors,
  ) {
    final isSel = selected == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSel,
      selectedColor: colors.neonGreenAlpha15,
      side: BorderSide(
        color: isSel ? colors.neonGreen : colors.borderSubtle,
      ),
      labelStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
        color: isSel ? colors.neonGreen : colors.textSecondary,
      ),
      onSelected: (_) => onSelected(value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final booking = widget.booking;
    final status = booking.status.toLowerCase();

    Color statusColor = colors.neonGreen;
    String statusLabel = 'CONFIRMED';

    if (status == 'pending_payment') {
      statusColor = colors.neonYellow;
      statusLabel = 'PENDING';
    } else if (status == 'paid') {
      statusColor = colors.neonGreen;
      statusLabel = 'PAID';
    } else if (status == 'confirmed') {
      statusColor = colors.neonGreen;
      statusLabel = 'CONFIRMED';
    } else if (status == 'checked_in') {
      statusColor = Colors.amber;
      statusLabel = 'CHECKED IN';
    } else if (status == 'cancelled_refund_pending') {
      statusColor = Colors.orange;
      statusLabel = 'REFUND PENDING';
    } else if (status == 'cancelled') {
      statusColor = colors.errorRed;
      statusLabel = 'CANCELLED';
    } else if (status == 'expired') {
      statusColor = colors.textMuted;
      statusLabel = 'EXPIRED';
    } else if (status == 'completed') {
      statusColor = colors.textMuted;
      statusLabel = 'COMPLETED';
    }

    final courtName = booking.displayCourtName;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: widget.isUpcoming
                ? colors.borderSubtle
                : colors.borderSubtleAlpha50,
            width: 1.2,
          ),
          boxShadow: widget.isUpcoming ? colors.cardShadow : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTapDown: (_) => _pressController.reverse(),
            onTapUp: (_) => _pressController.forward(),
            onTapCancel: () => _pressController.forward(),
            onTap: _openDetailsModal,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Date Header & Status Pill
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            color: widget.isUpcoming
                                ? colors.neonGreen
                                : colors.textMuted,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formatDateHeader(booking.startTime),
                            style: GoogleFonts.inter(
                              color: widget.isUpcoming
                                  ? colors.textPrimary
                                  : colors.textMuted,
                              fontSize: 12.5,
                              fontWeight: widget.isUpcoming
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          if (widget.isUpcoming && booking.isPaid) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: colors.neonLimeAlpha15,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: colors.neonLime,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'PASS READY',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: colors.neonLime,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withAlpha(35),
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: statusColor.withAlpha(70)),
                            ),
                            child: Text(
                              statusLabel,
                              style: GoogleFonts.plusJakartaSans(
                                color: statusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 2. Court Badge & Price Info
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: booking.isPaid
                              ? colors.neonGreenAlpha12
                              : colors.surfaceHighlight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: booking.isPaid
                                ? colors.neonGreenAlpha40
                                : colors.borderSubtle,
                          ),
                        ),
                        child: Icon(
                          Icons.sports_tennis_rounded,
                          color: booking.isPaid
                              ? colors.neonGreen
                              : colors.textSecondary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              courtName,
                              style: GoogleFonts.plusJakartaSans(
                                color: colors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatTimeSlot(
                                  booking.startTime, booking.endTime),
                              style: GoogleFonts.inter(
                                color: colors.textMuted,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₱${booking.totalPrice.toStringAsFixed(2)}',
                            style: GoogleFonts.plusJakartaSans(
                              color: status == 'completed' || status == 'cancelled'
                                  ? colors.textMuted
                                  : colors.neonLime,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            booking.id.length > 8
                                ? '${booking.id.substring(0, 8)}...'
                                : booking.id,
                            style: GoogleFonts.robotoMono(
                              color: colors.textMuted,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // 3. Quick Action Buttons
                  const SizedBox(height: 12),
                  Divider(color: colors.borderSubtle, height: 1),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      // QR Pass Action
                      if (booking.isPaid || booking.isCheckedIn) ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 8),
                              side: BorderSide(color: colors.neonGreenAlpha50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: _openCheckInQrModal,
                            icon: Icon(Icons.qr_code_2_rounded,
                                size: 16, color: colors.neonGreen),
                            label: Text(
                              'Gate Pass',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: colors.neonGreen,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],

                      // Receipt Action
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 8),
                            side: BorderSide(color: colors.borderSubtle),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _openReceiptModal,
                          icon: Icon(Icons.receipt_long_rounded,
                              size: 16, color: colors.textSecondary),
                          label: Text(
                            'Receipt',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      ),

                      // Cancel / Refund Button if 24h eligible
                      if (widget.isUpcoming && booking.isCancellable) ...[
                        const SizedBox(width: 8),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 10),
                            side: BorderSide(color: colors.errorRedAlpha30),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _isCancelling ? null : _openRefundDialog,
                          child: Text(
                            'Cancel / Refund',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: colors.errorRed,
                            ),
                          ),
                        ),
                      ],

                      if (widget.isUpcoming && booking.isPaid) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          style: IconButton.styleFrom(
                            minimumSize: const Size(48, 48),
                            backgroundColor: colors.neonGreenAlpha12,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(color: colors.neonGreenAlpha40),
                            ),
                          ),
                          onPressed: _isAddingToCalendar
                              ? null
                              : _handleAddToCalendar,
                          icon: _isAddingToCalendar
                              ? SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        colors.neonGreen),
                                  ),
                                )
                              : Icon(Icons.event_available_rounded,
                                  size: 18, color: colors.neonGreen),
                          tooltip: 'Add to Calendar',
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
