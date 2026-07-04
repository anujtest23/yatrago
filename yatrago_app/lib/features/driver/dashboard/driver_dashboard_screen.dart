import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/router/route_names.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_exception.dart';
import 'package:dio/dio.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  Map<String, dynamic>? _dashboard;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await DioClient.instance.get('/drivers/dashboard');
      if (!mounted) return;
      setState(() {
        _dashboard = response.data['data'];
        _isLoading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ApiException.fromDioError(e).message;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadDashboard,
          child: CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Container(
                  color: AppColors.driver,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Driver Dashboard',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Manage your rides and earnings',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () =>
                                    context.push(RouteNames.driverNotifications),
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
                              GestureDetector(
                                onTap: () =>
                                    context.push(RouteNames.driverSettings),
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

                      // Earnings cards
                      Row(
                        children: [
                          Expanded(
                            child: _EarningCard(
                              label: "Today's Earnings",
                              value:
                                  'NPR ${(_dashboard?['earnings']?['today'] ?? 0).toStringAsFixed(0)}',
                              icon: Icons.today_rounded,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _EarningCard(
                              label: 'Total Earnings',
                              value:
                                  'NPR ${(_dashboard?['earnings']?['lifetime'] ?? 0).toStringAsFixed(0)}',
                              icon: Icons.account_balance_wallet_rounded,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: _isLoading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(
                            color: AppColors.driver,
                          ),
                        ),
                      )
                    : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Text(_error!),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _loadDashboard,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(AppSpacing.screenPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Stats row
                            Row(
                              children: [
                                _StatCard(
                                  label: 'Total Trips',
                                  value:
                                      '${_dashboard?['driver']?['totalTrips'] ?? 0}',
                                  icon: Icons.directions_car_rounded,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 10),
                                _StatCard(
                                  label: 'Rating',
                                  value:
                                      '${(_dashboard?['driver']?['averageRating'] ?? 0.0).toStringAsFixed(1)}',
                                  icon: Icons.star_rounded,
                                  color: AppColors.star,
                                ),
                                const SizedBox(width: 10),
                                _StatCard(
                                  label: 'Pending',
                                  value:
                                      '${_dashboard?['pendingBookingRequests'] ?? 0}',
                                  icon: Icons.pending_actions_rounded,
                                  color: AppColors.warning,
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // Action buttons
                            Row(
                              children: [
                                Expanded(
                                  child: _ActionButton(
                                    icon: Icons.add_road_rounded,
                                    label: 'Post a Ride',
                                    color: AppColors.driver,
                                    onTap: () =>
                                        context.push(RouteNames.postRide),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _ActionButton(
                                    icon: Icons.confirmation_number_rounded,
                                    label: 'Bookings',
                                    color: AppColors.primary,
                                    onTap: () => context.push(
                                      RouteNames.incomingBookings,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            Row(
                              children: [
                                Expanded(
                                  child: _ActionButton(
                                    icon: Icons.list_alt_rounded,
                                    label: 'My Rides',
                                    color: AppColors.success,
                                    onTap: () =>
                                        context.push(RouteNames.driverMyRides),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _ActionButton(
                                    icon: Icons.account_balance_wallet_rounded,
                                    label: 'Wallet',
                                    color: AppColors.driver,
                                    onTap: () =>
                                        context.push(RouteNames.driverWallet),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            Row(
                              children: [
                                Expanded(
                                  child: _ActionButton(
                                    icon: Icons.settings_rounded,
                                    label: 'Settings',
                                    color: AppColors.textSecondary,
                                    onTap: () => context.push(
                                      RouteNames.driverSettings,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(child: SizedBox()),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // Upcoming trips
                            const Text(
                              'Upcoming Trips',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),

                            if ((_dashboard?['upcomingTrips'] as List?)
                                    ?.isEmpty !=
                                false)
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.borderLight,
                                  ),
                                ),
                                child: const Center(
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.directions_car_outlined,
                                        size: 36,
                                        color: AppColors.textTertiary,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'No upcoming trips',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              ...(_dashboard!['upcomingTrips'] as List)
                                  .map((t) => _TripCard(trip: t))
                                  .toList(),

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

class _EarningCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _EarningCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final Map<String, dynamic> trip;
  const _TripCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    DateTime? departure;
    try {
      departure = DateTime.parse(trip['departureAt']);
    } catch (_) {}

    return GestureDetector(
      onTap: () => context.push(
        RouteNames.driverRideDetail,
        extra: trip['id'] as String,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.driverLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.directions_car_rounded,
                color: AppColors.driver,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${trip['originName']} → ${trip['destName']}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (departure != null)
                    Text(
                      DateFormat('EEE, d MMM • h:mm a').format(departure),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${trip['availableSeats']} seats',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
                Text(
                  'NPR ${(trip['pricePerSeat'] ?? 0).toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.driver,
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
