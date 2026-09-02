import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import '../models/booking_model.dart';

class CheckInQrModal extends StatefulWidget {
  final BookingModel booking;

  const CheckInQrModal({
    super.key,
    required this.booking,
  });

  static Future<void> show(BuildContext context, {required BookingModel booking}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CheckInQrModal(booking: booking),
    );
  }

  @override
  State<CheckInQrModal> createState() => _CheckInQrModalState();
}

class _CheckInQrModalState extends State<CheckInQrModal>
    with SingleTickerProviderStateMixin {
  late String _checkInStatus;
  late DateTime? _checkInTime;
  late DateTime? _checkOutTime;
  Timer? _timer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _checkInStatus = widget.booking.status.toLowerCase() == 'checked_in'
        ? 'checked_in'
        : (widget.booking.status.toLowerCase() == 'completed' ? 'completed' : 'upcoming');
    _checkInTime = _checkInStatus == 'checked_in' ? DateTime.now() : null;
    _checkOutTime = _checkInStatus == 'completed' ? DateTime.now() : null;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _toggleCheckInState() {
    setState(() {
      if (_checkInStatus == 'upcoming') {
        _checkInStatus = 'checked_in';
        _checkInTime = DateTime.now();
      } else if (_checkInStatus == 'checked_in') {
        _checkInStatus = 'completed';
        _checkOutTime = DateTime.now();
      } else {
        _checkInStatus = 'upcoming';
        _checkInTime = null;
        _checkOutTime = null;
      }
    });
  }

  String _formatCountdown() {
    final booking = widget.booking;
    if (_checkInStatus == 'checked_in') {
      final diff = booking.endTime.difference(_now);
      if (diff.isNegative) {
        final overtime = _now.difference(booking.endTime);
        return 'Overtime: +${overtime.inMinutes}m ${overtime.inSeconds % 60}s';
      }
      final mins = diff.inMinutes;
      final secs = diff.inSeconds % 60;
      return 'Session Ends in: ${mins}m ${secs}s';
    } else if (_checkInStatus == 'upcoming') {
      final diff = booking.startTime.difference(_now);
      if (diff.isNegative) {
        return 'Session Ready • Gate Scanning Open';
      }
      final hours = diff.inHours;
      final mins = diff.inMinutes % 60;
      final secs = diff.inSeconds % 60;
      if (hours > 0) {
        return 'Starts in: ${hours}h ${mins}m';
      }
      return 'Starts in: ${mins}m ${secs}s';
    }
    return 'Court Session Concluded';
  }

  String _generateRollingToken() {
    final seed = (_now.millisecondsSinceEpoch ~/ 30000).toRadixString(16).toUpperCase();
    final idPart = widget.booking.id.length >= 6
        ? widget.booking.id.substring(0, 6).toUpperCase()
        : widget.booking.id.toUpperCase();
    return 'PKL-$idPart-$seed';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final booking = widget.booking;
    final courtName = booking.courtName ?? 'SmashCourt - Court 1';
    final timeFormat = DateFormat('h:mm a');

    Color statusColor = colors.neonGreen;
    String statusText = 'UPCOMING • READY FOR GATE';

    if (_checkInStatus == 'checked_in') {
      statusColor = Colors.amber;
      statusText = 'CHECKED IN • SESSION ACTIVE';
    } else if (_checkInStatus == 'completed') {
      statusColor = colors.textMuted;
      statusText = 'CHECKED OUT • CONCLUDED';
    }

    final countdownText = _formatCountdown();
    final rollingToken = _generateRollingToken();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colors.textMuted.withAlpha(80),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),

          // Header Title
          Text(
            'Smart Court Gate QR Pass',
            style: GoogleFonts.inter(
              color: colors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            courtName,
            style: GoogleFonts.inter(
              color: colors.neonGreen,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),

          // Live Animated Status Badge
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha((25 * _pulseAnimation.value).toInt()),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: statusColor.withAlpha((180 * _pulseAnimation.value).toInt()),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(_pulseAnimation.value),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: statusColor.withOpacity(0.6 * _pulseAnimation.value),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      statusText,
                      style: GoogleFonts.inter(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          // Countdown Timer Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colors.surfaceHighlight.withAlpha(120),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.borderSubtle),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer_outlined, size: 14, color: colors.neonLime),
                const SizedBox(width: 6),
                Text(
                  countdownText,
                  style: GoogleFonts.robotoMono(
                    color: colors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Visual Dynamic QR Display
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: colors.neonGreen.withAlpha(40),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                // Simulated QR Graphic
                Container(
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.qr_code_2_rounded,
                          color: Colors.white,
                          size: 120,
                        ),
                        Text(
                          rollingToken,
                          style: GoogleFonts.robotoMono(
                            color: Colors.white70,
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_rounded, size: 10, color: Colors.black54),
                    const SizedBox(width: 4),
                    Text(
                      'Auto-refreshes every 30s • Offline Cached',
                      style: GoogleFonts.inter(
                        color: Colors.black54,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Booking Slot Details
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  Text(
                    'Reserved Slot',
                    style: GoogleFonts.inter(color: colors.textMuted, fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${timeFormat.format(booking.startTime)} - ${timeFormat.format(booking.endTime)}',
                    style: GoogleFonts.inter(
                      color: colors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Container(width: 1, height: 28, color: colors.borderSubtle),
              Column(
                children: [
                  Text(
                    'Pass Status',
                    style: GoogleFonts.inter(color: colors.textMuted, fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _checkInStatus.replaceAll('_', ' ').toUpperCase(),
                    style: GoogleFonts.inter(
                      color: statusColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Interactive Check-In/Check-Out Action Toggle
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: statusColor,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _toggleCheckInState,
              icon: Icon(
                _checkInStatus == 'upcoming'
                    ? Icons.login_rounded
                    : (_checkInStatus == 'checked_in' ? Icons.logout_rounded : Icons.refresh_rounded),
              ),
              label: Text(
                _checkInStatus == 'upcoming'
                    ? 'Simulate Gate Scan (Check-In)'
                    : (_checkInStatus == 'checked_in' ? 'Simulate Gate Scan (Check-Out)' : 'Reset Gate Status'),
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
