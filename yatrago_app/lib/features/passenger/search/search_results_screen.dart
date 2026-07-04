import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
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

  @override
  Widget build(BuildContext context) {
    final origin = widget.searchParams['origin'] as String? ?? '';
    final destination = widget.searchParams['destination'] as String? ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              origin.isEmpty && destination.isEmpty
                  ? 'All Available Rides'
                  : destination.isEmpty
                      ? 'From $origin'
                      : origin.isEmpty
                          ? 'To $destination'
                          : '$origin → $destination',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            if (!_isLoading)
              Text(
                '$_total ride${_total == 1 ? '' : 's'} found',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showMap ? Icons.list_rounded : Icons.map_rounded,
              color: AppColors.textSecondary,
            ),
            tooltip: _showMap ? 'Show list' : 'Show map',
            onPressed: () => setState(() => _showMap = !_showMap),
          ),
          IconButton(
            icon: Icon(
              _womenOnly ? Icons.female_rounded : Icons.female_outlined,
              color: _womenOnly ? Colors.pink : AppColors.textSecondary,
            ),
            tooltip: 'Women only',
            onPressed: () {
              setState(() => _womenOnly = !_womenOnly);
              _search();
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort_rounded, color: AppColors.textSecondary),
            onSelected: (value) {
              setState(() => _sortBy = value);
              _search();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'departureAt', child: Text('Earliest departure')),
              PopupMenuItem(value: 'departure_desc', child: Text('Latest departure')),
              PopupMenuItem(value: 'price_asc', child: Text('Price: low to high')),
              PopupMenuItem(value: 'price_desc', child: Text('Price: high to low')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _search,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _error != null
                ? _buildError()
                : _rides.isEmpty
                    ? _buildEmpty()
                    : _showMap
                        ? _buildMap()
                        : ListView.builder(
                            padding: const EdgeInsets.all(
                              AppSpacing.screenPadding,
                            ),
                            itemCount: _rides.length,
                            itemBuilder: (context, i) {
                              final ride = _rides[i];
                              final showCityDivider =
                                  ride.matchType == 'city' &&
                                  (i == 0 || _rides[i - 1].matchType != 'city');
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (showCityDivider) _buildCityDivider(),
                                  RideCard(
                                    ride: ride,
                                    onTap: () => context.push(
                                      RouteNames.rideDetail,
                                      extra: ride.toJson(),
                                    ),
                                  ),
                                ],
                              );
                            },
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
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    final points = _rides
        .map((r) => LatLng(r.destLat, r.destLng))
        .toList();
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
            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
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
            const Text(
              'No rides found',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
