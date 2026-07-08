import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart' as loc;
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../services/map_service.dart';

class LocationPickerResult {
  final double lat;
  final double lng;
  final String name;
  final String? city;
  final String? state;

  LocationPickerResult({
    required this.lat,
    required this.lng,
    required this.name,
    this.city,
    this.state,
  });
}

class LocationPickerScreen extends StatefulWidget {
  final String title;
  final LatLng? initialPosition;

  const LocationPickerScreen({
    super.key,
    required this.title,
    this.initialPosition,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final MapController _mapController = MapController();
  final _searchController = TextEditingController();

  // Default center: Kathmandu, Nepal
  static const LatLng _kathmandu = LatLng(27.7172, 85.3240);

  late LatLng _pinPosition;
  String _placeName = 'Move map to set location';
  String? _city;
  String? _state;
  bool _isReverseGeocoding = false;
  bool _isSearching = false;
  List<GeocodingResult> _searchResults = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _pinPosition = widget.initialPosition ?? _kathmandu;
    _reverseGeocodeCurrentPin();
    if (widget.initialPosition == null) {
      _tryUseCurrentLocation();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _tryUseCurrentLocation() async {
    try {
      final location = loc.Location();

      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) return;
      }

      loc.PermissionStatus permission = await location.hasPermission();
      if (permission == loc.PermissionStatus.denied) {
        permission = await location.requestPermission();
        if (permission != loc.PermissionStatus.granted) return;
      }

      final current = await location.getLocation();
      if (current.latitude != null && current.longitude != null) {
        final pos = LatLng(current.latitude!, current.longitude!);
        if (!mounted) return;
        setState(() => _pinPosition = pos);
        _mapController.move(pos, 14);
        _reverseGeocodeCurrentPin();
      }
    } catch (_) {
      // Silently fall back to default Kathmandu position
    }
  }

  Future<void> _reverseGeocodeCurrentPin() async {
    setState(() => _isReverseGeocoding = true);
    final result = await MapService.reverseGeocodeStructured(
      _pinPosition.latitude,
      _pinPosition.longitude,
    );
    if (!mounted) return;
    setState(() {
      _placeName = result.displayName;
      _city = result.city;
      _state = result.state;
      _isReverseGeocoding = false;
    });
  }

  void _onMapMoved(MapCamera camera, bool hasGesture) {
    if (hasGesture) {
      _pinPosition = camera.center;
    }
  }

  void _onMapMoveEnd() {
    _reverseGeocodeCurrentPin();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 3) {
      setState(() => _searchResults = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _isSearching = true);
      final results = await MapService.searchPlace(query);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    });
  }

  void _selectSearchResult(GeocodingResult result) {
    final pos = LatLng(result.lat, result.lng);
    setState(() {
      _pinPosition = pos;
      _placeName = result.displayName.split(',').take(2).join(',');
      _searchResults = [];
      _searchController.clear();
    });
    _mapController.move(pos, 14);
    FocusScope.of(context).unfocus();
    _reverseGeocodeCurrentPin();
  }

  void _confirm() {
    Navigator.pop(
      context,
      LocationPickerResult(
        lat: _pinPosition.latitude,
        lng: _pinPosition.longitude,
        name: _placeName,
        city: _city,
        state: _state,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _pinPosition,
              initialZoom: 13,
              onPositionChanged: _onMapMoved,
              onMapEvent: (event) {
                if (event is MapEventMoveEnd) {
                  _onMapMoveEnd();
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.yatrago.app',
              ),
            ],
          ),

          // Fixed center pin
          const IgnorePointer(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 40),
                child: Icon(
                  Icons.location_on_rounded,
                  size: 48,
                  color: AppColors.error,
                ),
              ),
            ),
          ),

          // Top bar — back + search
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: AppColors.textPrimary,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
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
                          child: TextField(
                            controller: _searchController,
                            onChanged: _onSearchChanged,
                            decoration: InputDecoration(
                              hintText:
                                  'Search ${widget.title.toLowerCase()}...',
                              hintStyle: const TextStyle(fontSize: 14),
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                size: 20,
                              ),
                              suffixIcon: _isSearching
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : null,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Search results dropdown
                  if (_searchResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      constraints: const BoxConstraints(maxHeight: 260),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: _searchResults.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final r = _searchResults[i];
                          return ListTile(
                            dense: true,
                            leading: const Icon(
                              Icons.location_on_outlined,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            title: Text(
                              r.displayName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                            onTap: () => _selectSearchResult(r),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),

          // My location button
          Positioned(
            right: 16,
            bottom: 160,
            child: FloatingActionButton.small(
              heroTag: 'my_location',
              backgroundColor: Colors.white,
              onPressed: _tryUseCurrentLocation,
              child: const Icon(
                Icons.my_location_rounded,
                color: AppColors.primary,
              ),
            ),
          ),

          // Bottom confirm card
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        color: AppColors.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _isReverseGeocoding
                            ? const Text(
                                'Finding address...',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textTertiary,
                                ),
                              )
                            : Text(
                                _placeName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: AppSpacing.buttonHeight,
                    child: ElevatedButton(
                      onPressed: _isReverseGeocoding ? null : _confirm,
                      child: Text('Confirm ${widget.title}'),
                    ),
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
