import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/router/route_names.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/primary_button.dart';

import '../../../core/widgets/route_map_widget.dart';

class DriverRideDetailScreen extends StatefulWidget {
  final String tripId;
  const DriverRideDetailScreen({super.key, required this.tripId});

  @override
  State<DriverRideDetailScreen> createState() => _DriverRideDetailScreenState();
}

class _DriverRideDetailScreenState extends State<DriverRideDetailScreen> {
  Map<String, dynamic>? _trip;
  bool _isLoading = true;
  bool _isActing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await DioClient.instance.get('/trips/${widget.tripId}');
      setState(() {
        _trip = response.data['data'];
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _startTrip() async {
    setState(() => _isActing = true);
    try {
      await DioClient.instance.patch('/trips/${widget.tripId}/start');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trip started!'),
          backgroundColor: AppColors.success,
        ),
      );
      _load();
    } on DioException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiException.fromDioError(e).message)),
      );
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _completeTrip() async {
    setState(() => _isActing = true);
    try {
      final response = await DioClient.instance.patch(
        '/trips/${widget.tripId}/complete',
      );
      final data = response.data['data'];
      if (!mounted) return;
      context.pushReplacement(RouteNames.tripSummary, extra: data);
    } on DioException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiException.fromDioError(e).message)),
      );
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _cancelTrip() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Trip?'),
        content: const Text(
          'All passengers will be notified. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await DioClient.instance.delete('/trips/${widget.tripId}');
                if (!mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Trip cancelled')));
                context.pop();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
            child: const Text(
              'Cancel Trip',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.driver)),
      );
    }

    if (_trip == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ride Detail')),
        body: const Center(child: Text('Trip not found')),
      );
    }

    final status = _trip!['status'] as String? ?? '';
    final bookings = _trip!['bookings'] as List? ?? [];
    DateTime? departure;
    try {
      departure = DateTime.parse(_trip!['departureAt']);
    } catch (_) {}

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text('Ride Detail'),
        actions: [
          if (status == 'published')
            IconButton(
              icon: const Icon(Icons.edit_rounded, color: AppColors.driver),
              onPressed: () =>
                  context.push(RouteNames.editRide, extra: widget.tripId),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                child: Column(
                  children: [
                    // Route map
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: RouteMapWidget(
                        originLat: (_trip!['originLat'] ?? 0).toDouble(),
                        originLng: (_trip!['originLng'] ?? 0).toDouble(),
                        originName: _trip!['originName'] ?? '',
                        destLat: (_trip!['destLat'] ?? 0).toDouble(),
                        destLng: (_trip!['destLng'] ?? 0).toDouble(),
                        destName: _trip!['destName'] ?? '',
                        stops: ((_trip!['stops'] as List?) ?? [])
                            .map(
                              (s) => RouteStop(
                                lat: (s['lat'] ?? 0).toDouble(),
                                lng: (s['lng'] ?? 0).toDouble(),
                                name: s['locationName'] ?? '',
                              ),
                            )
                            .toList(),
                        height: 200,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Route card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.driverLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${_trip!['originName']} → ${_trip!['destName']}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.driver,
                                  ),
                                ),
                              ),
                              _StatusChip(status: status),
                            ],
                          ),
                          if (departure != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today_rounded,
                                  size: 14,
                                  color: AppColors.driver,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  DateFormat(
                                    'EEE, d MMM • h:mm a',
                                  ).format(departure),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.driver,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _Stat(
                                label: 'Available',
                                value:
                                    '${_trip!['availableSeats']}/${_trip!['totalSeats']}',
                                icon: Icons.event_seat_rounded,
                              ),
                              _Stat(
                                label: 'Per seat',
                                value:
                                    'NPR ${(_trip!['pricePerSeat'] ?? 0).toStringAsFixed(0)}',
                                icon: Icons.payments_rounded,
                              ),
                              _Stat(
                                label: 'Bookings',
                                value: '${bookings.length}',
                                icon: Icons.confirmation_number_rounded,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Passengers
                    if (bookings.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Passengers',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...bookings.map((b) {
                              final p = b['passenger'] as Map<String, dynamic>?;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  children: [
                                    const CircleAvatar(
                                      radius: 18,
                                      backgroundColor: AppColors.primaryLight,
                                      child: Icon(
                                        Icons.person,
                                        size: 18,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p?['fullName'] ?? 'Passenger',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            '${b['seatsBooked']} seat${(b['seatsBooked'] ?? 1) > 1 ? 's' : ''} • ${(b['status'] ?? '').toUpperCase()}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => context.push(
                                        RouteNames.contactPassenger,
                                        extra: {
                                          'bookingId': b['id'] as String,
                                          'passengerName':
                                              p?['fullName'] ?? 'Passenger',
                                        },
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryLight,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.chat_rounded,
                                              size: 14,
                                              color: AppColors.primary,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Chat',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Action buttons
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (status == 'published') ...[
                    PrimaryButton(
                      text: 'Start Trip',
                      isLoading: _isActing,
                      backgroundColor: AppColors.driver,
                      onPressed: _startTrip,
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(
                          double.infinity,
                          AppSpacing.buttonHeight,
                        ),
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.borderRadius,
                          ),
                        ),
                      ),
                      onPressed: _cancelTrip,
                      child: const Text('Cancel Trip'),
                    ),
                  ],
                  if (status == 'in_progress')
                    PrimaryButton(
                      text: 'Complete Trip',
                      isLoading: _isActing,
                      backgroundColor: AppColors.success,
                      onPressed: _completeTrip,
                    ),
                ],
              ),
            ),
          ],
        ),
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

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _Stat({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: AppColors.driver),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.driver,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.driver),
        ),
      ],
    );
  }
}
