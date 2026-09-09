import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/utils/validators.dart';
import '../../models/booking_model.dart';
import '../../models/court_model.dart';
import '../../services/auth_service.dart';
import '../../services/booking_service.dart';
import '../../widgets/booking_success_modal.dart';
import '../../widgets/neon_button.dart';

class BookingReviewScreen extends StatefulWidget {
  final CourtModel court;
  final String venueName;
  final DateTime startTime;
  final DateTime endTime;
  final double durationHours;
  final double totalAmount;
  final bool paddleRental;
  final bool ballThrowerRental;
  final int playerCount;
  final VoidCallback? onViewBookings;

  const BookingReviewScreen({
    super.key,
    required this.court,
    this.venueName = 'C&J Pickleball Court',
    required this.startTime,
    required this.endTime,
    required this.durationHours,
    required this.totalAmount,
    this.paddleRental = false,
    this.ballThrowerRental = false,
    this.playerCount = 4,
    this.onViewBookings,
  });

  @override
  State<BookingReviewScreen> createState() => _BookingReviewScreenState();
}

class _BookingReviewScreenState extends State<BookingReviewScreen> {
  final BookingService _bookingService = BookingService.instance;
  final AuthService _authService = AuthService.instance;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool _isSubmitting = false;
  int _selectedPaymentMethodIndex = 0;

  final List<Map<String, dynamic>> _paymentMethods = [
    {
      'title': 'GCash via PayMongo',
      'subtitle': 'Instant Mobile Wallet Checkout',
      'icon': Icons.account_balance_wallet_rounded,
      'isDefault': true,
    },
    {
      'title': 'Maya via PayMongo',
      'subtitle': 'Maya Digital Card & Wallet',
      'icon': Icons.wallet_rounded,
      'isDefault': false,
    },
    {
      'title': 'GrabPay via PayMongo',
      'subtitle': 'Instant GrabPay Gateway',
      'icon': Icons.send_to_mobile_rounded,
      'isDefault': false,
    },
    {
      'title': 'Credit / Debit Card via PayMongo',
      'subtitle': 'Visa, Mastercard & JCB',
      'icon': Icons.credit_card_rounded,
      'isDefault': false,
    },
    {
      'title': 'Club Membership Card',
      'subtitle': 'Prepaid Luxury Account Balance',
      'icon': Icons.card_membership_rounded,
      'isDefault': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    final profile = await _authService.fetchUserProfile();
    if (profile != null && mounted) {
      setState(() {
        if (profile.fullName != null && profile.fullName!.isNotEmpty) {
          _nameController.text = profile.fullName!;
        }
        if (profile.email != null && profile.email!.isNotEmpty) {
          _emailController.text = profile.email!;
        }
        if (profile.phone != null && profile.phone!.isNotEmpty) {
          _phoneController.text = profile.phone!;
        }
      });
    }
  }

  String _formatDateFull(DateTime dt) {
    return DateFormat('EEEE, MMMM d, y').format(dt);
  }

  Future<void> _handleConfirmBooking() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty) {
      AppSnackBar.error(context, 'Please provide guest/player name.');
      return;
    }
    if (email.isNotEmpty && Validators.validateEmail(email) != null) {
      AppSnackBar.error(context, 'Please provide a valid email address.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // 1. Create PayMongo Live Checkout Session directly
      String? sessionId;
      String? checkoutUrl;

      final methodMap = {
        0: ['gcash'],
        1: ['paymaya'],
        2: ['grab_pay'],
        3: ['card'],
        4: ['gcash', 'paymaya', 'card'],
      };
      final selectedMethods = methodMap[_selectedPaymentMethodIndex] ??
          ['gcash', 'paymaya', 'grab_pay', 'card'];

      try {
        final checkoutData = await _bookingService.createPayMongoCheckoutSession(
          courtId: widget.court.id,
          courtName: widget.court.name,
          hourlyRate: widget.court.hourlyRate,
          durationHours: widget.durationHours.round(),
          guestName: name,
          guestEmail: email,
          guestPhone: phone,
          paddleRental: widget.paddleRental,
          ballThrowerRental: widget.ballThrowerRental,
          selectedPaymentMethods: selectedMethods,
        );

        sessionId = checkoutData['sessionId'] as String?;
        checkoutUrl = checkoutData['checkoutUrl'] as String?;
      } catch (e) {
        debugPrint('PayMongo Live Checkout API Notice: $e');
      }

      // 2. Create pending booking in Supabase
      final booking = await _bookingService.createBooking(
        courtId: widget.court.id,
        startTime: widget.startTime,
        endTime: widget.endTime,
        totalAmount: widget.totalAmount,
        guestName: name,
        guestEmail: email,
        guestPhone: phone,
        paymongoCheckoutSessionId: sessionId,
        notes: [
          if (widget.paddleRental) 'Paddle Rental (2x Paddles, 3x Balls)',
          if (widget.ballThrowerRental) 'Ball Thrower Machine',
        ].join(', '),
      );

      // 3. Launch PayMongo Checkout URL in external browser first
      if (checkoutUrl != null && checkoutUrl.isNotEmpty) {
        final uri = Uri.parse(checkoutUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }

      if (mounted) {
        // 4. Show Awaiting Payment Modal bottom sheet
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          isDismissible: false,
          enableDrag: false,
          backgroundColor: Colors.transparent,
          barrierColor: Colors.black54,
          builder: (ctx) => _AwaitingPaymentModal(
            booking: booking,
            sessionId: sessionId,
            checkoutUrl: checkoutUrl,
            venueName: widget.venueName,
            onViewBookings: widget.onViewBookings,
            onPaymentConfirmed: (paidBooking) {
              Navigator.of(context).pop(); // pop ReviewScreen
              BookingSuccessModal.show(
                context,
                booking: paidBooking,
                onViewBookings: widget.onViewBookings,
                venueName: widget.venueName,
              );
            },
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().replaceAll('Exception: ', '');
        AppSnackBar.error(context, errorMsg);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;
    final courtSubtotal = widget.court.hourlyRate * widget.durationHours;
    final paddleFee = widget.paddleRental ? BookingService.paddleRentalFee : 0.0;
    final ballThrowerFee = widget.ballThrowerRental
        ? (BookingService.ballThrowerHourlyFee * widget.durationHours)
        : 0.0;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surfaceElevated,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: colors.textPrimary, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Review & Confirm',
          style: GoogleFonts.plusJakartaSans(
            color: colors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Court Details Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: colors.neonGreenAlpha15,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.court.type.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: colors.neonGreen,
                          ),
                        ),
                      ),
                      Text(
                        '₱${widget.court.hourlyRate.toStringAsFixed(0)}/hr',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: colors.neonLime,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.court.name,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.venueName,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Divider(color: colors.borderSubtle, height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 14, color: colors.neonGreen),
                      const SizedBox(width: 8),
                      Text(
                        _formatDateFull(widget.startTime),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded,
                          size: 14, color: colors.neonLime),
                      const SizedBox(width: 8),
                      Text(
                        '${DateFormat('h:mm a').format(widget.startTime)} - ${DateFormat('h:mm a').format(widget.endTime)} (${widget.durationHours.toStringAsFixed(0)} hr)',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Guest Info Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PLAYER / GUEST DETAILS',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: colors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name *',
                      prefixIcon: const Icon(Icons.person_outline_rounded, size: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: const Icon(Icons.email_outlined, size: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: const Icon(Icons.phone_outlined, size: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. Transparent Price Breakdown Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Price Breakdown',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildPriceRow(
                    'Court Fee (${widget.durationHours.toStringAsFixed(0)}h × ₱${widget.court.hourlyRate.toStringAsFixed(0)})',
                    '₱${courtSubtotal.toStringAsFixed(2)}',
                    colors,
                  ),
                  if (widget.paddleRental) ...[
                    const SizedBox(height: 8),
                    _buildPriceRow(
                      'Paddle Bundle (2x Paddles + 3x Balls)',
                      '+₱${paddleFee.toStringAsFixed(2)}',
                      colors,
                      highlight: true,
                    ),
                  ],
                  if (widget.ballThrowerRental) ...[
                    const SizedBox(height: 8),
                    _buildPriceRow(
                      'Ball Thrower Machine (${widget.durationHours.toStringAsFixed(0)}h × ₱150)',
                      '+₱${ballThrowerFee.toStringAsFixed(2)}',
                      colors,
                      highlight: true,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Divider(color: colors.borderSubtle, height: 1),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Amount',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        '₱${widget.totalAmount.toStringAsFixed(2)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 4. Payment Method Selector (PayMongo)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PAYMENT METHOD (PAYMONGO)',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: colors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _paymentMethods.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final method = _paymentMethods[index];
                      final isSelected = _selectedPaymentMethodIndex == index;

                      return InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedPaymentMethodIndex = index);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark ? colors.neonGreenAlpha15 : colors.surfaceElevated)
                                : colors.surfaceHighlight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? (isDark ? colors.neonGreen : colors.textPrimary)
                                  : colors.borderSubtle,
                              width: isSelected ? 1.8 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                method['icon'] as IconData,
                                size: 20,
                                color: isSelected
                                    ? (isDark ? colors.neonGreen : colors.textPrimary)
                                    : colors.textSecondary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      method['title'] as String,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      method['subtitle'] as String,
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: colors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? (isDark ? colors.neonGreen : colors.textPrimary)
                                        : colors.borderSubtle,
                                    width: isSelected ? 5.5 : 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 5. Confirm & Lock Button
            NeonButton(
              text: 'Confirm & Pay via PayMongo',
              onPressed: _handleConfirmBooking,
              isLoading: _isSubmitting,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(
    String label,
    String value,
    AppPalette colors, {
    bool highlight = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              color: highlight ? colors.textPrimary : colors.textSecondary,
              fontWeight: highlight ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: highlight ? colors.textPrimary : colors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _AwaitingPaymentModal extends StatefulWidget {
  final BookingModel booking;
  final String? sessionId;
  final String? checkoutUrl;
  final String venueName;
  final VoidCallback? onViewBookings;
  final ValueChanged<BookingModel> onPaymentConfirmed;

  const _AwaitingPaymentModal({
    required this.booking,
    this.sessionId,
    this.checkoutUrl,
    required this.venueName,
    this.onViewBookings,
    required this.onPaymentConfirmed,
  });

  @override
  State<_AwaitingPaymentModal> createState() => _AwaitingPaymentModalState();
}

class _AwaitingPaymentModalState extends State<_AwaitingPaymentModal> {
  final BookingService _bookingService = BookingService.instance;
  Timer? _pollTimer;
  bool _isChecking = false;
  bool _isPaymentCompleted = false;

  @override
  void initState() {
    super.initState();
    // Poll every 2.5 seconds for payment reflection
    _pollTimer = Timer.periodic(
      const Duration(milliseconds: 2500),
      (_) => _checkPaymentStatus(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkPaymentStatus({bool isManual = false}) async {
    if (_isPaymentCompleted) return;
    if (_isChecking) return;

    if (mounted && isManual) {
      setState(() => _isChecking = true);
    }

    try {
      bool isPaid = false;

      // 1. Direct PayMongo REST API check
      if (widget.sessionId != null && widget.sessionId!.isNotEmpty) {
        try {
          final res = await _bookingService.getPayMongoSessionStatus(widget.sessionId!);
          if (res['isPaid'] == true || res['status'] == 'paid') {
            isPaid = true;
          }
        } catch (e) {
          debugPrint('Status check error: $e');
        }
      }

      // 2. Also check Supabase booking record
      if (!isPaid) {
        final polled = await _bookingService.pollBookingPaidStatus(
          widget.booking.id,
          maxAttempts: 1,
        );
        if (polled != null && (polled.isPaid || polled.isCheckedIn)) {
          isPaid = true;
        }
      }

      if (isPaid && mounted) {
        _isPaymentCompleted = true;
        _pollTimer?.cancel();
        HapticFeedback.heavyImpact();

        final updatedBooking = await _bookingService.markBookingAsPaid(
          widget.booking.id,
          paymongoSessionId: widget.sessionId,
        );

        if (mounted) {
          Navigator.of(context).pop(); // pop this modal sheet
          widget.onPaymentConfirmed(updatedBooking);
        }
      } else if (isManual && mounted) {
        AppSnackBar.info(
          context,
          'Payment not yet received. Please complete checkout on the PayMongo page.',
        );
      }
    } finally {
      if (mounted && isManual) {
        setState(() => _isChecking = false);
      }
    }
  }

  Future<void> _confirmPaymentImmediately() async {
    _isPaymentCompleted = true;
    _pollTimer?.cancel();
    HapticFeedback.heavyImpact();

    final updatedBooking = await _bookingService.markBookingAsPaid(
      widget.booking.id,
      paymongoSessionId: widget.sessionId,
    );

    if (mounted) {
      Navigator.of(context).pop();
      widget.onPaymentConfirmed(updatedBooking);
    }
  }

  Future<void> _relaunchCheckout() async {
    if (widget.checkoutUrl != null && widget.checkoutUrl!.isNotEmpty) {
      final uri = Uri.parse(widget.checkoutUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } else {
      AppSnackBar.info(context, 'No active checkout URL found.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.paddingOf(context).bottom + 20,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(
          top: BorderSide(color: colors.borderSubtle, width: 1.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colors.borderSubtle,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Glowing PayMongo Payment Badge
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.neonLime.withValues(alpha: 0.15),
              border: Border.all(color: colors.neonLime, width: 2),
              boxShadow: [
                BoxShadow(
                  color: colors.neonLime.withValues(alpha: 0.25),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(colors.neonLime),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),

          Text(
            widget.checkoutUrl != null
                ? 'Awaiting PayMongo Payment'
                : 'PayMongo Checkout Active',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.checkoutUrl != null
                ? 'We redirected you to PayMongo to complete your GCash, Maya, GrabPay, or Card payment.'
                : 'Direct client-to-gateway calls are CORS-restricted on web browsers without a server proxy (native on Android/iOS).',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: colors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // Reservation Summary Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surfaceHighlight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.borderSubtle),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Court',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: colors.textMuted,
                      ),
                    ),
                    Text(
                      widget.booking.courtName ?? 'C&J Court',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Amount to Pay',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: colors.textMuted,
                      ),
                    ),
                    Text(
                      '₱${widget.booking.totalAmount.toStringAsFixed(2)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: colors.neonLime,
                      ),
                    ),
                  ],
                ),
                if (widget.sessionId != null) ...[
                  const SizedBox(height: 8),
                  Divider(color: colors.borderSubtle, height: 1),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Session ID',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: colors.textMuted,
                        ),
                      ),
                      Text(
                        widget.sessionId!.length > 18
                            ? '${widget.sessionId!.substring(0, 18)}...'
                            : widget.sessionId!,
                        style: GoogleFonts.robotoMono(
                          fontSize: 11,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Live Polling indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(colors.neonGreen),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Auto-detecting live payment status...',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  color: colors.textMuted,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Action 1: Manual Check Button
          NeonButton(
            text: widget.checkoutUrl != null
                ? 'I Have Paid — Check Status'
                : 'Confirm Payment (Web Test Mode)',
            onPressed: widget.checkoutUrl != null
                ? () => _checkPaymentStatus(isManual: true)
                : _confirmPaymentImmediately,
            isLoading: _isChecking,
          ),
          const SizedBox(height: 10),

          // Action 2: Reopen Checkout
          if (widget.checkoutUrl != null) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _relaunchCheckout,
                icon: Icon(Icons.open_in_new_rounded,
                    size: 16, color: colors.textPrimary),
                label: Text(
                  'Reopen PayMongo Checkout',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: colors.borderSubtle),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Action 3: Dismiss / Back
          TextButton(
            onPressed: () {
              _pollTimer?.cancel();
              Navigator.of(context).pop();
            },
            child: Text(
              'Cancel / Finish Later',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                color: colors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

