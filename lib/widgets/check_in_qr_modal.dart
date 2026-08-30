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

class _CheckInQrModalState extends State<CheckInQrModal> {
  late String _checkInStatus;
  late DateTime? _checkInTime;
  late DateTime? _checkOutTime;

  @override
  void initState() {
    super.initState();
    _checkInStatus = widget.booking.status.toLowerCase() == 'checked_in'
        ? 'checked_in'
        : (widget.booking.status.toLowerCase() == 'completed' ? 'completed' : 'upcoming');
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final booking = widget.booking;
    final courtName = booking.courtName ?? 'SmashCourt - Court 1';
    final timeFormat = DateFormat('h:mm a');

    Color statusColor = colors.neonGreen;
    String statusText = 'UPCOMING - READY FOR CHECK-IN';

    if (_checkInStatus == 'checked_in') {
      statusColor = colors.neonYellow;
      statusText = 'CHECKED IN • SESSION IN PROGRESS';
    } else if (_checkInStatus == 'completed') {
      statusColor = colors.textMuted;
      statusText = 'CHECKED OUT • SESSION COMPLETED';
    }

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
          const SizedBox(height: 20),

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
          const SizedBox(height: 16),

          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(25),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withAlpha(80)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
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
          ),
          const SizedBox(height: 20),

          // Visual Dynamic QR Display
          Container(
            padding: const EdgeInsets.all(16),
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
                  width: 180,
                  height: 180,
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
                          size: 130,
                        ),
                        Text(
                          'PASS CODE: ${booking.id.substring(0, booking.id.length > 8 ? 8 : booking.id.length).toUpperCase()}',
                          style: GoogleFonts.robotoMono(
                            color: Colors.white70,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

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
                      color: colors.neonGreen,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

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
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
