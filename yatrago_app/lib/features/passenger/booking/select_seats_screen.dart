import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/router/route_names.dart';
import '../../../core/widgets/primary_button.dart';
import '../models/ride_model.dart';

class SelectSeatsScreen extends StatefulWidget {
  final Map<String, dynamic> ride;
  const SelectSeatsScreen({super.key, required this.ride});

  @override
  State<SelectSeatsScreen> createState() => _SelectSeatsScreenState();
}

class _SelectSeatsScreenState extends State<SelectSeatsScreen> {
  int _seats = 1;
  late RideModel _ride;

  @override
  void initState() {
    super.initState();
    _ride = RideModel.fromJson(widget.ride);
  }

  double get _total => _ride.pricePerSeat * _seats;

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
        title: const Text('Select Seats'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Route summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.directions_car_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${_ride.originName} → ${_ride.destName}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    Text(
                      DateFormat('d MMM').format(_ride.departureAt),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Price per seat
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Price per seat',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    'NPR ${_ride.pricePerSeat.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Available seats',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    '${_ride.availableSeats} seats',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // Seat counter
              const Text(
                'How many seats?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Minus
                  GestureDetector(
                    onTap: () {
                      if (_seats > 1) setState(() => _seats--);
                    },
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: _seats > 1
                            ? AppColors.primaryLight
                            : AppColors.borderLight,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _seats > 1
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                      ),
                      child: Icon(
                        Icons.remove_rounded,
                        size: 24,
                        color: _seats > 1
                            ? AppColors.primary
                            : AppColors.textTertiary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 32),
                  // Count
                  Column(
                    children: [
                      Text(
                        '$_seats',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'seat${_seats > 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 32),
                  // Plus
                  GestureDetector(
                    onTap: () {
                      if (_seats < _ride.availableSeats) {
                        setState(() => _seats++);
                      }
                    },
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: _seats < _ride.availableSeats
                            ? AppColors.primaryLight
                            : AppColors.borderLight,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _seats < _ride.availableSeats
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                      ),
                      child: Icon(
                        Icons.add_rounded,
                        size: 24,
                        color: _seats < _ride.availableSeats
                            ? AppColors.primary
                            : AppColors.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Total
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total amount',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'NPR ${_total.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              PrimaryButton(
                text: 'Continue',
                onPressed: () => context.push(
                  RouteNames.bookingSummary,
                  extra: {
                    'ride': widget.ride,
                    'seats': _seats,
                    'total': _total,
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
