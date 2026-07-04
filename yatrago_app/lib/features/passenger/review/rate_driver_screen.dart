import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/primary_button.dart';
import 'package:dio/dio.dart';

class RateDriverScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  const RateDriverScreen({super.key, required this.data});

  @override
  State<RateDriverScreen> createState() => _RateDriverScreenState();
}

class _RateDriverScreenState extends State<RateDriverScreen> {
  int _rating = 0;
  final _reviewController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  final List<String> _quickTags = [
    'Great driver',
    'Very punctual',
    'Safe driving',
    'Friendly',
    'Clean car',
    'Good music',
  ];
  final Set<String> _selectedTags = {};

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      setState(() => _error = 'Please select a rating');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final tags = _selectedTags.join(', ');
      final review = _reviewController.text.trim();
      final fullReview = [
        if (tags.isNotEmpty) tags,
        if (review.isNotEmpty) review,
      ].join('. ');

      await DioClient.instance.post(
        '/reviews',
        data: {
          'bookingId': widget.data['bookingId'],
          'rateeId': widget.data['rateeId'],
          'rateeType': 'driver',
          'score': _rating,
          if (fullReview.isNotEmpty) 'reviewText': fullReview,
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Review submitted. Thank you!'),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop();
    } on DioException catch (e) {
      setState(() => _error = ApiException.fromDioError(e).message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final driverName = widget.data['driverName'] as String? ?? 'Driver';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text('Rate Your Driver'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // Driver avatar
              const CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.primaryLight,
                child: Icon(
                  Icons.person_rounded,
                  size: 44,
                  color: AppColors.primary,
                ),
              ),

              const SizedBox(height: 14),

              Text(
                'How was your ride with $driverName?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                'Your feedback helps other passengers',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
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

              if (_rating > 0) ...[
                const SizedBox(height: 8),
                Text(
                  _ratingLabel(_rating),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.star,
                  ),
                ),
              ],

              const SizedBox(height: 28),

              // Quick tags
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: _quickTags.map((tag) {
                  final selected = _selectedTags.contains(tag);
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (selected) {
                        _selectedTags.remove(tag);
                      } else {
                        _selectedTags.add(tag);
                      }
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary : Colors.white,
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: selected
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // Review text
              TextField(
                controller: _reviewController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Share more about your experience (optional)...',
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
                text: 'Submit Review',
                isLoading: _isLoading,
                onPressed: _submit,
              ),

              const SizedBox(height: 12),

              TextButton(
                onPressed: () => context.pop(),
                child: const Text(
                  'Skip for now',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
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
