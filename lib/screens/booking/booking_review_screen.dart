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
import '../../services/calendar_link_service.dart';
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
  bool _autoLaunchCalendar = true;
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
      BookingModel? booking;

      // 1. Try server-side PayMongo checkout creation
      try {
        final checkoutData = await _bookingService.createPayMongoCheckout(
          courtId: widget.court.id,
          date: widget.startTime,
          hour24: widget.startTime.hour,
          durationHours: widget.durationHours.round(),
          guestName: name,
          guestEmail: email,
          guestPhone: phone,
          paddleRental: widget.paddleRental,
          ballThrowerRental: widget.ballThrowerRental,
        );

        final checkoutUrl = checkoutData['checkoutUrl'] as String?;
        final bookingId = checkoutData['bookingId'] as String?;

        if (checkoutUrl != null && checkoutUrl.isNotEmpty) {
          final uri = Uri.parse(checkoutUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }

          if (bookingId != null) {
            // Poll for payment confirmation
            booking = await _bookingService.pollBookingPaidStatus(bookingId, maxAttempts: 5);
          }
        }
      } catch (e) {
        debugPrint('PayMongo API note: $e, executing direct booking fallback');
      }

      // 2. Direct fallback booking if server-side checkout not configured
      booking ??= await _bookingService.createBooking(
        courtId: widget.court.id,
        startTime: widget.startTime,
        endTime: widget.endTime,
        totalAmount: widget.totalAmount,
        guestName: name,
        guestEmail: email,
        guestPhone: phone,
        notes: [
          if (widget.paddleRental) 'Paddle Rental (2x Paddles, 3x Balls)',
          if (widget.ballThrowerRental) 'Ball Thrower Machine',
        ].join(', '),
      );

      if (mounted) {
        if (_autoLaunchCalendar) {
          CalendarLinkService.addBookingToCalendar(
            booking,
            context: context,
            venueName: widget.venueName,
          );
        }

        Navigator.of(context).pop();

        BookingSuccessModal.show(
          context,
          booking: booking,
          onViewBookings: widget.onViewBookings,
          venueName: widget.venueName,
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
                          color: colors.neonLime,
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
                                ? colors.neonGreenAlpha15
                                : colors.surfaceHighlight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? colors.neonGreen
                                  : colors.borderSubtle,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                method['icon'] as IconData,
                                size: 20,
                                color: isSelected
                                    ? colors.neonGreen
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
                                        ? colors.neonGreen
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
            const SizedBox(height: 16),

            // 5. 1-Tap Calendar Sync Toggle
            Container(
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.borderSubtle),
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: colors.neonGreen,
                    title: Text(
                      '1-Tap Auto-Sync Calendar',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'Add event to Google / Apple / Outlook calendar on booking',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: colors.textMuted,
                      ),
                    ),
                    value: _autoLaunchCalendar,
                    onChanged: (v) => setState(() => _autoLaunchCalendar = v),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 6. Confirm & Lock Button
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
              color: highlight ? colors.neonGreen : colors.textSecondary,
              fontWeight: highlight ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: highlight ? colors.neonGreen : colors.textPrimary,
          ),
        ),
      ],
    );
  }
}
