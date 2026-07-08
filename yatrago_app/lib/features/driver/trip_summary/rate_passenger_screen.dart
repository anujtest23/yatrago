import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/router/route_names.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/primary_button.dart';

class RatePassengerScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  const RatePassengerScreen({super.key, required this.data});

  @override
  State<RatePassengerScreen> createState() => _RatePassengerScreenState();
}

class _RatePassengerScreenState extends State<RatePassengerScreen> {
  int _rating = 5;
  final _reviewController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  String? _tripId;

  @override
  void initState() {
    super.initState();
    _tripId = widget.data['tripId'];
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_tripId == null) {
      context.go(RouteNames.driverDashboard);
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get completed bookings for this trip and rate each passenger
      final response = await DioClient.instance.get('/trips/$_tripId');
      final bookings = response.data['data']['bookings'] as List? ?? [];

      for (final booking in bookings) {
        if (booking['status'] == 'completed') {
          try {
            await DioClient.instance.post(
              '/reviews',
              data: {
                'bookingId': booking['id'],
                'rateeId': booking['passengerId'],
                'rateeType': 'passenger',
                'score': _rating,
                if (_reviewController.text.trim().isNotEmpty)
                  'reviewText': _reviewController.text.trim(),
              },
            );
          } catch (_) {}
        }
      }

      if (!mounted) return;
      context.go(RouteNames.driverDashboard);
    } on DioException catch (e) {
      setState(() => _error = ApiException.fromDioError(e).message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgWarm,
      body: SafeArea(
        child: Column(
          children: [
            _Header(onBack: () => context.pop()),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                child: Column(
                  children: [
                    const SizedBox(height: 12),

              const CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.driverLight,
                child: Icon(
                  Icons.people_rounded,
                  size: 44,
                  color: AppColors.driver,
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                'How were your passengers?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Stars
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  return GestureDetector(
                    onTap: () => setState(() => _rating = i + 1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        i < _rating
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        size: 44,
                        color: i < _rating ? AppColors.star : AppColors.border,
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 8),

              Text(
                _ratingLabel(_rating),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.star,
                ),
              ),

              const SizedBox(height: 28),

              TextField(
                controller: _reviewController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Any comments about your passengers? (optional)',
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ],

              const SizedBox(height: 32),

              PrimaryButton(
                text: 'Submit Rating',
                isLoading: _isLoading,
                backgroundColor: AppColors.driver,
                onPressed: _submit,
              ),

              const SizedBox(height: 12),

              TextButton(
                onPressed: () => context.go(RouteNames.driverDashboard),
                child: const Text(
                  'Skip',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _ratingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Very Good';
      case 5:
        return 'Excellent!';
      default:
        return '';
    }
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onBack;
  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
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
                color: AppColors.driver,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            'Rate Passengers',
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
}
