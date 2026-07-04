import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/router/route_names.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/widgets/ride_card.dart';
import '../data/search_api.dart';
import '../data/booking_api.dart';
import '../models/ride_model.dart';
import '../models/booking_model.dart';
import '../../auth/data/auth_api.dart';

class PassengerHomeScreen extends ConsumerStatefulWidget {
  const PassengerHomeScreen({super.key});

  @override
  ConsumerState<PassengerHomeScreen> createState() =>
      _PassengerHomeScreenState();
}

class _PassengerHomeScreenState extends ConsumerState<PassengerHomeScreen> {
  String? _userName;
  List<RideModel> _popularRides = [];
  BookingModel? _upcomingBooking;
  bool _isLoading = true;

  final List<Map<String, String>> _popularRoutes = [
    {'from': 'Kathmandu', 'to': 'Pokhara'},
    {'from': 'Kathmandu', 'to': 'Chitwan'},
    {'from': 'Pokhara', 'to': 'Kathmandu'},
    {'from': 'Kathmandu', 'to': 'Butwal'},
    {'from': 'Kathmandu', 'to': 'Dharan'},
    {'from': 'Kathmandu', 'to': 'Biratnagar'},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Load user name
      final user = await AuthApi.getMe();
      final bookings = await BookingApi.getMyBookings(
        role: 'passenger',
        status: 'confirmed',
      );
      final rides = await SearchApi.getAllRides(limit: 20);

      if (!mounted) return;
      setState(() {
        _userName = user['fullName'];
        _popularRides = rides;
        _upcomingBooking = bookings.isNotEmpty ? bookings.first : null;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _searchRide({String? from, String? to}) {
    if (from != null && to != null && from.isNotEmpty && to.isNotEmpty) {
      // Popular route chips go directly to search results
      context.push(
        RouteNames.searchResults,
        extra: {
          'origin': from,
          'destination': to,
          'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
          'seats': 1,
          'originLat': null,
          'originLng': null,
          'destLat': null,
          'destLng': null,
        },
      );
    } else {
      // Search bar and "See all" button still open the search page
      context.push(RouteNames.search);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: CustomScrollView(
            slivers: [
              // App bar
              SliverToBoxAdapter(
                child: Container(
                  color: AppColors.primary,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hello, ${_userName ?? 'Traveller'} 👋',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Where are you going today?',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              // Notifications
                              GestureDetector(
                                onTap: () =>
                                    context.push(RouteNames.notifications),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.notifications_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Settings / Profile
                              GestureDetector(
                                onTap: () => context.push(RouteNames.settings),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.person_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Search bar
                      GestureDetector(
                        onTap: () => _searchRide(),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.search_rounded,
                                color: AppColors.textTertiary,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Search origin, destination...',
                                  style: TextStyle(
                                    color: AppColors.textTertiary,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  DateFormat('d MMM').format(DateTime.now()),
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.screenPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Upcoming booking card
                      if (_upcomingBooking != null) ...[
                        _UpcomingBookingCard(
                          booking: _upcomingBooking!,
                          onTap: () => context.push(
                            RouteNames.passengerRideDetail,
                            extra: _upcomingBooking!.id,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Popular routes
                      const Text(
                        'Popular Routes',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 44,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _popularRoutes.length,
                          itemBuilder: (context, i) {
                            final route = _popularRoutes[i];
                            return GestureDetector(
                              onTap: () => _searchRide(
                                from: route['from'],
                                to: route['to'],
                              ),
                              child: Container(
                                margin: const EdgeInsets.only(right: 10),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(
                                    color: AppColors.borderLight,
                                  ),
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      route['from']!,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      child: Icon(
                                        Icons.arrow_right_alt_rounded,
                                        size: 16,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    Text(
                                      route['to']!,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Nearby rides map preview
                      if (!_isLoading && _popularRides.isNotEmpty) ...[
                        const Text(
                          'Rides Near You',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () => context.push(
                            RouteNames.searchResults,
                            extra: {
                              'origin': '',
                              'destination': '',
                              'date': DateFormat(
                                'yyyy-MM-dd',
                              ).format(DateTime.now()),
                              'seats': 1,
                              'originLat': null,
                              'originLng': null,
                              'destLat': null,
                              'destLng': null,
                            },
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppSpacing.cardRadius,
                            ),
                            child: SizedBox(
                              height: 160,
                              child: IgnorePointer(
                                child: FlutterMap(
                                  options: MapOptions(
                                    initialCenter: LatLng(
                                      _popularRides.first.destLat,
                                      _popularRides.first.destLng,
                                    ),
                                    initialZoom: 6.5,
                                  ),
                                  children: [
                                    TileLayer(
                                      urlTemplate:
                                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                      userAgentPackageName: 'com.yatrago.app',
                                    ),
                                    MarkerLayer(
                                      markers: _popularRides
                                          .map(
                                            (ride) => Marker(
                                              point: LatLng(
                                                ride.destLat,
                                                ride.destLng,
                                              ),
                                              width: 32,
                                              height: 32,
                                              child: const Icon(
                                                Icons.location_on_rounded,
                                                color: AppColors.primary,
                                                size: 28,
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Available rides
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Available Rides',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          TextButton(
                            onPressed: () => _searchRide(),
                            child: const Text(
                              'See all',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (_isLoading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          ),
                        )
                      else if (_popularRides.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.directions_car_outlined,
                                  size: 48,
                                  color: AppColors.textTertiary,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'No rides available right now',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextButton(
                                  onPressed: () => _searchRide(),
                                  child: const Text('Search rides'),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ...(_popularRides
                            .take(5)
                            .map(
                              (ride) => RideCard(
                                ride: ride,
                                onTap: () => context.push(
                                  RouteNames.rideDetail,
                                  extra: ride.toJson(),
                                ),
                              ),
                            )),

                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Upcoming booking card
class _UpcomingBookingCard extends StatelessWidget {
  final BookingModel booking;
  final VoidCallback onTap;

  const _UpcomingBookingCard({required this.booking, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ride = booking.ride;
    if (ride == null) return const SizedBox.shrink();

    final departure = ride['departureAt'] != null
        ? DateTime.parse(ride['departureAt'])
        : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, Color(0xFF1A6EC0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Upcoming Trip',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    booking.status.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${ride['originName']} → ${ride['destName']}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (departure != null) ...[
              const SizedBox(height: 8),
              Text(
                DateFormat('EEE, d MMM • h:mm a').format(departure),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${booking.seatsBooked} seat${booking.seatsBooked > 1 ? 's' : ''} • NPR ${booking.totalAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Row(
                  children: [
                    Text(
                      'View details',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: Colors.white,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
