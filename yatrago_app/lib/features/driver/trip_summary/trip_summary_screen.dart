import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/router/route_names.dart';
import '../../../core/widgets/primary_button.dart';

class TripSummaryScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  const TripSummaryScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final totalPassengers = data['totalPassengers'] ?? 0;
    final totalEarnings = (data['totalEarnings'] ?? 0).toDouble();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            children: [
              const Spacer(),

              // Success icon
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: AppColors.driverLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.flag_rounded,
                  size: 56,
                  color: AppColors.driver,
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Trip Completed!',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                'Great job! You successfully completed this trip.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 32),

              // Earnings summary
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.driverLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Trip Earnings',
                      style: TextStyle(fontSize: 14, color: AppColors.driver),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'NPR ${totalEarnings.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: AppColors.driver,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$totalPassengers passenger${totalPassengers != 1 ? 's' : ''}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.driver,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              PrimaryButton(
                text: 'Rate Passengers',
                backgroundColor: AppColors.driver,
                onPressed: () =>
                    context.push(RouteNames.ratePassenger, extra: data),
              ),

              const SizedBox(height: 12),

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
                onPressed: () => context.go(RouteNames.driverDashboard),
                child: const Text('Back to Dashboard'),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
