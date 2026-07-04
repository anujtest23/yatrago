import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/router/route_names.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/location_picker_screen.dart';
import '../../../core/widgets/route_map_widget.dart';
import '../data/booking_api.dart';
import '../models/ride_model.dart';

class BookingSummaryScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  const BookingSummaryScreen({super.key, required this.data});

  @override
  State<BookingSummaryScreen> createState() => _BookingSummaryScreenState();
}

class _BookingSummaryScreenState extends State<BookingSummaryScreen> {
  final _couponController = TextEditingController();
  bool _showCoupon = false;
  bool _isSubmitting = false;
  late RideModel _ride;
  late int _seats;
  late double _total;

  // Passenger pickup / drop-off. Defaults to the passenger's search points if
  // supplied, otherwise to the ride's origin/destination. Adjustable on a map.
  late double _pickupLat;
  late double _pickupLng;
  late String _pickupName;
  late double _dropLat;
  late double _dropLng;
  late String _dropName;

  @override
  void initState() {
    super.initState();
    _ride = RideModel.fromJson(widget.data['ride']);
    _seats = widget.data['seats'];
    _total = widget.data['total'].toDouble();

    _pickupLat = (widget.data['pickupLat'] as num?)?.toDouble() ?? _ride.originLat;
    _pickupLng = (widget.data['pickupLng'] as num?)?.toDouble() ?? _ride.originLng;
    _pickupName = widget.data['pickupName'] as String? ?? _ride.originName;
    _dropLat = (widget.data['dropLat'] as num?)?.toDouble() ?? _ride.destLat;
    _dropLng = (widget.data['dropLng'] as num?)?.toDouble() ?? _ride.destLng;
    _dropName = widget.data['dropName'] as String? ?? _ride.destName;
  }

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _adjustPoint({required bool isPickup}) async {
    final result = await Navigator.push<LocationPickerResult>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          title: isPickup ? 'Pickup' : 'Drop-off',
          initialPosition: isPickup
              ? LatLng(_pickupLat, _pickupLng)
              : LatLng(_dropLat, _dropLng),
        ),
      ),
    );
    if (result == null) return;
    setState(() {
      if (isPickup) {
        _pickupLat = result.lat;
        _pickupLng = result.lng;
        _pickupName = result.name;
      } else {
        _dropLat = result.lat;
        _dropLng = result.lng;
        _dropName = result.name;
      }
    });
  }

  Future<void> _submitRequest() async {
    setState(() => _isSubmitting = true);
    try {
      final coupon = _couponController.text.trim();
      final result = await BookingApi.createBooking(
        rideId: _ride.id,
        seatsBooked: _seats,
        pickupLat: _pickupLat,
        pickupLng: _pickupLng,
        pickupName: _pickupName,
        dropLat: _dropLat,
        dropLng: _dropLng,
        dropName: _dropName,
        couponCode: coupon.isEmpty ? null : coupon,
      );
      if (!mounted) return;
      context.pushReplacement(
        RouteNames.bookingConfirmation,
        extra: result['booking'],
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not submit request')));
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
        title: const Text('Booking Summary'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Route card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Column(
                        children: [
                          // Origin
                          Row(
                            children: [
                              const Icon(
                                Icons.trip_origin_rounded,
                                color: AppColors.primary,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _ride.originName,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                DateFormat('h:mm a').format(_ride.departureAt),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Column(
                              children: List.generate(
                                3,
                                (_) => Container(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  width: 2,
                                  height: 5,
                                  color: AppColors.border,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Destination
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_rounded,
                                color: AppColors.error,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _ride.destName,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          // Date
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_rounded,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat(
                                  'EEEE, d MMMM yyyy',
                                ).format(_ride.departureAt),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Your pickup & drop-off (adjustable on the map)
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
                            'Your Pickup & Drop-off',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'The driver sees these points to decide on your request. Tap to adjust.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 12),
                          RouteMapWidget(
                            key: ValueKey(
                              '$_pickupLat,$_pickupLng,$_dropLat,$_dropLng',
                            ),
                            originLat: _pickupLat,
                            originLng: _pickupLng,
                            originName: _pickupName,
                            destLat: _dropLat,
                            destLng: _dropLng,
                            destName: _dropName,
                            height: 180,
                          ),
                          const SizedBox(height: 12),
                          _PointRow(
                            icon: Icons.trip_origin_rounded,
                            iconColor: AppColors.primary,
                            label: 'Pickup',
                            value: _pickupName,
                            onEdit: () => _adjustPoint(isPickup: true),
                          ),
                          const SizedBox(height: 10),
                          _PointRow(
                            icon: Icons.location_on_rounded,
                            iconColor: AppColors.error,
                            label: 'Drop-off',
                            value: _dropName,
                            onEdit: () => _adjustPoint(isPickup: false),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Driver + vehicle
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: AppColors.primaryLight,
                            child: const Icon(
                              Icons.person,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _ride.driver.fullName ?? 'Driver',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${_ride.vehicle.make} ${_ride.vehicle.model}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 14,
                                color: AppColors.star,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                _ride.driver.averageRating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Price breakdown
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Column(
                        children: [
                          _PriceRow(
                            label: 'Price per seat × $_seats',
                            value:
                                'NPR ${_ride.pricePerSeat.toStringAsFixed(0)} × $_seats',
                          ),
                          const SizedBox(height: 10),
                          const Divider(height: 1),
                          const SizedBox(height: 10),
                          _PriceRow(
                            label: 'Total',
                            value: 'NPR ${_total.toStringAsFixed(0)}',
                            isTotal: true,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Coupon
                    GestureDetector(
                      onTap: () => setState(() => _showCoupon = !_showCoupon),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.local_offer_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Apply coupon code',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.primary,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              _showCoupon
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              color: AppColors.textTertiary,
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (_showCoupon) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _couponController,
                              textCapitalization: TextCapitalization.characters,
                              decoration: const InputDecoration(
                                hintText: 'Enter coupon code',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                            child: const Text('Apply'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Bottom bar
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Fare (pay driver directly)',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        'NPR ${_total.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    text: 'Request to Book',
                    isLoading: _isSubmitting,
                    onPressed: _submitRequest,
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

class _PointRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final VoidCallback onEdit;

  const _PointRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_location_alt_outlined, size: 16),
          label: const Text('Adjust', style: TextStyle(fontSize: 12)),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 32),
          ),
        ),
      ],
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;

  const _PriceRow({
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 15 : 14,
            fontWeight: isTotal ? FontWeight.w600 : FontWeight.w400,
            color: isTotal ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 17 : 14,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
            color: isTotal ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
