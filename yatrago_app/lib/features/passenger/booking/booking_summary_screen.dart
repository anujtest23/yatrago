import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/router/route_names.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/location_picker_screen.dart';
import '../../../core/widgets/route_map_widget.dart';
import '../data/booking_api.dart';
import '../../shared/coupons/data/coupon_api.dart';
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
  late double _total; // payable after any discount
  late double _gross; // fare before discount
  double _discount = 0;
  String? _appliedCode;
  bool _couponBusy = false;
  String? _couponError;

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
    _gross = widget.data['total'].toDouble();
    _total = _gross;

    _pickupLat =
        (widget.data['pickupLat'] as num?)?.toDouble() ?? _ride.originLat;
    _pickupLng =
        (widget.data['pickupLng'] as num?)?.toDouble() ?? _ride.originLng;
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

  // Server-computed coupon preview. The app never calculates the discount —
  // it displays what the backend returns and passes the raw code on booking.
  Future<void> _applyCoupon() async {
    final code = _couponController.text.trim();
    if (code.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _couponBusy = true;
      _couponError = null;
    });
    try {
      final quote = await CouponApi.validate(code: code, amount: _gross);
      if (!mounted) return;
      setState(() {
        _discount = (quote['discountAmount'] as num).toDouble();
        _total = (quote['finalAmount'] as num).toDouble();
        _appliedCode = (quote['code'] as String?) ?? code;
        _couponBusy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _discount = 0;
        _total = _gross;
        _appliedCode = null;
        _couponError = e.toString();
        _couponBusy = false;
      });
    }
  }

  void _clearCoupon() {
    setState(() {
      _couponController.clear();
      _discount = 0;
      _total = _gross;
      _appliedCode = null;
      _couponError = null;
    });
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
      // Only send a coupon that was validated (applied). An unpreviewed code
      // would just be re-validated (and possibly rejected) by the server.
      final result = await BookingApi.createBooking(
        rideId: _ride.id,
        seatsBooked: _seats,
        pickupLat: _pickupLat,
        pickupLng: _pickupLng,
        pickupName: _pickupName,
        dropLat: _dropLat,
        dropLng: _dropLng,
        dropName: _dropName,
        couponCode: _appliedCode,
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
      backgroundColor: AppColors.bgWarm,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFareCard(),
                    const SizedBox(height: 16),
                    _buildPickupDropCard(),
                    const SizedBox(height: 16),
                    _buildDriverCard(),
                    const SizedBox(height: 16),
                    _buildCouponCard(),
                  ],
                ),
              ),
            ),
            _buildBottomBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: AppColors.textPrimary,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            'Booking Summary',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════
  // FARE CARD — Yatri payment_page "Total Fare" treatment
  // ════════════════════════════════════════════════════
  Widget _buildFareCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFECEB),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.route_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Fare',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF718096),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_ride.originName} → ${_ride.destName}',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E293B),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('EEE, d MMM • h:mm a').format(_ride.departureAt),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF718096),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(color: Color(0xFFF1F5F9), height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'NPR ${_ride.pricePerSeat.toStringAsFixed(0)} × $_seats ${_seats == 1 ? 'seat' : 'seats'}',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF4A5568),
                ),
              ),
              Text(
                'NPR ${_total.toStringAsFixed(0)}',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: AppColors.textTertiary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Pay the driver directly on the day of travel.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════
  // PICKUP & DROP-OFF — real route map, adjustable
  // ════════════════════════════════════════════════════
  Widget _buildPickupDropCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Pickup & Drop-off',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'The driver sees these points to decide on your request. Tap to adjust.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: RouteMapWidget(
              key: ValueKey('$_pickupLat,$_pickupLng,$_dropLat,$_dropLng'),
              originLat: _pickupLat,
              originLng: _pickupLng,
              originName: _pickupName,
              destLat: _dropLat,
              destLng: _dropLng,
              destName: _dropName,
              height: 180,
            ),
          ),
          const SizedBox(height: 12),
          _PointRow(
            icon: Icons.trip_origin_rounded,
            iconColor: const Color(0xFF16A34A),
            label: 'Pickup',
            value: _pickupName,
            onEdit: () => _adjustPoint(isPickup: true),
          ),
          const SizedBox(height: 10),
          _PointRow(
            icon: Icons.location_on_rounded,
            iconColor: AppColors.primary,
            label: 'Drop-off',
            value: _dropName,
            onEdit: () => _adjustPoint(isPickup: false),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════
  // DRIVER CARD
  // ════════════════════════════════════════════════════
  Widget _buildDriverCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primaryLight,
            child: const Icon(Icons.person, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _ride.driver.fullName ?? 'Driver',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                Text(
                  '${_ride.vehicle.make} ${_ride.vehicle.model}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              const Icon(Icons.star_rounded, size: 14, color: AppColors.star),
              const SizedBox(width: 3),
              Text(
                _ride.driver.averageRating.toStringAsFixed(1),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════
  // COUPON CARD
  // ════════════════════════════════════════════════════
  Widget _buildCouponCard() {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _showCoupon = !_showCoupon),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFECEB),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.local_offer_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Apply coupon code',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
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
          if (_showCoupon)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _couponController,
                          enabled: _appliedCode == null,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            hintText: 'Enter coupon code',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _couponBusy
                            ? null
                            : (_appliedCode != null
                                ? _clearCoupon
                                : _applyCoupon),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        child: _couponBusy
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : Text(_appliedCode != null ? 'Remove' : 'Apply'),
                      ),
                    ],
                  ),
                  if (_couponError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _couponError!,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  if (_appliedCode != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              size: 16, color: Color(0xFF16A34A)),
                          const SizedBox(width: 6),
                          Text(
                            'Coupon $_appliedCode applied — NPR ${_discount.toStringAsFixed(0)} off',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration({double radius = 20}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgWarm,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Fare (pay driver directly)',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                'NPR ${_total.toStringAsFixed(0)}',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _isSubmitting ? null : _submitRequest,
            child: Container(
              width: double.infinity,
              height: 54,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'Request to Book',
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
            ),
          ),
        ],
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
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
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
