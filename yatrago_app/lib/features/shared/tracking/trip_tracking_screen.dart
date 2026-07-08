import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart' as loc;
import '../../../core/constants/app_colors.dart';
import '../../../core/services/map_service.dart';
import 'tracking_api.dart';

class TripTrackingScreen extends StatefulWidget {
  final String tripId;
  final bool isDriver;
  final double originLat;
  final double originLng;
  final String originName;
  final double destLat;
  final double destLng;
  final String destName;

  const TripTrackingScreen({
    super.key,
    required this.tripId,
    required this.isDriver,
    required this.originLat,
    required this.originLng,
    required this.originName,
    required this.destLat,
    required this.destLng,
    required this.destName,
  });

  @override
  State<TripTrackingScreen> createState() => _TripTrackingScreenState();
}

class _TripTrackingScreenState extends State<TripTrackingScreen> {
  final MapController _mapController = MapController();
  final loc.Location _location = loc.Location();

  Timer? _locationTimer;
  LatLng? _driverPosition;
  List<LatLng> _routePoints = [];
  double? _distanceKm;
  int? _durationMin;
  DateTime? _lastUpdated;
  String? _error;
  bool _isLoadingRoute = true;
  bool _hasCentered = false;

  late LatLng _origin;
  late LatLng _destination;

  @override
  void initState() {
    super.initState();
    _origin = LatLng(widget.originLat, widget.originLng);
    _destination = LatLng(widget.destLat, widget.destLng);
    _loadRoute();
    if (widget.isDriver) {
      _startSendingLocation();
    } else {
      _startPollingLocation();
    }
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadRoute() async {
    final result = await MapService.getRoute(_origin, _destination);
    if (!mounted) return;
    setState(() {
      _routePoints = result?.points ?? [_origin, _destination];
      _distanceKm = result?.distanceKm;
      _durationMin = result?.durationMinutes;
      _isLoadingRoute = false;
    });
  }

  void _startSendingLocation() {
    _sendCurrentLocation();
    _locationTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _sendCurrentLocation(),
    );
  }

  Future<void> _sendCurrentLocation() async {
    try {
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) return;
      }
      loc.PermissionStatus permission = await _location.hasPermission();
      if (permission == loc.PermissionStatus.denied) {
        permission = await _location.requestPermission();
        if (permission != loc.PermissionStatus.granted) return;
      }
      final current = await _location.getLocation();
      if (current.latitude == null || current.longitude == null) return;
      final pos = LatLng(current.latitude!, current.longitude!);
      if (!mounted) return;
      setState(() {
        _driverPosition = pos;
        _lastUpdated = DateTime.now();
        _error = null;
      });
      if (!_hasCentered) {
        _mapController.move(pos, 14);
        _hasCentered = true;
      }
      await TrackingApi.updateMyLocation(pos.latitude, pos.longitude);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not update location');
    }
  }

  void _startPollingLocation() {
    _pollLocation();
    _locationTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _pollLocation(),
    );
  }

  Future<void> _pollLocation() async {
    try {
      final data = await TrackingApi.getDriverLocation(widget.tripId);
      if (!mounted) return;
      if (data['lat'] != null && data['lng'] != null) {
        final pos = LatLng(
          (data['lat'] as num).toDouble(),
          (data['lng'] as num).toDouble(),
        );
        setState(() {
          _driverPosition = pos;
          _lastUpdated = data['lastUpdatedAt'] != null
              ? DateTime.tryParse(data['lastUpdatedAt'])
              : null;
          _error = null;
        });
        if (!_hasCentered) {
          _mapController.move(pos, 14);
          _hasCentered = true;
        }
      } else {
        setState(() => _error = 'Waiting for driver location...');
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not fetch driver location');
    }
  }

  String _timeAgo() {
    if (_lastUpdated == null) return 'Never';
    final diff = DateTime.now().difference(_lastUpdated!);
    if (diff.inSeconds < 10) return 'Just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    return '${diff.inMinutes}m ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: _origin, initialZoom: 12),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.yatrago.app',
              ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 4,
                      color: AppColors.primary.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _origin,
                    width: 32,
                    height: 32,
                    child: const Icon(
                      Icons.trip_origin_rounded,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                  Marker(
                    point: _destination,
                    width: 36,
                    height: 36,
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: AppColors.error,
                      size: 32,
                    ),
                  ),
                  if (_driverPosition != null)
                    Marker(
                      point: _driverPosition!,
                      width: 46,
                      height: 46,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.driver,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.directions_car_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (_isLoadingRoute)
            Container(
              color: Colors.white.withValues(alpha: 0.5),
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
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
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _error == null
                                  ? AppColors.success
                                  : AppColors.warning,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.isDriver
                                  ? 'Sending your location'
                                  : _error ?? 'Tracking driver',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            _timeAgo(),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.originName,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.arrow_downward_rounded,
                              size: 12,
                              color: AppColors.textTertiary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                widget.destName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_distanceKm != null && _durationMin != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_distanceKm!.toStringAsFixed(0)} km',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          _durationMin! < 60
                              ? '$_durationMin min'
                              : '${_durationMin! ~/ 60}h ${_durationMin! % 60}m',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
