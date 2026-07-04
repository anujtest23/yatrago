import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/router/route_names.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/widgets/primary_button.dart';

class UnderReviewScreen extends StatefulWidget {
  const UnderReviewScreen({super.key});

  @override
  State<UnderReviewScreen> createState() => _UnderReviewScreenState();
}

class _UnderReviewScreenState extends State<UnderReviewScreen> {
  bool _isChecking = false;

  Future<void> _checkStatus() async {
    setState(() => _isChecking = true);
    try {
      final response = await DioClient.instance.get('/drivers/status');
      final status = response.data['data']['verificationStatus'] as String?;
      if (!mounted) return;

      if (status == 'approved') {
        context.go(RouteNames.driverApproved);
      } else if (status == 'rejected') {
        context.go(RouteNames.driverRejected);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Still under review. Check back later.'),
          ),
        );
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

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
                  color: AppColors.warningLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.hourglass_top_rounded,
                  size: 52,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Application Under Review',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Our team is reviewing your documents. This usually takes 24-48 hours. We will notify you once approved.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 48),
              PrimaryButton(
                text: 'Check Status',
                isLoading: _isChecking,
                onPressed: _checkStatus,
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
                onPressed: () => context.go(RouteNames.passengerHome),
                child: const Text('Continue as Passenger'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
