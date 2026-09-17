import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive_layout.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/utils/validators.dart';
import '../../data/mock_data.dart';
import '../../models/event_space_model.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/event_booking_confirmation_modal.dart';
import '../../widgets/tap_collapse.dart';

/// Screen allowing club members and event organizers to reserve arena spaces,
/// clubhouses, and tournament pavilions with customized add-on packages.
class EventPlaceBookingScreen extends StatefulWidget {
  final VoidCallback? onBookingCompleted;
  final bool showAppBar;

  const EventPlaceBookingScreen({
    super.key,
    this.onBookingCompleted,
    this.showAppBar = true,
  });

  @override
  State<EventPlaceBookingScreen> createState() => _EventPlaceBookingScreenState();
}

class _EventPlaceBookingScreenState extends State<EventPlaceBookingScreen> {
  final _formKey = GlobalKey<FormState>();

  // Spaces state
  final List<EventSpaceModel> _spaces = MockData.eventSpaces;
  late int _selectedSpaceIndex;

  // Configuration state
  String _selectedEventType = 'Tournament & League';
  EventPackageType _selectedPackage = EventPackageType.halfDayMorning;
  int _customHours = 4;
  late int _guestCount;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 3));
  late TimeOfDay _startTime;

  // Selected add-ons
  final Set<String> _selectedAddonIds = {};

  // Organizer controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  final List<String> _eventTypes = const [
    'Tournament & League',
    'Corporate Outing',
    'Birthday / Celebration',
    'Clinic & Workshop',
    'Social Mixer',
  ];

  @override
  void initState() {
    super.initState();
    _selectedSpaceIndex = 0;
    _guestCount = _currentSpace.capacityMin + 15;
    _startTime = _selectedPackage.defaultStartTime;

    const user = MockData.mockUserProfile;
    _nameController.text = user.fullName ?? '';
    _emailController.text = user.email ?? '';
    _phoneController.text = user.phone ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  EventSpaceModel get _currentSpace => _spaces[_selectedSpaceIndex];

  int get _durationHours {
    if (_selectedPackage == EventPackageType.customHourly) {
      return _customHours;
    }
    return _selectedPackage.defaultDurationHours;
  }

  double get _basePrice => _currentSpace.calculateBasePrice(
        package: _selectedPackage,
        customHours: _customHours,
      );

  List<EventAddon> get _selectedAddonsList {
    return MockData.eventAddons
        .where((addon) => _selectedAddonIds.contains(addon.id))
        .toList();
  }

  double get _addonsPrice {
    double sum = 0.0;
    for (final addon in _selectedAddonsList) {
      sum += addon.calculateCost(_durationHours);
    }
    return sum;
  }

  double get _securityDeposit => 2500.0; // Standard refundable deposit

  double get _totalPrice => _basePrice + _addonsPrice + _securityDeposit;

  TimeOfDay get _endTime {
    final endHour = (_startTime.hour + _durationHours).clamp(0, 24);
    return TimeOfDay(hour: endHour % 24, minute: _startTime.minute);
  }

  void _onSpaceSelected(int index) {
    if (_selectedSpaceIndex == index) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedSpaceIndex = index;
      if (_guestCount < _currentSpace.capacityMin) {
        _guestCount = _currentSpace.capacityMin;
      } else if (_guestCount > _currentSpace.capacityMax) {
        _guestCount = _currentSpace.capacityMax;
      }
    });
  }

  void _onPackageSelected(EventPackageType package) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedPackage = package;
      _startTime = package.defaultStartTime;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: now.add(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 180)),
      builder: (ctx, child) {
        final colors = ctx.colors;
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: ColorScheme.dark(
              primary: colors.neonGreen,
              onPrimary: colors.background,
              surface: colors.surfaceElevated,
              onSurface: colors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  void _submitReservation() {
    if (!_formKey.currentState!.validate()) {
      AppSnackBar.error(context, 'Please complete the organizer contact details.');
      return;
    }

    final booking = EventBookingModel(
      id: 'EVT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      spaceId: _currentSpace.id,
      spaceName: _currentSpace.name,
      eventType: _selectedEventType,
      packageType: _selectedPackage,
      date: _selectedDate,
      startTime: _startTime,
      durationHours: _durationHours,
      guestCount: _guestCount,
      selectedAddons: _selectedAddonsList,
      organizerName: _nameController.text.trim(),
      organizerEmail: _emailController.text.trim(),
      organizerPhone: _phoneController.text.trim(),
      specialInstructions: _notesController.text.trim(),
      basePrice: _basePrice,
      addonsPrice: _addonsPrice,
      securityDeposit: _securityDeposit,
      totalAmount: _totalPrice,
      isMessageFirst: _currentSpace.isMessageFirst,
      createdAt: DateTime.now(),
    );

    // Save to in-memory store
    MockData.addMockEventBooking(booking);

    HapticFeedback.heavyImpact();
    EventBookingConfirmationModal.show(
      context,
      booking: booking,
      onDismiss: widget.onBookingCompleted,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final bodyContent = ResponsiveLayoutBuilder(
      compact: (ctx, constraints) => _buildCompactLayout(colors),
      expanded: (ctx, constraints) => _buildExpandedLayout(colors),
    );

    if (!widget.showAppBar) {
      return AdaptiveContainer(child: bodyContent);
    }

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: colors.textPrimary, size: 18),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'EVENTS PLACE RESERVATION',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: colors.neonGreen,
              ),
            ),
            Text(
              'Book Luxury Venues & Pavilions',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: AdaptiveContainer(
          child: bodyContent,
        ),
      ),
      bottomNavigationBar: LayoutBuilder(
        builder: (ctx, constraints) {
          // On tablet/desktop, the sticky summary card is on the right side
          if (constraints.maxWidth >= ResponsiveBreakpoints.tablet) {
            return const SizedBox.shrink();
          }
          return _buildMobileBottomBar(colors);
        },
      ),
    );
  }

  // ==========================================
  // MOBILE SINGLE-COLUMN LAYOUT (< 650px)
  // ==========================================
  Widget _buildCompactLayout(AppPalette colors) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSpacePicker(colors),
            const SizedBox(height: 18),
            _buildEventTypeSelector(colors),
            const SizedBox(height: 18),
            _buildGuestCountSection(colors),
            const SizedBox(height: 18),
            _buildPackageAndScheduleSection(colors),
            const SizedBox(height: 18),
            _buildAddonsSection(colors),
            const SizedBox(height: 18),
            _buildOrganizerForm(colors),
            const SizedBox(height: 20),
            _buildPricingSummaryCard(colors),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TABLET / DESKTOP SPLIT LAYOUT (>= 650px)
  // ==========================================
  Widget _buildExpandedLayout(AppPalette colors) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: Configuration Forms (Flex: 6)
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSpacePicker(colors),
                  const SizedBox(height: 20),
                  _buildEventTypeSelector(colors),
                  const SizedBox(height: 20),
                  _buildGuestCountSection(colors),
                  const SizedBox(height: 20),
                  _buildPackageAndScheduleSection(colors),
                  const SizedBox(height: 20),
                  _buildAddonsSection(colors),
                  const SizedBox(height: 20),
                  _buildOrganizerForm(colors),
                ],
              ),
            ),
            const SizedBox(width: 24),

            // Right Column: Sticky Summary & Reservation CTA (Flex: 4)
            Expanded(
              flex: 4,
              child: Column(
                children: [
                  _buildPricingSummaryCard(colors),
                  const SizedBox(height: 16),
                  _buildDesktopCTAButton(colors),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 1. SPACE PICKER CARDS
  // ==========================================
  Widget _buildSpacePicker(AppPalette colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'SELECT EVENT VENUE',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: colors.textMuted,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${_spaces.length} Luxury Spaces',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colors.neonGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Column(
          children: _spaces.asMap().entries.map((entry) {
            final index = entry.key;
            final space = entry.value;
            final isSel = _selectedSpaceIndex == index;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TapCollapse(
                onTap: () => _onSpaceSelected(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSel ? colors.surfaceElevated : colors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSel ? colors.neonGreen : colors.borderSubtle,
                      width: isSel ? 2.0 : 1.0,
                    ),
                    boxShadow: isSel ? colors.neonGlow : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isSel ? colors.neonGreenAlpha15 : colors.surfaceHighlight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              space.tags.first,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: isSel ? colors.neonGreen : colors.textMuted,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.groups_rounded,
                            size: 16,
                            color: isSel ? colors.neonGreen : colors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${space.capacityMin}–${space.capacityMax} Guests',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        space.name,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        space.subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: colors.textMuted,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (space.areaSqm != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: colors.neonGreenAlpha15,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.square_foot_rounded, size: 12, color: colors.neonGreen),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${space.areaSqm} sqm',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: colors.neonGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (space.levelInfo != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: colors.surfaceHighlight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 260),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.elevator_rounded, size: 12, color: colors.textSecondary),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        space.levelInfo!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: colors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ...space.amenities.take(3).map((amenity) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: colors.surfaceHighlight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                amenity,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: colors.textSecondary,
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 12),
                      space.isMessageFirst
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: colors.neonGreenAlpha15,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: colors.neonGreen.withAlpha(80)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.chat_bubble_outline_rounded, size: 14, color: colors.neonGreen),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            'Message Us First for Rates & Availability',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: colors.neonGreen,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Inquiry Only',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: colors.textMuted,
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    '₱${space.hourlyRate.toStringAsFixed(0)} / hr',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: isSel ? colors.neonGreen : colors.textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    '₱${space.halfDayRate.toStringAsFixed(0)} half-day',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: colors.textMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ==========================================
  // 2. EVENT TYPE SELECTOR
  // ==========================================
  Widget _buildEventTypeSelector(AppPalette colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'EVENT OCCASION',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            color: colors.textMuted,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _eventTypes.map((type) {
            final isSel = _selectedEventType == type;
            return TapCollapse(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedEventType = type);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: isSel ? colors.textPrimary : colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSel ? colors.textPrimary : colors.borderSubtle,
                  ),
                ),
                child: Text(
                  type,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                    color: isSel ? colors.background : colors.textSecondary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ==========================================
  // 3. GUEST COUNT SECTION
  // ==========================================
  Widget _buildGuestCountSection(AppPalette colors) {
    final min = _currentSpace.capacityMin;
    final max = _currentSpace.capacityMax;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ESTIMATED GUESTS',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: colors.textMuted,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.neonGreenAlpha15,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$_guestCount Guests',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: colors.neonGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: colors.surfaceHighlight,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: Icon(Icons.remove, color: colors.textPrimary, size: 18),
                onPressed: _guestCount > min
                    ? () {
                        HapticFeedback.selectionClick();
                        setState(() => _guestCount -= 5);
                      }
                    : null,
              ),
              Expanded(
                child: Slider(
                  value: _guestCount.toDouble().clamp(min.toDouble(), max.toDouble()),
                  min: min.toDouble(),
                  max: max.toDouble(),
                  divisions: (max - min) ~/ 5 > 0 ? (max - min) ~/ 5 : 1,
                  activeColor: colors.neonGreen,
                  inactiveColor: colors.surfaceHighlight,
                  onChanged: (val) {
                    setState(() => _guestCount = val.round());
                  },
                ),
              ),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: colors.surfaceHighlight,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: Icon(Icons.add, color: colors.textPrimary, size: 18),
                onPressed: _guestCount < max
                    ? () {
                        HapticFeedback.selectionClick();
                        setState(() => _guestCount += 5);
                      }
                    : null,
              ),
            ],
          ),
          Text(
            'Space capacity: $min to $max attendees',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: colors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 4. PACKAGE AND SCHEDULE SECTION
  // ==========================================
  Widget _buildPackageAndScheduleSection(AppPalette colors) {
    final dateFormat = DateFormat('EEE, MMM d, yyyy');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PACKAGE & SCHEDULE',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: 12),

          // Date Trigger
          TapCollapse(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: colors.surfaceHighlight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.borderSubtle),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_month_rounded, color: colors.neonGreen, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      dateFormat.format(_selectedDate),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Change Date',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.neonGreen,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Package Selector Grid
          Column(
            children: EventPackageType.values.map((pkg) {
              final isSel = _selectedPackage == pkg;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TapCollapse(
                  onTap: () => _onPackageSelected(pkg),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSel ? colors.surfaceElevated : colors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSel ? colors.neonGreen : colors.borderSubtle,
                        width: isSel ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSel ? Icons.radio_button_checked : Icons.radio_button_off,
                          color: isSel ? colors.neonGreen : colors.textMuted,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pkg.label,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary,
                                ),
                              ),
                              Text(
                                pkg.timeFrame,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: colors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _currentSpace.isMessageFirst
                              ? 'Custom Quote'
                              : '₱${_currentSpace.calculateBasePrice(package: pkg, customHours: _customHours).toStringAsFixed(0)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: isSel ? colors.neonGreen : colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          // Custom Hours Stepper (if custom hourly selected)
          if (_selectedPackage == EventPackageType.customHourly) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Custom Hours (2–10 hrs):',
                  style: GoogleFonts.inter(fontSize: 12, color: colors.textSecondary),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.remove_circle_outline, color: colors.textPrimary, size: 20),
                      onPressed: _customHours > 2
                          ? () => setState(() => _customHours--)
                          : null,
                    ),
                    Text(
                      '$_customHours hrs',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: colors.neonGreen,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.add_circle_outline, color: colors.textPrimary, size: 20),
                      onPressed: _customHours < 10
                          ? () => setState(() => _customHours++)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // 5. ADD-ONS SECTION
  // ==========================================
  Widget _buildAddonsSection(AppPalette colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'EQUIPMENT & CONCIERGE ADD-ONS',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: colors.textMuted,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${_selectedAddonIds.length} Selected',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colors.neonGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Column(
          children: MockData.eventAddons.map((addon) {
            final isChecked = _selectedAddonIds.contains(addon.id);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TapCollapse(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    if (isChecked) {
                      _selectedAddonIds.remove(addon.id);
                    } else {
                      _selectedAddonIds.add(addon.id);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isChecked ? colors.surfaceElevated : colors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isChecked ? colors.neonGreen : colors.borderSubtle,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        addon.icon,
                        color: isChecked ? colors.neonGreen : colors.textMuted,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              addon.name,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary,
                              ),
                            ),
                            Text(
                              addon.description,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: colors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '+₱${addon.calculateCost(_durationHours).toStringAsFixed(0)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isChecked ? colors.neonGreen : colors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        isChecked ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                        color: isChecked ? colors.neonGreen : colors.textMuted,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ==========================================
  // 6. ORGANIZER FORM
  // ==========================================
  Widget _buildOrganizerForm(AppPalette colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ORGANIZER CONTACT DETAILS',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          CustomTextField(
            controller: _nameController,
            label: 'Organizer Full Name',
            hintText: 'e.g. Alex Morgan',
            prefixIcon: Icons.person_outline_rounded,
            validator: Validators.validateFullName,
          ),
          const SizedBox(height: 12),
          CustomTextField(
            controller: _emailController,
            label: 'Contact Email',
            hintText: 'e.g. alex@example.com',
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.email_outlined,
            validator: Validators.validateEmail,
          ),
          const SizedBox(height: 12),
          CustomTextField(
            controller: _phoneController,
            label: 'Mobile Phone',
            hintText: '+63 917 555 0192',
            keyboardType: TextInputType.phone,
            prefixIcon: Icons.phone_outlined,
            validator: Validators.validatePhone,
          ),
          const SizedBox(height: 12),
          CustomTextField(
            controller: _notesController,
            label: 'Special Setup Instructions / Dietary Notes',
            hintText: 'e.g. Need 4 tables for registration, projector screen setup...',
            prefixIcon: Icons.notes_rounded,
          ),
          if (_currentSpace.isOcularAvailable) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colors.surfaceHighlight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.neonGreenAlpha15),
              ),
              child: Row(
                children: [
                  Icon(Icons.phone_android_rounded, size: 16, color: colors.neonGreen),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Free ocular by appointment (${_currentSpace.contactPhone ?? '0917-123-0382'})',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // 7. PRICING SUMMARY CARD
  // ==========================================
  Widget _buildPricingSummaryCard(AppPalette colors) {
    final dateFormat = DateFormat('EEE, MMM d');

    return Container(
      padding: const EdgeInsets.all(18),
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
              Flexible(
                child: Text(
                  'EVENT RESERVATION SUMMARY',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: colors.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.neonGreenAlpha15,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'QUOTE',
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: colors.neonGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _currentSpace.name,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${dateFormat.format(_selectedDate)} • ${_startTime.format(context)}–${_endTime.format(context)} ($_durationHours hrs)',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          if (_currentSpace.isMessageFirst) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.neonGreenAlpha15,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.neonGreen.withAlpha(60)),
              ),
              child: Row(
                children: [
                  Icon(Icons.chat_outlined, size: 16, color: colors.neonGreen),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Direct inquiry only. No upfront payment required. Submit your request or message us directly to discuss package rates and ocular schedule.',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: colors.textPrimary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            _buildItemizedRow(colors, 'Base Space Rental (${_selectedPackage.label})', '₱${_basePrice.toStringAsFixed(0)}'),
            if (_selectedAddonIds.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildItemizedRow(colors, 'Selected Add-ons (${_selectedAddonIds.length})', '₱${_addonsPrice.toStringAsFixed(0)}'),
            ],
            const SizedBox(height: 8),
            _buildItemizedRow(colors, 'Refundable Security Deposit', '₱${_securityDeposit.toStringAsFixed(0)}', isSubtle: true),
          ],
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentSpace.isMessageFirst ? 'PAYMENT REQUIRED' : 'TOTAL ESTIMATE',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: colors.textMuted,
                      ),
                    ),
                    Text(
                      _currentSpace.isMessageFirst ? '₱0 Upfront' : '₱${_totalPrice.toStringAsFixed(0)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: colors.neonGreen,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: colors.surfaceHighlight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _currentSpace.isMessageFirst ? 'Message us first' : 'Deposit included',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemizedRow(AppPalette colors, String label, String value, {bool isSubtle = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: isSubtle ? colors.textMuted : colors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSubtle ? colors.textMuted : colors.textPrimary,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // MOBILE BOTTOM BAR
  // ==========================================
  Widget _buildMobileBottomBar(AppPalette colors) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.paddingOf(context).bottom + 12,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        border: Border(top: BorderSide(color: colors.borderSubtle)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentSpace.isMessageFirst ? 'DIRECT INQUIRY' : 'TOTAL RESERVATION',
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: colors.textMuted,
                  ),
                ),
                Text(
                  _currentSpace.isMessageFirst ? 'Message First' : '₱${_totalPrice.toStringAsFixed(0)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: colors.neonGreen,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.textPrimary,
                foregroundColor: colors.background,
                elevation: 0,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _submitReservation,
              child: Text(
                _currentSpace.isMessageFirst ? 'Message Us to Book' : 'Request Space',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // DESKTOP CTA BUTTON
  // ==========================================
  Widget _buildDesktopCTAButton(AppPalette colors) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.textPrimary,
          foregroundColor: colors.background,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: _submitReservation,
        child: Text(
          _currentSpace.isMessageFirst
              ? 'Send Inquiry / Message Us First'
              : 'Confirm Event Reservation • ₱${_totalPrice.toStringAsFixed(0)}',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
