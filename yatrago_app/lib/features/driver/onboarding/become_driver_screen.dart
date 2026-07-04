import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/router/route_names.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/primary_button.dart';
import 'package:dio/dio.dart';

class BecomeDriverScreen extends StatefulWidget {
  const BecomeDriverScreen({super.key});

  @override
  State<BecomeDriverScreen> createState() => _BecomeDriverScreenState();
}

class _BecomeDriverScreenState extends State<BecomeDriverScreen> {
  bool _isLoading = false;

  final List<Map<String, dynamic>> _requirements = [
    {
      'icon': Icons.credit_card_rounded,
      'title': 'Citizenship Certificate',
      'subtitle': 'Front and back photo',
    },
    {
      'icon': Icons.drive_eta_rounded,
      'title': 'Driving License',
      'subtitle': 'Front and back photo',
    },
    {
      'icon': Icons.face_rounded,
      'title': 'Selfie Verification',
      'subtitle': 'Clear photo of your face',
    },
    {
      'icon': Icons.directions_car_rounded,
      'title': 'Vehicle Information',
      'subtitle': 'Make, model, plate number',
    },
    {
      'icon': Icons.description_rounded,
      'title': 'Vehicle Documents',
      'subtitle': 'Bluebook (vehicle registration)',
    },
  ];

  Future<void> _apply() async {
    setState(() => _isLoading = true);
    try {
      await DioClient.instance.post('/drivers/apply');
      if (!mounted) return;
      context.pushReplacement(RouteNames.driverOnboarding);
    } on DioException catch (e) {
      final err = ApiException.fromDioError(e);
      if (!mounted) return;
      // Already applied — go straight to onboarding
      if (e.response?.statusCode == 409 || err.message.contains('already')) {
        context.pushReplacement(RouteNames.driverOnboarding);
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(err.message)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
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
                    // Header
                    Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.driverLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.drive_eta_rounded,
                          size: 44,
                          color: AppColors.driver,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Center(
                      child: Text(
                        'Become a Driver',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Center(
                      child: Text(
                        'Earn money by sharing your trips with\nfellow travellers across Nepal.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),

                    const Text(
                      'What you will need',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    ..._requirements.map(
                      (req) => Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.borderLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.driverLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                req['icon'] as IconData,
                                size: 22,
                                color: AppColors.driver,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    req['title'] as String,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    req['subtitle'] as String,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.success,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            color: AppColors.primary,
                            size: 18,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Verification takes 24-48 hours after you submit all documents.',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.primary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: PrimaryButton(
                text: 'Start Verification',
                isLoading: _isLoading,
                backgroundColor: AppColors.driver,
                onPressed: _apply,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
