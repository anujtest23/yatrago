import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../constants/app_colors.dart';
import '../services/map_service.dart';

/// Shows the driver's route with the passenger's pickup & drop-off overlaid,
/// and calculates how much extra travel the request adds versus the driver's
/// original origin→destination route.
class BookingRouteMap extends StatefulWidget {
  final LatLng driverOrigin;
  final LatLng driverDest;
  final LatLng pickup;
  final LatLng drop;
  final String pickupName;
  final String dropName;
  final double height;

  const BookingRouteMap({
    super.key,
    required this.driverOrigin,
    required this.driverDest,
    required this.pickup,
    required this.drop,
    required this.pickupName,
    required this.dropName,
    this.height = 240,
  });

  @override
  State<BookingRouteMap> createState() => _BookingRouteMapState();
}

class _BookingRouteMapState extends State<BookingRouteMap> {
  final MapController _mapController = MapController();
  List<LatLng> _routePoints = [];
  bool _isLoading = true;

  double? _pickupDeviationKm;
  double? _dropDeviationKm;
  double? _totalDeviationKm;
  int? _extraMinutes;

  @override
  void initState() {
    super.initState();
    _computeDeviation();
  }

  Future<void> _computeDeviation() async {
    // Run the four routing queries in parallel:
    //  - baseline:  origin → destination (driver's original route)
    //  - +pickup:   origin → pickup → destination
    //  - +drop:     origin → drop → destination
    //  - full:      origin → pickup → drop → destination (the actual detour)
    final results = await Future.wait([
      MapService.getRoute(widget.driverOrigin, widget.driverDest),
      MapService.getRoute(
        widget.driverOrigin,
        widget.driverDest,
        waypoints: [widget.pickup],
      ),
      MapService.getRoute(
        widget.driverOrigin,
        widget.driverDest,
        waypoints: [widget.drop],
      ),
      MapService.getRoute(
        widget.driverOrigin,
        widget.driverDest,
        waypoints: [widget.pickup, widget.drop],
      ),
    ]);

    if (!mounted) return;

    final baseline = results[0];
    final withPickup = results[1];
    final withDrop = results[2];
    final full = results[3];

    double diff(double? a, double? b) =>
        (a == null || b == null) ? 0 : (a - b).clamp(0, double.infinity);

    setState(() {
      if (baseline != null) {
        _pickupDeviationKm = diff(withPickup?.distanceKm, baseline.distanceKm);
        _dropDeviationKm = diff(withDrop?.distanceKm, baseline.distanceKm);
        _totalDeviationKm = diff(full?.distanceKm, baseline.distanceKm);
        if (full != null) {
          _extraMinutes = (full.durationMinutes - baseline.durationMinutes)
              .clamp(0, 100000);
        }
      }
      _routePoints = (full ?? baseline)?.points ??
          [widget.driverOrigin, widget.pickup, widget.drop, widget.driverDest];
      _isLoading = false;
    });
    _fitBounds();
  }

  void _fitBounds() {
    final bounds = LatLngBounds.fromPoints([
      widget.driverOrigin,
      widget.pickup,
      widget.drop,
      widget.driverDest,
    ]);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        _mapController.fitCamera(
          CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(44)),
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
                    initialCenter: widget.pickup,
                    initialZoom: 9,
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
                        _marker(
                          widget.driverOrigin,
                          Icons.trip_origin_rounded,
                          AppColors.textSecondary,
                          26,
                        ),
                        _marker(
                          widget.driverDest,
                          Icons.sports_score_rounded,
                          AppColors.textSecondary,
                          26,
                        ),
                        _marker(
                          widget.pickup,
                          Icons.person_pin_circle_rounded,
                          AppColors.primary,
                          38,
                        ),
                        _marker(
                          widget.drop,
                          Icons.location_on_rounded,
                          AppColors.error,
                          34,
                        ),
                      ],
                    ),
                  ],
                ),
                if (_isLoading)
                  Container(
                    color: Colors.white.withValues(alpha: 0.6),
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

        const SizedBox(height: 10),

        // Legend
        Row(
          children: [
            _legend(Icons.person_pin_circle_rounded, AppColors.primary,
                'Pickup'),
            const SizedBox(width: 14),
            _legend(Icons.location_on_rounded, AppColors.error, 'Drop-off'),
          ],
        ),

        // Deviation panel
        if (!_isLoading && _totalDeviationKm != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Extra travel vs your route',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 10),
                _deviationRow(
                  'Pickup detour',
                  '+${_pickupDeviationKm!.toStringAsFixed(1)} km',
                ),
                _deviationRow(
                  'Drop-off detour',
                  '+${_dropDeviationKm!.toStringAsFixed(1)} km',
                ),
                const Divider(height: 16),
                _deviationRow(
                  'Total extra distance',
                  '+${_totalDeviationKm!.toStringAsFixed(1)} km',
                  bold: true,
                ),
                if (_extraMinutes != null)
                  _deviationRow(
                    'Estimated extra time',
                    '+$_extraMinutes min',
                    bold: true,
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Marker _marker(LatLng point, IconData icon, Color color, double size) {
    return Marker(
      point: point,
      width: size + 4,
      height: size + 4,
      child: Icon(icon, color: color, size: size),
    );
  }

  Widget _legend(IconData icon, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _deviationRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.primary,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
