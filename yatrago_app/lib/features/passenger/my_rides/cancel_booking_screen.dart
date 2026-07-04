import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/booking_api.dart';

class CancelBookingScreen extends StatefulWidget {
  final String bookingId;
  const CancelBookingScreen({super.key, required this.bookingId});

  @override
  State<CancelBookingScreen> createState() => _CancelBookingScreenState();
}

class _CancelBookingScreenState extends State<CancelBookingScreen> {
  String? _selectedReason;
  final _otherController = TextEditingController();
  bool _isLoading = false;

  final List<String> _reasons = [
    'Change of plans',
    'Found another ride',
    'Emergency',
    'Driver not responding',
    'Incorrect booking details',
    'Other',
  ];

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  Future<void> _cancel() async {
    if (_selectedReason == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a reason')));
      return;
    }

    final reason = _selectedReason == 'Other'
        ? _otherController.text.trim()
        : _selectedReason!;

    setState(() => _isLoading = true);

    try {
      await BookingApi.cancelBooking(widget.bookingId, reason: reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking cancelled successfully'),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop();
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
      );
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
        title: const Text('Cancel Booking'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Warning
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.warning,
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Cancelling close to departure may affect your rating.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.warning,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              const Text(
                'Reason for cancellation',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 14),

              // Reason list
              ...(_reasons.map(
                (reason) => GestureDetector(
                  onTap: () => setState(() => _selectedReason = reason),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: _selectedReason == reason
                            ? AppColors.primary
                            : AppColors.border,
                        width: _selectedReason == reason ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            reason,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: _selectedReason == reason
                                  ? FontWeight.w500
                                  : FontWeight.w400,
                              color: _selectedReason == reason
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _selectedReason == reason
                                  ? AppColors.primary
                                  : AppColors.border,
                              width: 2,
                            ),
                            color: _selectedReason == reason
                                ? AppColors.primary
                                : Colors.transparent,
                          ),
                          child: _selectedReason == reason
                              ? const Icon(
                                  Icons.check_rounded,
                                  size: 12,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              )),

              // Other text field
              if (_selectedReason == 'Other') ...[
                const SizedBox(height: 4),
                TextField(
                  controller: _otherController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Please describe your reason...',
                  ),
                ),
              ],

              const Spacer(),

              PrimaryButton(
                text: 'Confirm Cancellation',
                isLoading: _isLoading,
                backgroundColor: AppColors.error,
                onPressed: _cancel,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
