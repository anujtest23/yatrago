import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/router/route_names.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/widgets/primary_button.dart';

class ApprovedScreen extends StatelessWidget {
  const ApprovedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: AppColors.successLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  size: 56,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'You are Approved!',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Congratulations! Your driver application has been approved. You can now start posting rides and earning money.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 48),
              PrimaryButton(
                text: 'Go to Driver Dashboard',
                backgroundColor: AppColors.driver,
                onPressed: () async {
                  await SecureStorage.saveActiveMode('driver');
                  if (!context.mounted) return;
                  context.go(RouteNames.driverDashboard);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
