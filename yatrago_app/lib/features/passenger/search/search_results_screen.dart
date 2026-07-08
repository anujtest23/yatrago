import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/router/route_names.dart';
import '../../../core/widgets/ride_card.dart';
import '../data/search_api.dart';
import '../models/ride_model.dart';

class SearchResultsScreen extends StatefulWidget {
  final Map<String, dynamic> searchParams;
  const SearchResultsScreen({super.key, required this.searchParams});

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  List<RideModel> _rides = [];
  int _total = 0;
  bool _isLoading = true;
  String? _error;
  bool _womenOnly = false;
  String _sortBy = 'departureAt';
  bool _showMap = false;

  static const Map<String, String> _sortLabels = {
    'departureAt': 'Earliest',
    'departure_desc': 'Latest',
    'price_asc': 'Price ↑',
    'price_desc': 'Price ↓',
  };

  @override
  void initState() {
    super.initState();
    _search();
  }

  Future<void> _search() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final origin = widget.searchParams['origin'] as String? ?? '';
      final destination =
          widget.searchParams['destination'] as String? ?? '';

      List<RideModel> rides;
      int total;

      // If no search terms — fetch ALL rides
      if (origin.isEmpty && destination.isEmpty) {
        rides = await SearchApi.getAllRides(limit: 50);
        total = rides.length;
      } else {
        final result = await SearchApi.searchRides(
          origin: origin.isEmpty ? null : origin,
          destination: destination.isEmpty ? null : destination,
          date: widget.searchParams['date'],
          seats: widget.searchParams['seats'] ?? 1,
          womenOnly: _womenOnly ? true : null,
          sortBy: _sortBy,
          originLat: widget.searchParams['originLat'] as double?,
          originLng: widget.searchParams['originLng'] as double?,
          destLat: widget.searchParams['destLat'] as double?,
          destLng: widget.searchParams['destLng'] as double?,
          originCity: widget.searchParams['originCity'] as String?,
          destCity: widget.searchParams['destCity'] as String?,
        );
        rides = result['rides'] as List<RideModel>;
        total = result['pagination']['total'] ?? rides.length;
      }

      if (!mounted) return;
      setState(() {
        _rides = rides;
        _total = total;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String get _title {
    final origin = widget.searchParams['origin'] as String? ?? '';
    final destination = widget.searchParams['destination'] as String? ?? '';
    if (origin.isEmpty && destination.isEmpty) return 'All Available Rides';
    if (destination.isEmpty) return 'From $origin';
    if (origin.isEmpty) return 'To $destination';
    return '$origin → $destination';
  }

  String get _subtitle {
    final parts = <String>[];
    final date = widget.searchParams['date'] as String?;
    if (date != null && date.isNotEmpty) {
      try {
        parts.add(DateFormat('EEE, d MMM').format(DateTime.parse(date)));
      } catch (_) {}
    }
    final seats = widget.searchParams['seats'] ?? 1;
    parts.add('$seats ${seats == 1 ? 'Seat' : 'Seats'}');
    if (!_isLoading) {
      parts.add('$_total ride${_total == 1 ? '' : 's'}');
    }
    return parts.join(' • ');
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Sort by',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            ...const {
              'departureAt': 'Earliest departure',
              'departure_desc': 'Latest departure',
              'price_asc': 'Price: low to high',
              'price_desc': 'Price: high to low',
            }.entries.map(
                  (e) => ListTile(
                    title: Text(e.value, style: GoogleFonts.inter(fontSize: 15)),
                    trailing: _sortBy == e.key
                        ? const Icon(Icons.check_rounded,
                            color: AppColors.primary)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _sortBy = e.key);
                      _search();
                    },
                  ),
                ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgWarm,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 12),

            // ─── Custom Top Bar ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        color: AppColors.primary,
                        size: 28,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _subtitle,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF718096),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 44), // balance back button space
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ─── Filter Pills Row ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildFilterButton(
                    icon: Icons.access_time_rounded,
                    label: _sortLabels[_sortBy] ?? 'Sort',
                    onTap: _showSortSheet,
                  ),
                  _buildFilterButton(
                    icon: Icons.female_rounded,
                    label: 'Women only',
                    active: _womenOnly,
                    onTap: () {
                      setState(() => _womenOnly = !_womenOnly);
                      _search();
                    },
                  ),
                  _buildFilterButton(
                    icon: _showMap ? Icons.list_rounded : Icons.map_rounded,
                    label: _showMap ? 'List' : 'Map',
                    onTap: () => setState(() => _showMap = !_showMap),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ─── Results ───
            Expanded(
              child: RefreshIndicator(
                onRefresh: _search,
                child: _isLoading
                    ? const Center(
                        child:
                            CircularProgressIndicator(color: AppColors.primary),
                      )
                    : _error != null
                        ? _buildError()
                        : _rides.isEmpty
                            ? _buildEmpty()
                            : _showMap
                                ? _buildMap()
                                : ListView.builder(
                                    physics: const BouncingScrollPhysics(),
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      0,
                                      16,
                                      32,
                                    ),
                                    itemCount: _rides.length,
                                    itemBuilder: (context, i) {
                                      final ride = _rides[i];
                                      final showCityDivider =
                                          ride.matchType == 'city' &&
                                              (i == 0 ||
                                                  _rides[i - 1].matchType !=
                                                      'city');
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (showCityDivider)
                                            _buildCityDivider(),
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 16,
                                            ),
                                            child: _buildResultCard(ride),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? AppColors.primary : const Color(0xFFF3EAE3),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: active ? Colors.white : AppColors.primary,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCityDivider() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          const Icon(
            Icons.location_city_rounded,
            size: 16,
            color: AppColors.textTertiary,
          ),
          const SizedBox(width: 6),
          Text(
            'Other rides between these cities',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════
  // RESULT CARD — Yatri timeline design, live RideModel data
  // ════════════════════════════════════════════════════
  Widget _buildResultCard(RideModel ride) {
    final driver = ride.driver;
    final initials = (driver.fullName ?? '?')
        .split(' ')
        .where((p) => p.isNotEmpty)
        .map((p) => p[0])
        .take(2)
        .join()
        .toUpperCase();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () =>
              context.push(RouteNames.rideDetail, extra: ride.toJson()),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Avatar + vertical route timeline
                SizedBox(
                  width: 48,
                  child: Column(
                    children: [
                      _buildAvatar(driver.profilePhotoUrl, initials),
                      const SizedBox(height: 16),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(
                            color: const Color(0xFF10B981),
                            width: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Column(
                        children: List.generate(
                          4,
                          (index) => Container(
                            width: 1.5,
                            height: 4,
                            margin:
                                const EdgeInsets.symmetric(vertical: 1.5),
                            color: const Color(0xFFCBD5E1),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(
                            color: const Color(0xFFEF4444),
                            width: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Right Column: details, locations, seats, price
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Driver name + rating badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 2),
                                Text(
                                  driver.fullName ?? 'Driver',
                                  style: GoogleFonts.inter(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      DateFormat('EEE, d MMM')
                                          .format(ride.departureAt),
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF94A3B8),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      width: 4,
                                      height: 4,
                                      decoration: const BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      DateFormat('h:mm a')
                                          .format(ride.departureAt),
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF4A4A4A),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF1F1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  color: AppColors.primary,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  driver.averageRating.toStringAsFixed(1),
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // From location + seats-left + women-only badges
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              ride.originName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF475569),
                              ),
                            ),
                          ),
                          if (ride.womenOnly) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFCE7F3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.female_rounded,
                                    color: Color(0xFFDB2777),
                                    size: 14,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    'Women only',
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFFDB2777),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${ride.availableSeats} ${ride.availableSeats == 1 ? 'Seat' : 'Seats'} Left',
                              style: GoogleFonts.inter(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // To location + pricing
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              ride.destName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF475569),
                              ),
                            ),
                          ),
                          RichText(
                            textAlign: TextAlign.end,
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text:
                                      'NPR ${ride.pricePerSeat.toStringAsFixed(0)}\n',
                                  style: GoogleFonts.inter(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                    height: 1.2,
                                  ),
                                ),
                                TextSpan(
                                  text: 'per seat',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF94A3B8),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String? photoUrl, String initials) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundColor: AppColors.primaryLight,
        backgroundImage: CachedNetworkImageProvider(photoUrl),
      );
    }
    return CircleAvatar(
      radius: 24,
      backgroundColor: AppColors.primaryLight,
      child: Text(
        initials,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildMap() {
    final points = _rides.map((r) => LatLng(r.destLat, r.destLng)).toList();
    final center = points.isNotEmpty
        ? points[0]
        : const LatLng(27.7172, 85.3240); // Kathmandu fallback

    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(initialCenter: center, initialZoom: 7),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.yatrago.app',
            ),
            MarkerLayer(
              markers: _rides
                  .map(
                    (ride) => Marker(
                      point: LatLng(ride.destLat, ride.destLng),
                      width: 40,
                      height: 40,
                      child: GestureDetector(
                        onTap: () => _showRideSheet(ride),
                        child: const Icon(
                          Icons.location_on_rounded,
                          color: AppColors.primary,
                          size: 36,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ],
    );
  }

  void _showRideSheet(RideModel ride) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: RideCard(
          ride: ride,
          onTap: () {
            Navigator.pop(context);
            context.push(RouteNames.rideDetail, extra: ride.toJson());
          },
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: _search, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.directions_car_outlined,
              size: 48,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 12),
            Text(
              'No rides found',
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
