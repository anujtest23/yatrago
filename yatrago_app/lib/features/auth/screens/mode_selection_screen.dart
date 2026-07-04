import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/router/route_names.dart';
import '../../../core/storage/secure_storage.dart';

class ModeSelectionScreen extends ConsumerWidget {
  const ModeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              const Text(
                'How will you use\nYatraGo?',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'You can switch between modes anytime from settings.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 48),

              // Passenger card
              _ModeCard(
                icon: Icons.person_rounded,
                title: 'Passenger',
                subtitle:
                    'Find and book seats on intercity rides. Travel comfortably at a shared cost.',
                color: AppColors.primary,
                lightColor: AppColors.primaryLight,
                onTap: () async {
                  await SecureStorage.saveActiveMode('passenger');
                  if (!context.mounted) return;
                  context.go(RouteNames.passengerHome);
                },
              ),

              const SizedBox(height: 16),

              // Driver card
              _ModeCard(
                icon: Icons.drive_eta_rounded,
                title: 'Driver',
                subtitle:
                    'Post your trips and earn money. Share your journey with fellow travellers.',
                color: AppColors.driver,
                lightColor: AppColors.driverLight,
                onTap: () async {
                  await SecureStorage.saveActiveMode('driver');
                  if (!context.mounted) return;
                  context.go(RouteNames.becomeDriver);
                },
              ),

              const Spacer(),

              Center(
                child: TextButton(
                  onPressed: () => context.go(RouteNames.passengerHome),
                  child: const Text(
                    'Decide later',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color lightColor;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.lightColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: lightColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: color),
          ],
        ),
      ),
    );
  }
}
