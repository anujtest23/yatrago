import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../../features/passenger/models/ride_model.dart';

class RideCard extends StatelessWidget {
  final RideModel ride;
  final VoidCallback onTap;

  const RideCard({super.key, required this.ride, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final departure = ride.departureAt;
    final dateStr = DateFormat('EEE, d MMM').format(departure);
    final timeStr = DateFormat('h:mm a').format(departure);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Route row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ride.originName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.arrow_downward_rounded,
                            size: 14,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            ride.destName,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'NPR ${ride.pricePerSeat.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const Text(
                      'per seat',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Info row
            Row(
              children: [
                // Date + time
                _InfoChip(
                  icon: Icons.calendar_today_rounded,
                  label: '$dateStr • $timeStr',
                ),
                const SizedBox(width: 8),
                // Seats
                _InfoChip(
                  icon: Icons.event_seat_rounded,
                  label: '${ride.availableSeats} seats',
                ),
                if (ride.womenOnly) ...[
                  const SizedBox(width: 8),
                  _InfoChip(
                    icon: Icons.female_rounded,
                    label: 'Women only',
                    color: Colors.pink,
                  ),
                ],
              ],
            ),

            const SizedBox(height: 12),

            // Driver row
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primaryLight,
                  backgroundImage: ride.driver.profilePhotoUrl != null
                      ? NetworkImage(ride.driver.profilePhotoUrl!)
                      : null,
                  child: ride.driver.profilePhotoUrl == null
                      ? const Icon(
                          Icons.person,
                          size: 18,
                          color: AppColors.primary,
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Text(
                  ride.driver.fullName ?? 'Driver',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.star_rounded, size: 14, color: AppColors.star),
                const SizedBox(width: 2),
                Text(
                  ride.driver.averageRating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  '${ride.vehicle.make} ${ride.vehicle.model}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _InfoChip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.borderLight,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color ?? AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color ?? AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
