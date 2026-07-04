import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/router/route_names.dart';
import '../../../core/widgets/primary_button.dart';

class BookingConfirmationScreen extends StatelessWidget {
  final Map<String, dynamic> booking;
  const BookingConfirmationScreen({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    final ride = booking['ride'] as Map<String, dynamic>?;
    final driver = ride?['driver'] as Map<String, dynamic>?;

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
          onPressed: () => context.go(RouteNames.passengerHome),
        ),
        title: const Text('Request Submitted'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                child: Column(
                  children: [
                    // Pending badge
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.warning, Color(0xFFE08A00)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.hourglass_top_rounded,
                            color: Colors.white,
                            size: 48,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Awaiting Driver Approval',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'The driver will review your pickup & drop-off and accept or reject your request.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'ID: ${(booking['id'] as String?)?.substring(0, 8).toUpperCase() ?? ''}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Trip details
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
                          _DetailRow(
                            label: 'From',
                            value: ride?['originName'] ?? '',
                          ),
                          _DetailRow(
                            label: 'To',
                            value: ride?['destName'] ?? '',
                          ),
                          if (departure != null)
                            _DetailRow(
                              label: 'Departure',
                              value: DateFormat(
                                'EEE, d MMM • h:mm a',
                              ).format(departure),
                            ),
                          _DetailRow(
                            label: 'Seats',
                            value: '${booking['seatsBooked'] ?? 1}',
                          ),
                          _DetailRow(
                            label: 'Fare',
                            value:
                                'NPR ${(booking['totalAmount'] ?? 0).toStringAsFixed(0)} (pay driver directly)',
                          ),
                          _DetailRow(
                            label: 'Status',
                            value:
                                (booking['status']?.toString().toUpperCase() ??
                                'PENDING'),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Driver details
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
                              'Your Driver',
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
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Bottom buttons
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PrimaryButton(
                    text: 'View My Rides',
                    onPressed: () => context.go(RouteNames.passengerMyRides),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(
                        double.infinity,
                        AppSpacing.buttonHeight,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.borderRadius,
                        ),
                      ),
                    ),
                    onPressed: () => context.go(RouteNames.passengerHome),
                    child: const Text('Back to Home'),
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

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
