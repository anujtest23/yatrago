import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/router/route_names.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/widgets/primary_button.dart';

class RejectedScreen extends StatefulWidget {
  const RejectedScreen({super.key});

  @override
  State<RejectedScreen> createState() => _RejectedScreenState();
}

class _RejectedScreenState extends State<RejectedScreen> {
  String? _reason;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReason();
  }

  Future<void> _loadReason() async {
    try {
      final response = await DioClient.instance.get('/drivers/status');
      setState(() {
        _reason = response.data['data']['rejectionReason'];
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
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
                  color: AppColors.errorLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cancel_rounded,
                  size: 56,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Application Not Approved',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Unfortunately your application was not approved. Please review the reason and resubmit.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
              if (_reason != null && _reason!.isNotEmpty) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.errorLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.error,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _reason!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.error,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 48),
              PrimaryButton(
                text: 'Resubmit Documents',
                backgroundColor: AppColors.driver,
                onPressed: () => context.go(RouteNames.driverOnboarding),
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
