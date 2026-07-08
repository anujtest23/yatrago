import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/router/route_names.dart';
import '../data/booking_api.dart';

class PassengerRideDetailScreen extends StatefulWidget {
  final String bookingId;
  const PassengerRideDetailScreen({super.key, required this.bookingId});

  @override
  State<PassengerRideDetailScreen> createState() =>
      _PassengerRideDetailScreenState();
}

class _PassengerRideDetailScreenState extends State<PassengerRideDetailScreen> {
  Map<String, dynamic>? _booking;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBooking();
  }

  Future<void> _loadBooking() async {
    try {
      final data = await BookingApi.getBookingById(widget.bookingId);
      if (!mounted) return;
      setState(() {
        _booking = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  bool get _canCancel {
    final status = _booking?['status'];
    return status == 'pending' || status == 'confirmed';
  }

  bool get _canRate {
    return _booking?['status'] == 'completed';
  }

  bool get _canTrack {
    final ride = _booking?['ride'] as Map<String, dynamic>?;
    return ride?['status'] == 'in_progress';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.bgWarm,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_error != null || _booking == null) {
      return Scaffold(
        backgroundColor: AppColors.bgWarm,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: Center(child: Text(_error ?? 'Not found')),
              ),
            ],
          ),
        ),
      );
    }

    final ride = _booking!['ride'] as Map<String, dynamic>?;
    final driver = ride?['driver'] as Map<String, dynamic>?;
    final status = _booking!['status'] as String? ?? '';

    DateTime? departure;
    try {
      if (ride?['departureAt'] != null) {
        departure = DateTime.parse(ride!['departureAt']);
      }
    } catch (_) {}

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
                  children: [
                    _buildStatusCard(status),
                    const SizedBox(height: 16),
                    _buildTripCard(ride, departure),
                    const SizedBox(height: 16),
                    if (driver != null) _buildDriverCard(driver),
                  ],
                ),
              ),
            ),
            _buildActions(context, driver, status),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
            'Ride Detail',
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

  Widget _buildStatusCard(String status) {
    final color = _statusColor(status);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(_statusIcon(status), color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _statusLabel(status),
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                Text(
                  _statusSubtitle(status),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: color.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripCard(Map<String, dynamic>? ride, DateTime? departure) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trip Details',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 14),
          _row('From', ride?['originName'] ?? ''),
          _row('To', ride?['destName'] ?? ''),
          if (departure != null)
            _row(
              'Date & Time',
              DateFormat('EEE, d MMM yyyy • h:mm a').format(departure),
            ),
          _row('Seats', '${_booking!['seatsBooked'] ?? 1}'),
          _row(
            'Amount',
            'NPR ${(_booking!['totalAmount'] ?? 0).toStringAsFixed(0)}',
          ),
          _row(
            'Payment',
            (_booking!['paymentStatus'] ?? '').toString().toUpperCase(),
          ),
          _row(
            'Booking ID',
            widget.bookingId.substring(0, 8).toUpperCase(),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverCard(Map<String, dynamic> driver) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Driver',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primaryLight,
                child: Icon(Icons.person, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver['user']?['fullName'] ?? 'Driver',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      driver['user']?['phoneNumber'] ?? '',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActions(
    BuildContext context,
    Map<String, dynamic>? driver,
    String status,
  ) {
    if (!_canRate && !_canCancel && !_canTrack) {
      return const SizedBox.shrink();
    }

    final ride = _booking!['ride'] as Map<String, dynamic>?;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_canTrack) ...[
            GestureDetector(
              onTap: () => context.push(
                RouteNames.tripTracking,
                extra: {
                  'tripId': ride?['id'] ?? '',
                  'isDriver': false,
                  'originLat': (ride?['originLat'] ?? 0).toDouble(),
                  'originLng': (ride?['originLng'] ?? 0).toDouble(),
                  'originName': ride?['originName'] ?? '',
                  'destLat': (ride?['destLat'] ?? 0).toDouble(),
                  'destLng': (ride?['destLng'] ?? 0).toDouble(),
                  'destName': ride?['destName'] ?? '',
                },
              ),
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.my_location_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Track Live',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_canRate || _canCancel) const SizedBox(height: 10),
          ],
          if (_canRate) ...[
            GestureDetector(
              onTap: () => context.push(
                RouteNames.rateDriver,
                extra: {
                  'bookingId': widget.bookingId,
                  'rateeId': driver?['userId'] ?? '',
                  'driverName': driver?['user']?['fullName'] ?? 'Driver',
                },
              ),
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
                child: Text(
                  'Rate Your Driver',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            if (_canCancel) const SizedBox(height: 10),
          ],
          if (_canCancel)
            GestureDetector(
              onTap: () => context.push(
                RouteNames.cancelBooking,
                extra: widget.bookingId,
              ),
              child: Container(
                width: double.infinity,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.error, width: 1.4),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Cancel Booking',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFF1F5F9)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
        return AppColors.success;
      case 'pending':
        return AppColors.warning;
      case 'completed':
        return AppColors.primary;
      case 'cancelled':
      case 'rejected':
        return AppColors.error;
      default:
        return AppColors.textTertiary;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'confirmed':
        return Icons.check_circle_rounded;
      case 'pending':
        return Icons.schedule_rounded;
      case 'completed':
        return Icons.flag_rounded;
      case 'cancelled':
      case 'rejected':
        return Icons.cancel_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'confirmed':
        return 'Booking Confirmed';
      case 'pending':
        return 'Awaiting Driver Approval';
      case 'completed':
        return 'Trip Completed';
      case 'cancelled':
        return 'Booking Cancelled';
      case 'rejected':
        return 'Booking Rejected';
      default:
        return status;
    }
  }

  String _statusSubtitle(String status) {
    switch (status) {
      case 'confirmed':
        return 'Your seat is reserved';
      case 'pending':
        return 'Driver will confirm shortly';
      case 'completed':
        return 'Hope you had a great trip!';
      case 'cancelled':
        return 'Your booking was cancelled';
      case 'rejected':
        return 'Driver could not accept this booking';
      default:
        return '';
    }
  }
}
