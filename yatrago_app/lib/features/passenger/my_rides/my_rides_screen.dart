import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/router/route_names.dart';
import '../data/booking_api.dart';
import '../models/booking_model.dart';

class MyRidesScreen extends StatefulWidget {
  const MyRidesScreen({super.key});

  @override
  State<MyRidesScreen> createState() => _MyRidesScreenState();
}

class _MyRidesScreenState extends State<MyRidesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<BookingModel> _upcoming = [];
  List<BookingModel> _completed = [];
  List<BookingModel> _cancelled = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadBookings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBookings() async {
    setState(() => _isLoading = true);
    try {
      final all = await BookingApi.getMyBookings(role: 'passenger');
      if (!mounted) return;
      setState(() {
        _upcoming = all
            .where((b) => b.status == 'confirmed' || b.status == 'pending')
            .toList();
        _completed = all.where((b) => b.status == 'completed').toList();
        _cancelled = all
            .where((b) => b.status == 'cancelled' || b.status == 'rejected')
            .toList();
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text('My Rides'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textTertiary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 2,
          tabs: [
            Tab(text: 'Upcoming (${_upcoming.length})'),
            Tab(text: 'Completed (${_completed.length})'),
            Tab(text: 'Cancelled (${_cancelled.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _BookingList(
                  bookings: _upcoming,
                  emptyMessage: 'No upcoming rides',
                  emptyIcon: Icons.directions_car_outlined,
                  onRefresh: _loadBookings,
                ),
                _BookingList(
                  bookings: _completed,
                  emptyMessage: 'No completed rides yet',
                  emptyIcon: Icons.check_circle_outline_rounded,
                  onRefresh: _loadBookings,
                ),
                _BookingList(
                  bookings: _cancelled,
                  emptyMessage: 'No cancelled rides',
                  emptyIcon: Icons.cancel_outlined,
                  onRefresh: _loadBookings,
                ),
              ],
            ),
    );
  }
}

class _BookingList extends StatelessWidget {
  final List<BookingModel> bookings;
  final String emptyMessage;
  final IconData emptyIcon;
  final Future<void> Function() onRefresh;

  const _BookingList({
    required this.bookings,
    required this.emptyMessage,
    required this.emptyIcon,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyIcon, size: 56, color: AppColors.textTertiary),
            const SizedBox(height: 14),
            Text(
              emptyMessage,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => context.go(RouteNames.search),
              child: const Text('Find a ride'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        itemCount: bookings.length,
        itemBuilder: (context, i) => _BookingCard(booking: bookings[i]),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final BookingModel booking;
  const _BookingCard({required this.booking});

  Color get _statusColor {
    switch (booking.status) {
      case 'confirmed':
        return AppColors.success;
      case 'pending':
        return AppColors.warning;
      case 'cancelled':
      case 'rejected':
        return AppColors.error;
      case 'completed':
        return AppColors.primary;
      default:
        return AppColors.textTertiary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ride = booking.ride;
    DateTime? departure;
    try {
      if (ride?['departureAt'] != null) {
        departure = DateTime.parse(ride!['departureAt']);
      }
    } catch (_) {}

    return GestureDetector(
      onTap: () =>
          context.push(RouteNames.passengerRideDetail, extra: booking.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status + date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    booking.status == 'pending'
                        ? 'AWAITING APPROVAL'
                        : booking.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _statusColor,
                    ),
                  ),
                ),
                if (departure != null)
                  Text(
                    DateFormat('d MMM yyyy').format(departure),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Route
            Text(
              '${ride?['originName'] ?? ''} → ${ride?['destName'] ?? ''}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),

            if (departure != null) ...[
              const SizedBox(height: 4),
              Text(
                DateFormat('EEEE • h:mm a').format(departure),
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Seats + amount
            Row(
              children: [
                const Icon(
                  Icons.event_seat_rounded,
                  size: 16,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: 6),
                Text(
                  '${booking.seatsBooked} seat${booking.seatsBooked > 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  'NPR ${booking.totalAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
