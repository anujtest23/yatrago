import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/router/route_names.dart';
import '../../../core/network/dio_client.dart';

class DriverMyRidesScreen extends StatefulWidget {
  const DriverMyRidesScreen({super.key});

  @override
  State<DriverMyRidesScreen> createState() => _DriverMyRidesScreenState();
}

class _DriverMyRidesScreenState extends State<DriverMyRidesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _upcoming = [];
  List<Map<String, dynamic>> _completed = [];
  List<Map<String, dynamic>> _cancelled = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final response = await DioClient.instance.get('/trips');
      final trips = List<Map<String, dynamic>>.from(
        response.data['data']['trips'] ?? [],
      );
      if (!mounted) return;
      setState(() {
        _upcoming = trips
            .where(
              (t) => t['status'] == 'published' || t['status'] == 'in_progress',
            )
            .toList();
        _completed = trips.where((t) => t['status'] == 'completed').toList();
        _cancelled = trips.where((t) => t['status'] == 'cancelled').toList();
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
          labelColor: AppColors.driver,
          unselectedLabelColor: AppColors.textTertiary,
          indicatorColor: AppColors.driver,
          tabs: [
            Tab(text: 'Upcoming (${_upcoming.length})'),
            Tab(text: 'Completed (${_completed.length})'),
            Tab(text: 'Cancelled (${_cancelled.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.driver),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _TripList(
                  trips: _upcoming,
                  emptyMessage:
                      'No upcoming rides.\nPost a ride to get started.',
                  onRefresh: _load,
                ),
                _TripList(
                  trips: _completed,
                  emptyMessage: 'No completed rides yet.',
                  onRefresh: _load,
                ),
                _TripList(
                  trips: _cancelled,
                  emptyMessage: 'No cancelled rides.',
                  onRefresh: _load,
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(RouteNames.postRide),
        backgroundColor: AppColors.driver,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Post Ride', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

class _TripList extends StatelessWidget {
  final List<Map<String, dynamic>> trips;
  final String emptyMessage;
  final Future<void> Function() onRefresh;

  const _TripList({
    required this.trips,
    required this.emptyMessage,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (trips.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.directions_car_outlined,
                size: 56,
                color: AppColors.textTertiary,
              ),
              const SizedBox(height: 12),
              Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        itemCount: trips.length,
        itemBuilder: (context, i) {
          final trip = trips[i];
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _StatusChip(status: trip['status'] ?? ''),
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
                  const SizedBox(height: 10),
                  Text(
                    '${trip['originName']} → ${trip['destName']}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (departure != null)
                    Text(
                      DateFormat('h:mm a').format(departure),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.event_seat_rounded,
                        size: 16,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${trip['availableSeats']} / ${trip['totalSeats']} seats',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'NPR ${(trip['pricePerSeat'] ?? 0).toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.driver,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  Color get color {
    switch (status) {
      case 'published':
        return AppColors.success;
      case 'in_progress':
        return AppColors.primary;
      case 'completed':
        return AppColors.textSecondary;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.textTertiary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase().replaceAll('_', ' '),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
