import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/booking_route_map.dart';
import 'package:dio/dio.dart';

class PassengerDetailsScreen extends StatefulWidget {
  final String bookingId;
  const PassengerDetailsScreen({super.key, required this.bookingId});

  @override
  State<PassengerDetailsScreen> createState() => _PassengerDetailsScreenState();
}

class _PassengerDetailsScreenState extends State<PassengerDetailsScreen> {
  Map<String, dynamic>? _booking;
  bool _isLoading = true;
  bool _isActing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await DioClient.instance.get(
        '/bookings/${widget.bookingId}',
      );
      setState(() {
        _booking = response.data['data'];
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _accept() async {
    setState(() => _isActing = true);
    try {
      await DioClient.instance.patch('/bookings/${widget.bookingId}/accept');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking accepted'),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop();
    } on DioException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiException.fromDioError(e).message)),
      );
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _reject() async {
    setState(() => _isActing = true);
    try {
      await DioClient.instance.patch(
        '/bookings/${widget.bookingId}/reject',
        data: {'reason': 'Sorry, cannot accommodate'},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Booking rejected')));
      context.pop();
    } on DioException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiException.fromDioError(e).message)),
      );
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.driver)),
      );
    }

    final passenger = _booking?['passenger'] as Map<String, dynamic>?;
    final ride = _booking?['ride'] as Map<String, dynamic>?;
    final rating = _booking?['passengerRating'] as Map<String, dynamic>?;
    final isPending = _booking?['status'] == 'pending';

    final ratingAvg = (rating?['average'] as num?)?.toDouble() ?? 0;
    final ratingCount = (rating?['count'] as num?)?.toInt() ?? 0;

    final pickupLat = (_booking?['pickupLat'] as num?)?.toDouble();
    final pickupLng = (_booking?['pickupLng'] as num?)?.toDouble();
    final dropLat = (_booking?['dropLat'] as num?)?.toDouble();
    final dropLng = (_booking?['dropLng'] as num?)?.toDouble();
    final pickupName = _booking?['pickupName'] as String?;
    final dropName = _booking?['dropName'] as String?;

    final originLat = (ride?['originLat'] as num?)?.toDouble();
    final originLng = (ride?['originLng'] as num?)?.toDouble();
    final destLat = (ride?['destLat'] as num?)?.toDouble();
    final destLng = (ride?['destLng'] as num?)?.toDouble();

    final hasMap = pickupLat != null &&
        pickupLng != null &&
        dropLat != null &&
        dropLng != null &&
        originLat != null &&
        originLng != null &&
        destLat != null &&
        destLng != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text('Passenger Details'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                child: Column(
                  children: [
                    // Passenger card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.borderLight,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const CircleAvatar(
                            radius: 40,
                            backgroundColor: AppColors.primaryLight,
                            child: Icon(
                              Icons.person,
                              size: 44,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            passenger?['fullName'] ?? 'Passenger',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            passenger?['phoneNumber'] ?? '',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Passenger rating
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 18,
                                color: AppColors.star,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                ratingCount > 0
                                    ? '${ratingAvg.toStringAsFixed(1)} ($ratingCount)'
                                    : 'No ratings yet',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Booking details
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Column(
                        children: [
                          _Row('Seats', '${_booking?['seatsBooked'] ?? 1}'),
                          _Row(
                            'Fare',
                            'NPR ${(_booking?['totalAmount'] ?? 0).toStringAsFixed(0)}',
                          ),
                          _Row('Pickup', pickupName ?? '—'),
                          _Row('Drop-off', dropName ?? '—'),
                          _Row(
                            'Status',
                            (_booking?['status'] ?? '')
                                .toString()
                                .toUpperCase(),
                          ),
                        ],
                      ),
                    ),

                    // Route + deviation map
                    if (hasMap) ...[
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: const Text(
                          'Pickup & Drop-off vs Your Route',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      BookingRouteMap(
                        driverOrigin: LatLng(originLat, originLng),
                        driverDest: LatLng(destLat, destLng),
                        pickup: LatLng(pickupLat, pickupLng),
                        drop: LatLng(dropLat, dropLng),
                        pickupName: pickupName ?? 'Pickup',
                        dropName: dropName ?? 'Drop-off',
                      ),
                    ],
                  ],
                ),
              ),
            ),

            if (isPending)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
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
                        onPressed: _isActing ? null : _reject,
                        child: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PrimaryButton(
                        text: 'Accept',
                        isLoading: _isActing,
                        backgroundColor: AppColors.driver,
                        onPressed: _accept,
                      ),
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

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
