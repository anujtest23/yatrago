import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/router/route_names.dart';
import '../../../core/widgets/primary_button.dart';
import '../models/ride_model.dart';

import '../../../core/widgets/route_map_widget.dart';

class RideDetailScreen extends StatelessWidget {
  final Map<String, dynamic> ride;
  const RideDetailScreen({super.key, required this.ride});

  @override
  Widget build(BuildContext context) {
    final rideModel = RideModel.fromJson(ride);
    final departure = rideModel.departureAt;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text('Ride Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: AppColors.primary),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Route map
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: RouteMapWidget(
                originLat: rideModel.originLat,
                originLng: rideModel.originLng,
                originName: rideModel.originName,
                destLat: rideModel.destLat,
                destLng: rideModel.destLng,
                destName: rideModel.destName,
                stops: rideModel.stops
                    .map(
                      (s) => RouteStop(
                        lat: s.lat,
                        lng: s.lng,
                        name: s.locationName,
                      ),
                    )
                    .toList(),
              ),
            ),

            // Route card
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: Column(
                children: [
                  // Origin
                  Row(
                    children: [
                      const _RouteIcon(
                        icon: Icons.trip_origin_rounded,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rideModel.originName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              DateFormat(
                                'EEEE, d MMM • h:mm a',
                              ).format(departure),
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Stops
                  if (rideModel.stops.isNotEmpty)
                    ...rideModel.stops.map(
                      (stop) => Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Row(
                          children: [
                            const _RouteIcon(
                              icon: Icons.circle_outlined,
                              color: AppColors.textTertiary,
                              size: 16,
                            ),
                            const SizedBox(width: 14),
                            Text(
                              stop.locationName,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            if (stop.minutesFromStart != null) ...[
                              const Spacer(),
                              Text(
                                '+${stop.minutesFromStart} min',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                  // Dashed line
                  Padding(
                    padding: const EdgeInsets.only(left: 14, top: 4),
                    child: Row(
                      children: [
                        Column(
                          children: List.generate(
                            4,
                            (_) => Container(
                              margin: const EdgeInsets.symmetric(vertical: 2),
                              width: 2,
                              height: 6,
                              color: AppColors.border,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Destination
                  Row(
                    children: [
                      const _RouteIcon(
                        icon: Icons.location_on_rounded,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: 14),
                      Text(
                        rideModel.destName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Price + seats
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: Row(
                children: [
                  _InfoTile(
                    label: 'Price per seat',
                    value: 'NPR ${rideModel.pricePerSeat.toStringAsFixed(0)}',
                    icon: Icons.payments_rounded,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 12),
                  _InfoTile(
                    label: 'Available seats',
                    value: '${rideModel.availableSeats} seats',
                    icon: Icons.event_seat_rounded,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Driver card
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Driver',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () => context.push(
                      RouteNames.driverProfile,
                      extra: rideModel.driver.id,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: AppColors.primaryLight,
                          backgroundImage:
                              rideModel.driver.profilePhotoUrl != null
                              ? NetworkImage(rideModel.driver.profilePhotoUrl!)
                              : null,
                          child: rideModel.driver.profilePhotoUrl == null
                              ? const Icon(
                                  Icons.person,
                                  size: 30,
                                  color: AppColors.primary,
                                )
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                rideModel.driver.fullName ?? 'Driver',
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
                                    Icons.star_rounded,
                                    size: 16,
                                    color: AppColors.star,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    rideModel.driver.averageRating
                                        .toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${rideModel.driver.totalTrips} trips',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textTertiary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Vehicle info
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Vehicle',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.borderLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.directions_car_rounded,
                          color: AppColors.textSecondary,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${rideModel.vehicle.make} ${rideModel.vehicle.model}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            rideModel.vehicle.color ?? '',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Preferences
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ride Preferences',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _PrefChip(
                        icon: rideModel.smokingPref == 'no_smoking'
                            ? Icons.smoke_free_rounded
                            : Icons.smoking_rooms_rounded,
                        label: rideModel.smokingPref == 'no_smoking'
                            ? 'No smoking'
                            : 'Smoking OK',
                      ),
                      _PrefChip(
                        icon: Icons.luggage_rounded,
                        label: rideModel.luggagePref == 'any'
                            ? 'Any luggage'
                            : rideModel.luggagePref == 'small_only'
                            ? 'Small luggage only'
                            : 'No luggage',
                      ),
                      if (rideModel.womenOnly)
                        const _PrefChip(
                          icon: Icons.female_rounded,
                          label: 'Women only',
                        ),
                    ],
                  ),
                  if (rideModel.notes != null &&
                      rideModel.notes!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Text(
                      'Driver notes',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      rideModel.notes!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),

      // Book button
      bottomNavigationBar: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Price per seat',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    Text(
                      'NPR ${rideModel.pricePerSeat.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${rideModel.availableSeats} seat${rideModel.availableSeats != 1 ? 's' : ''} left',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              text: rideModel.availableSeats > 0
                  ? 'Book Now'
                  : 'No Seats Available',
              onPressed: rideModel.availableSeats > 0
                  ? () => context.push(RouteNames.selectSeats, extra: ride)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _RouteIcon({required this.icon, required this.color, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      child: Icon(icon, color: color, size: size),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _InfoTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.borderLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrefChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PrefChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.borderLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
