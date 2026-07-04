import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/router/route_names.dart';
import '../../../core/widgets/primary_button.dart';
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_error != null || _booking == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ride Detail')),
        body: Center(child: Text(_error ?? 'Not found')),
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text('Ride Detail'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                child: Column(
                  children: [
                    // Status card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _statusColor(status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _statusColor(status).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _statusIcon(status),
                            color: _statusColor(status),
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _statusLabel(status),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: _statusColor(status),
                                ),
                              ),
                              Text(
                                _statusSubtitle(status),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _statusColor(status).withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Trip info
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
                            'Trip Details',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _Row('From', ride?['originName'] ?? ''),
                          _Row('To', ride?['destName'] ?? ''),
                          if (departure != null)
                            _Row(
                              'Date & Time',
                              DateFormat(
                                'EEE, d MMM yyyy • h:mm a',
                              ).format(departure),
                            ),
                          _Row('Seats', '${_booking!['seatsBooked'] ?? 1}'),
                          _Row(
                            'Amount',
                            'NPR ${(_booking!['totalAmount'] ?? 0).toStringAsFixed(0)}',
                          ),
                          _Row(
                            'Payment',
                            (_booking!['paymentStatus'] ?? '')
                                .toString()
                                .toUpperCase(),
                          ),
                          _Row(
                            'Booking ID',
                            (widget.bookingId).substring(0, 8).toUpperCase(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Driver info
                    if (driver != null)
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
                              'Driver',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const CircleAvatar(
                                  radius: 24,
                                  backgroundColor: AppColors.primaryLight,
                                  child: Icon(
                                    Icons.person,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        driver['user']?['fullName'] ?? 'Driver',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        driver['user']?['phoneNumber'] ?? '',
                                        style: const TextStyle(
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
                      ),
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
                  if (_canRate) ...[
                    PrimaryButton(
                      text: 'Rate Your Driver',
                      onPressed: () => context.push(
                        RouteNames.rateDriver,
                        extra: {
                          'bookingId': widget.bookingId,
                          'rateeId': driver?['userId'] ?? '',
                          'driverName':
                              driver?['user']?['fullName'] ?? 'Driver',
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (_canCancel)
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
                      onPressed: () => context.push(
                        RouteNames.cancelBooking,
                        extra: widget.bookingId,
                      ),
                      child: const Text('Cancel Booking'),
                    ),
                ],
              ),
            ),
          ],
        ),
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

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
