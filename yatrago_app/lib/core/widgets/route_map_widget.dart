import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../constants/app_colors.dart';
import '../services/map_service.dart';

class RouteStop {
  final double lat;
  final double lng;
  final String name;

  RouteStop({required this.lat, required this.lng, required this.name});
}

class RouteMapWidget extends StatefulWidget {
  final double originLat;
  final double originLng;
  final String originName;
  final double destLat;
  final double destLng;
  final String destName;
  final List<RouteStop> stops;
  final double height;

  const RouteMapWidget({
    super.key,
    required this.originLat,
    required this.originLng,
    required this.originName,
    required this.destLat,
    required this.destLng,
    required this.destName,
    this.stops = const [],
    this.height = 220,
  });

  @override
  State<RouteMapWidget> createState() => _RouteMapWidgetState();
}

class _RouteMapWidgetState extends State<RouteMapWidget> {
  final MapController _mapController = MapController();
  List<LatLng> _routePoints = [];
  double? _distanceKm;
  int? _durationMin;
  bool _isLoadingRoute = true;

  late LatLng _origin;
  late LatLng _destination;

  @override
  void initState() {
    super.initState();
    _origin = LatLng(widget.originLat, widget.originLng);
    _destination = LatLng(widget.destLat, widget.destLng);
    _loadRoute();
  }

  Future<void> _loadRoute() async {
    final waypoints = widget.stops.map((s) => LatLng(s.lat, s.lng)).toList();

    final result = await MapService.getRoute(
      _origin,
      _destination,
      waypoints: waypoints,
    );

    if (!mounted) return;

    if (result != null) {
      setState(() {
        _routePoints = result.points;
        _distanceKm = result.distanceKm;
        _durationMin = result.durationMinutes;
        _isLoadingRoute = false;
      });
      _fitBounds();
    } else {
      // Fallback: straight line if OSRM fails
      setState(() {
        _routePoints = [_origin, ...waypoints, _destination];
        _isLoadingRoute = false;
      });
      _fitBounds();
    }
  }

  void _fitBounds() {
    final allPoints = [
      _origin,
      ...widget.stops.map((s) => LatLng(s.lat, s.lng)),
      _destination,
    ];

    final bounds = LatLngBounds.fromPoints(allPoints);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        _mapController.fitCamera(
          CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(40)),
        );
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: widget.height,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _origin,
                    initialZoom: 8,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.yatrago.app',
                    ),
                    if (_routePoints.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _routePoints,
                            strokeWidth: 4,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _origin,
                          width: 36,
                          height: 36,
                          child: const Icon(
                            Icons.trip_origin_rounded,
                            color: AppColors.primary,
                            size: 30,
                          ),
                        ),
                        ...widget.stops.map(
                          (s) => Marker(
                            point: LatLng(s.lat, s.lng),
                            width: 28,
                            height: 28,
                            child: const Icon(
                              Icons.circle,
                              color: AppColors.warning,
                              size: 14,
                            ),
                          ),
                        ),
                        Marker(
                          point: _destination,
                          width: 36,
                          height: 36,
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: AppColors.error,
                            size: 34,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (_isLoadingRoute)
                  Container(
                    color: Colors.white.withOpacity(0.6),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Distance / ETA bar
        if (_distanceKm != null && _durationMin != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              _InfoChip(
                icon: Icons.route_rounded,
                label: '${_distanceKm!.toStringAsFixed(0)} km',
              ),
              const SizedBox(width: 8),
              _InfoChip(
                icon: Icons.access_time_rounded,
                label: _formatDuration(_durationMin!),
              ),
            ],
          ),
        ],
      ],
    );
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.borderLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
