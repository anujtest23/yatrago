import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/router/route_names.dart';
import '../../../core/widgets/route_map_widget.dart';
import '../models/ride_model.dart';

class RideDetailScreen extends StatelessWidget {
  final Map<String, dynamic> ride;
  const RideDetailScreen({super.key, required this.ride});

  @override
  Widget build(BuildContext context) {
    final rideModel = RideModel.fromJson(ride);
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppColors.bgWarm,
      body: Stack(
        children: [
          // ─── Top Right Festive Banner ───
          Positioned(
            top: 47,
            right: 0,
            width: width * 0.40,
            child: Image.asset(
              'assets/images/passenger_rider_details_bg_1.png',
              fit: BoxFit.contain,
            ),
          ),

          // ─── Main Content ───
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildHeader(context),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 140),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        _buildDriverCard(context, rideModel),
                        const SizedBox(height: 12),
                        _buildRouteCard(rideModel),
                        const SizedBox(height: 12),
                        _buildMapCard(rideModel),
                        const SizedBox(height: 12),
                        _buildTripInfoCard(rideModel),
                        const SizedBox(height: 12),
                        _buildDetailsCard(rideModel),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─── Bottom Book Bar ───
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomBar(context, rideModel),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════
  // HEADER — Back button + title + decorative divider
  // ════════════════════════════════════════════════════
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => context.pop(),
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
                color: AppColors.textPrimary,
                size: 22,
              ),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Ride Details',
                  style: GoogleFonts.inter(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 32,
                      height: 1.2,
                      color: AppColors.primaryDark,
                    ),
                    const SizedBox(width: 8),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Transform.rotate(
                          angle: 45 * 3.1415927 / 180,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              border: Border.all(
                                color: AppColors.primaryDark,
                                width: 2.0,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryDark,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 32,
                      height: 1.2,
                      color: AppColors.primaryDark,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════
  // DRIVER CARD — tappable → driver profile
  // ════════════════════════════════════════════════════
  Widget _buildDriverCard(BuildContext context, RideModel rideModel) {
    final driver = rideModel.driver;
    final initials = (driver.fullName ?? '?')
        .split(' ')
        .where((p) => p.isNotEmpty)
        .map((p) => p[0])
        .take(2)
        .join()
        .toUpperCase();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () => context.push(
          RouteNames.driverProfile,
          extra: driver.id,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE2E8F0).withValues(alpha: 0.6),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar — real photo, initials fallback
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFEE2D5),
                  border: Border.all(
                    color: const Color(0xFFFFD0BC),
                    width: 1.5,
                  ),
                  image: driver.profilePhotoUrl != null &&
                          driver.profilePhotoUrl!.isNotEmpty
                      ? DecorationImage(
                          image: CachedNetworkImageProvider(
                            driver.profilePhotoUrl!,
                          ),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: driver.profilePhotoUrl == null ||
                        driver.profilePhotoUrl!.isEmpty
                    ? Center(
                        child: Text(
                          initials,
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              // Name & rating
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver.fullName ?? 'Driver',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 4,
                      runSpacing: 2,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: AppColors.primary,
                          size: 18,
                        ),
                        Text(
                          driver.averageRating.toStringAsFixed(1),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '(${driver.totalTrips} trips)',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Verified badge — all drivers pass admin approval
              Flexible(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.verified_user_rounded,
                          color: Color(0xFF22C55E),
                          size: 15,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Verified Driver',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════
  // ROUTE CARD — Pickup → stops → Drop-off
  // ════════════════════════════════════════════════════
  Widget _buildRouteCard(RideModel rideModel) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFE2E8F0).withValues(alpha: 0.6),
            width: 1,
          ),
          image: const DecorationImage(
            image: AssetImage(
              'assets/images/passenger_rider_details_bg_2.png',
            ),
            fit: BoxFit.fitHeight,
            alignment: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pickup
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFFDCFCE7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.directions_walk_rounded,
                    color: Color(0xFF16A34A),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PICKUP',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF16A34A),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        rideModel.originName,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('EEEE, d MMM • h:mm a')
                            .format(rideModel.departureAt),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Dotted connector + intermediate stops
            Padding(
              padding: const EdgeInsets.only(left: 19),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _dottedSegment(),
                  ...rideModel.stops.map(
                    (stop) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Transform.translate(
                              offset: const Offset(-4, 0),
                              child: const Icon(
                                Icons.circle_outlined,
                                size: 10,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                stop.locationName,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            if (stop.minutesFromStart != null)
                              Text(
                                '+${stop.minutesFromStart} min',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                          ],
                        ),
                        _dottedSegment(),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Drop-off
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEE2E2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DROP-OFF',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        rideModel.destName,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dottedSegment() {
    return Column(
      children: List.generate(
        3,
        (index) => Container(
          width: 2,
          height: 4,
          margin: const EdgeInsets.symmetric(vertical: 2.5),
          decoration: BoxDecoration(
            color: const Color(0xFF94A3B8),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════
  // MAP CARD — real route map (flutter_map + OSRM polyline)
  // ════════════════════════════════════════════════════
  Widget _buildMapCard(RideModel rideModel) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFE2E8F0).withValues(alpha: 0.6),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
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
      ),
    );
  }

  // ════════════════════════════════════════════════════
  // TRIP INFO CARD — Departure | Price | Seats left
  // ════════════════════════════════════════════════════
  Widget _buildTripInfoCard(RideModel rideModel) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFE2E8F0).withValues(alpha: 0.6),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _tripInfoBox(
              icon: Icons.access_time_rounded,
              iconColor: const Color(0xFF7C3AED),
              value: DateFormat('h:mm a').format(rideModel.departureAt),
              label: 'Departure',
            ),
            _tripInfoDivider(),
            _tripInfoBox(
              icon: Icons.account_balance_wallet_outlined,
              iconColor: AppColors.primary,
              value: 'NPR ${rideModel.pricePerSeat.toStringAsFixed(0)}',
              label: 'Per seat',
            ),
            _tripInfoDivider(),
            _tripInfoBox(
              icon: Icons.person_outline_rounded,
              iconColor: const Color(0xFFEA580C),
              value:
                  '${rideModel.availableSeats} ${rideModel.availableSeats == 1 ? 'Seat' : 'Seats'} left',
              label: 'Limited seats',
              labelColor: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _tripInfoBox({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    Color? labelColor,
  }) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: labelColor ?? const Color(0xFF94A3B8),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _tripInfoDivider() {
    return Container(
      width: 1,
      height: 32,
      color: const Color(0xFFE2E8F0),
    );
  }

  // ════════════════════════════════════════════════════
  // DETAILS CARD — vehicle + preferences + driver notes
  // ════════════════════════════════════════════════════
  Widget _buildDetailsCard(RideModel rideModel) {
    final tiles = <Map<String, dynamic>>[
      {
        'icon': Icons.directions_car_rounded,
        'label':
            '${rideModel.vehicle.make} ${rideModel.vehicle.model}'.trim(),
        'color': const Color(0xFF0EA5E9),
        'bgColor': const Color(0xFFE0F2FE),
      },
      {
        'icon': rideModel.smokingPref == 'no_smoking'
            ? Icons.smoke_free_rounded
            : Icons.smoking_rooms_rounded,
        'label': rideModel.smokingPref == 'no_smoking'
            ? 'No Smoking'
            : 'Smoking OK',
        'color': AppColors.primary,
        'bgColor': const Color(0xFFFEE2E2),
      },
      {
        'icon': Icons.luggage_rounded,
        'label': rideModel.luggagePref == 'any'
            ? 'Any Luggage'
            : rideModel.luggagePref == 'small_only'
                ? 'Small Luggage'
                : 'No Luggage',
        'color': const Color(0xFF16A34A),
        'bgColor': const Color(0xFFDCFCE7),
      },
      if (rideModel.womenOnly)
        {
          'icon': Icons.female_rounded,
          'label': 'Women Only',
          'color': const Color(0xFFDB2777),
          'bgColor': const Color(0xFFFCE7F3),
        },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFE2E8F0).withValues(alpha: 0.6),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'Vehicle & Preferences',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                for (var i = 0; i < tiles.length; i++) ...[
                  if (i > 0)
                    Container(
                      width: 1,
                      height: 40,
                      color: const Color(0xFFE2E8F0),
                    ),
                  Expanded(child: _buildPrefTile(tiles[i])),
                ],
              ],
            ),
            if (rideModel.vehicle.color != null &&
                rideModel.vehicle.color!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  'Vehicle color: ${rideModel.vehicle.color}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
            if (rideModel.notes != null && rideModel.notes!.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(
                  color: Color(0xFFE2E8F0),
                  height: 1,
                  thickness: 0.8,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Driver notes',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      rideModel.notes!,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPrefTile(Map<String, dynamic> data) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: data['bgColor'] as Color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            data['icon'] as IconData,
            color: data['color'] as Color,
            size: 20,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          data['label'] as String,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════
  // BOTTOM BAR — price summary + Book Now
  // ════════════════════════════════════════════════════
  Widget _buildBottomBar(BuildContext context, RideModel rideModel) {
    final hasSeats = rideModel.availableSeats > 0;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgWarm,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Price per seat',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  Text(
                    'NPR ${rideModel.pricePerSeat.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              Text(
                '${rideModel.availableSeats} seat${rideModel.availableSeats != 1 ? 's' : ''} left',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: hasSeats
                ? () => context.push(RouteNames.selectSeats, extra: ride)
                : null,
            child: Container(
              width: double.infinity,
              height: 54,
              decoration: BoxDecoration(
                gradient: hasSeats ? AppColors.primaryGradient : null,
                color: hasSeats ? null : AppColors.border,
                borderRadius: BorderRadius.circular(16),
                boxShadow: hasSeats
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(
                hasSeats ? 'Book Now' : 'No Seats Available',
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: hasSeats ? Colors.white : AppColors.textTertiary,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
