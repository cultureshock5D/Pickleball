import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/pagination/pagination_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/booking_repository.dart';
import '../../models/booking_model.dart';
import '../../services/booking_service.dart';
import '../../widgets/paginated_list_view.dart';
import '../../widgets/reservation_card.dart';
import '../../widgets/skeleton_loader.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final BookingService _bookingService = BookingService.instance;
  StreamSubscription<BookingRealtimeEvent>? _realtimeSubscription;
  late final PaginationController<BookingModel> _bookingsPaginationController;

  List<BookingModel> _upcomingBookings = [];
  List<BookingModel> _pastBookings = [];
  int _filterIndex = 0; // 0 = Upcoming, 1 = Past / Cancelled

  @override
  void initState() {
    super.initState();
    _bookingsPaginationController = PaginationController<BookingModel>(
      fetchPageChunk: (cursor, pageSize) =>
          BookingRepository.forFlavor().fetchPaginatedCustomerBookings(
        cursor: cursor,
        pageSize: pageSize,
      ),
      idExtractor: (b) => b.id,
    );
    _loadBookings();
    _initRealtimeSubscription();
  }

  void _initRealtimeSubscription() {
    _bookingService.initRealtimeSubscription();
    _realtimeSubscription = _bookingService.bookingRealtimeEvents
        .listen(_handleRealtimeBookingEvent);
  }

  void _handleRealtimeBookingEvent(BookingRealtimeEvent event) {
    if (!mounted) return;
    final user = _bookingService.currentUser;
    final b = event.booking;
    final affectsUser = b == null ||
        (user != null &&
            (b.userId == user.id ||
                (b.guestEmail.isNotEmpty && b.guestEmail == user.email)));

    if (affectsUser) {
      if (b != null) {
        if (event.type == BookingRealtimeEventType.inserted) {
          _bookingsPaginationController.insertItem(b);
        } else if (event.type == BookingRealtimeEventType.updated) {
          _bookingsPaginationController.updateItem(b);
        } else if (event.type == BookingRealtimeEventType.deleted) {
          _bookingsPaginationController.removeItem(b.id);
        }
      }
      _loadBookings();
    }
  }

  Future<void> _loadBookings() async {
    final bookings = await _bookingService.fetchCustomerBookings();
    final now = DateTime.now();

    final upcoming = bookings.where((b) {
      final isFuture = b.endTime.isAfter(now);
      final isNotCancelled = b.status != 'cancelled' &&
          b.status != 'expired' &&
          b.status != 'void';
      return isFuture && isNotCancelled;
    }).toList(growable: false);

    final past = bookings.where((b) {
      final isPast = b.endTime.isBefore(now);
      final isCancelled = b.status == 'cancelled' ||
          b.status == 'expired' ||
          b.status == 'void';
      return isPast || isCancelled;
    }).toList(growable: false);

    if (mounted) {
      setState(() {
        _upcomingBookings = upcoming;
        _pastBookings = past;
      });
    }
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    _bookingsPaginationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _buildFilterTab(
                      index: 0,
                      label: 'Upcoming (${_upcomingBookings.length})',
                      colors: colors,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildFilterTab(
                      index: 1,
                      label: 'Past / Cancelled (${_pastBookings.length})',
                      colors: colors,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PaginatedListView<BookingModel>(
                controller: _bookingsPaginationController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                skeletonBuilder: (_, __) => const SkeletonReservationCard(
                  margin: EdgeInsets.symmetric(vertical: 6),
                ),
                itemBuilder: (context, item, index) {
                  final isUpcoming = item.endTime.isAfter(DateTime.now()) &&
                      item.status != 'cancelled' &&
                      item.status != 'expired';

                  if (_filterIndex == 0 && !isUpcoming) {
                    return const SizedBox.shrink();
                  }
                  if (_filterIndex == 1 && isUpcoming) {
                    return const SizedBox.shrink();
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ReservationCard(
                      booking: item,
                      isUpcoming: isUpcoming,
                      onRefresh: () async {
                        await _loadBookings();
                        await _bookingsPaginationController.refresh();
                      },
                    ),
                  );
                },
                emptyBuilder: (context) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_month_outlined,
                            size: 48, color: colors.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          _filterIndex == 0
                              ? 'No upcoming court reservations'
                              : 'No past booking records',
                          style: GoogleFonts.inter(
                            color: colors.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTab({
    required int index,
    required String label,
    required AppPalette colors,
  }) {
    final isSelected = _filterIndex == index;
    return InkWell(
      onTap: () => setState(() => _filterIndex = index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? colors.textPrimary : colors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? colors.textPrimary : colors.borderSubtle,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? colors.background : colors.textMuted,
          ),
        ),
      ),
    );
  }
}
