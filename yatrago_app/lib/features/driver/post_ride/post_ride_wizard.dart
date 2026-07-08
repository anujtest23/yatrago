import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/router/route_names.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/location_picker_screen.dart';

class PostRideWizard extends StatefulWidget {
  const PostRideWizard({super.key});

  @override
  State<PostRideWizard> createState() => _PostRideWizardState();
}

class _PostRideWizardState extends State<PostRideWizard> {
  int _step = 0;
  bool _isLoading = false;
  String? _error;

  // Route
  String _originName = '';
  double? _originLat;
  double? _originLng;
  String? _originCity;
  String? _originState;
  String _destName = '';
  double? _destLat;
  double? _destLng;
  String? _destCity;
  String? _destState;

  // Stops
  List<Map<String, dynamic>> _stops = [];

  // Date/time
  DateTime _departureAt = DateTime.now().add(const Duration(days: 1));

  // Vehicle
  List<Map<String, dynamic>> _vehicles = [];
  String? _selectedVehicleId;
  int _totalSeats = 3;

  // Price
  double _pricePerSeat = 500;

  // Preferences
  bool _womenOnly = false;
  String _smokingPref = 'no_smoking';
  String _luggagePref = 'any';
  String _notes = '';

  final List<String> _stepTitles = [
    'Route',
    'Stops',
    'Date & Time',
    'Vehicle',
    'Price & Seats',
    'Preferences',
    'Preview',
  ];

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    try {
      final response = await DioClient.instance.get('/vehicles');
      setState(() {
        _vehicles = List<Map<String, dynamic>>.from(
          response.data['data']['vehicles'] ?? [],
        );
        if (_vehicles.isNotEmpty) {
          _selectedVehicleId = _vehicles.first['id'];
          _totalSeats = _vehicles.first['totalSeats'] ?? 3;
        }
      });
    } catch (_) {}
  }

  Future<void> _selectLocation(bool isOrigin) async {
    final initial = isOrigin
        ? (_originLat != null ? LatLng(_originLat!, _originLng!) : null)
        : (_destLat != null ? LatLng(_destLat!, _destLng!) : null);

    final result = await Navigator.push<LocationPickerResult>(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          title: isOrigin ? 'Origin' : 'Destination',
          initialPosition: initial,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        if (isOrigin) {
          _originName = result.name;
          _originLat = result.lat;
          _originLng = result.lng;
          _originCity = result.city;
          _originState = result.state;
        } else {
          _destName = result.name;
          _destLat = result.lat;
          _destLng = result.lng;
          _destCity = result.city;
          _destState = result.state;
        }
      });
    }
  }

  Future<void> _publish() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (_originLat == null || _destLat == null) {
        setState(() {
          _error = 'Please select both origin and destination on the map';
          _isLoading = false;
        });
        return;
      }

      final response = await DioClient.instance.post(
        '/trips',
        data: {
          'vehicleId': _selectedVehicleId,
          'originName': _originName,
          'originLat': _originLat,
          'originLng': _originLng,
          if (_originCity != null) 'originCity': _originCity,
          if (_originState != null) 'originState': _originState,
          'destName': _destName,
          'destLat': _destLat,
          'destLng': _destLng,
          if (_destCity != null) 'destCity': _destCity,
          if (_destState != null) 'destState': _destState,
          'departureAt': _departureAt.toUtc().toIso8601String(),
          'totalSeats': _totalSeats,
          'pricePerSeat': _pricePerSeat,
          'womenOnly': _womenOnly,
          'smokingPref': _smokingPref,
          'luggagePref': _luggagePref,
          'notes': _notes.isEmpty ? null : _notes,
          if (_stops.isNotEmpty)
            'stops': _stops
                .map(
                  (s) => {
                    'locationName': s['locationName'],
                    'lat': s['lat'],
                    'lng': s['lng'],
                    'stopOrder': s['stopOrder'],
                  },
                )
                .toList(),
        },
      );

      if (!mounted) return;
      final tripData =
          response.data['data']['trip'] as Map<String, dynamic>? ?? {};
      context.pushReplacement(RouteNames.ridePublished, extra: tripData);
    } on DioException catch (e) {
      setState(() => _error = ApiException.fromDioError(e).message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _validateAndNext() {
    setState(() => _error = null);

    switch (_step) {
      case 0:
        if (_originLat == null || _destLat == null) {
          setState(
            () => _error = 'Select both origin and destination on the map',
          );
          return;
        }
        break;
      case 3:
        if (_selectedVehicleId == null) {
          setState(() => _error = 'Please select a vehicle');
          return;
        }
        break;
    }

    setState(() => _step++);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: _step > 0
            ? IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: AppColors.textPrimary,
                ),
                onPressed: () => setState(() => _step--),
              )
            : IconButton(
                icon: const Icon(Icons.close, color: AppColors.textPrimary),
                onPressed: () => context.pop(),
              ),
        title: Text(
          '${_stepTitles[_step]} (${_step + 1}/${_stepTitles.length})',
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(
              value: (_step + 1) / _stepTitles.length,
              backgroundColor: AppColors.borderLight,
              color: AppColors.driver,
              minHeight: 4,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                child: _buildStep(),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: _step == _stepTitles.length - 1
                  ? PrimaryButton(
                      text: 'Publish Ride',
                      isLoading: _isLoading,
                      backgroundColor: AppColors.driver,
                      onPressed: _publish,
                    )
                  : PrimaryButton(
                      text: 'Continue',
                      backgroundColor: AppColors.driver,
                      onPressed: _validateAndNext,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _RouteStep(
          originName: _originName,
          destName: _destName,
          onOriginTap: () => _selectLocation(true),
          onDestTap: () => _selectLocation(false),
        );
      case 1:
        return _AddStopsStep(
          stops: _stops,
          onStopsChanged: (s) => setState(() => _stops = s),
        );
      case 2:
        return _DateTimeStep(
          departureAt: _departureAt,
          onDateChanged: (d) => setState(() => _departureAt = d),
        );
      case 3:
        return _VehicleStep(
          vehicles: _vehicles,
          selectedId: _selectedVehicleId,
          onSelect: (id) => setState(() => _selectedVehicleId = id),
        );
      case 4:
        return _PriceSeatsStep(
          pricePerSeat: _pricePerSeat,
          totalSeats: _totalSeats,
          onPriceChanged: (p) => setState(() => _pricePerSeat = p),
          onSeatsChanged: (s) => setState(() => _totalSeats = s),
        );
      case 5:
        return _PreferencesStep(
          womenOnly: _womenOnly,
          smokingPref: _smokingPref,
          luggagePref: _luggagePref,
          notes: _notes,
          onWomenOnlyChanged: (v) => setState(() => _womenOnly = v),
          onSmokingChanged: (v) => setState(() => _smokingPref = v),
          onLuggageChanged: (v) => setState(() => _luggagePref = v),
          onNotesChanged: (v) => setState(() => _notes = v),
        );
      case 6:
        return _PreviewStep(
          originName: _originName,
          destName: _destName,
          departureAt: _departureAt,
          totalSeats: _totalSeats,
          pricePerSeat: _pricePerSeat,
          womenOnly: _womenOnly,
          smokingPref: _smokingPref,
          luggagePref: _luggagePref,
          notes: _notes,
          vehicles: _vehicles,
          selectedVehicleId: _selectedVehicleId,
          stops: _stops,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ─── Route Step ───────────────────────────────────────────────────────────────

class _RouteStep extends StatelessWidget {
  final String originName;
  final String destName;
  final VoidCallback onOriginTap;
  final VoidCallback onDestTap;

  const _RouteStep({
    required this.originName,
    required this.destName,
    required this.onOriginTap,
    required this.onDestTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Where are you going?',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 24),
        _CityPicker(
          label: 'From',
          value: originName,
          hint: 'Select origin on map',
          icon: Icons.trip_origin_rounded,
          color: AppColors.primary,
          onTap: onOriginTap,
        ),
        const SizedBox(height: 14),
        _CityPicker(
          label: 'To',
          value: destName,
          hint: 'Select destination on map',
          icon: Icons.location_on_rounded,
          color: AppColors.error,
          onTap: onDestTap,
        ),
      ],
    );
  }
}

class _CityPicker extends StatelessWidget {
  final String label;
  final String value;
  final String hint;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CityPicker({
    required this.label,
    required this.value,
    required this.hint,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(
            color: value.isNotEmpty ? color : AppColors.border,
            width: value.isNotEmpty ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  Text(
                    value.isEmpty ? hint : value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: value.isEmpty
                          ? AppColors.textTertiary
                          : AppColors.textPrimary,
                    ),
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
    );
  }
}

// ─── Add Stops Step ───────────────────────────────────────────────────────────

class _AddStopsStep extends StatefulWidget {
  final List<Map<String, dynamic>> stops;
  final Function(List<Map<String, dynamic>>) onStopsChanged;

  const _AddStopsStep({required this.stops, required this.onStopsChanged});

  @override
  State<_AddStopsStep> createState() => _AddStopsStepState();
}

class _AddStopsStepState extends State<_AddStopsStep> {
  late List<Map<String, dynamic>> _stops;

  final List<String> _commonStops = [
    'Muglin',
    'Damauli',
    'Dumre',
    'Narayangadh',
    'Hetauda',
    'Birgunj',
    'Butwal',
    'Bhairahawa',
    'Kohalpur',
    'Inaruwa',
    'Itahari',
  ];

  final Map<String, Map<String, double>> _commonStopCoords = {
    'Muglin': {'lat': 27.8484, 'lng': 84.5614},
    'Damauli': {'lat': 27.9928, 'lng': 84.2667},
    'Dumre': {'lat': 27.9342, 'lng': 84.4144},
    'Narayangadh': {'lat': 27.6939, 'lng': 84.4306},
    'Hetauda': {'lat': 27.4290, 'lng': 85.0330},
    'Birgunj': {'lat': 27.0104, 'lng': 84.8772},
    'Butwal': {'lat': 27.7000, 'lng': 83.4500},
    'Bhairahawa': {'lat': 27.5042, 'lng': 83.4564},
    'Kohalpur': {'lat': 28.1167, 'lng': 81.4333},
    'Inaruwa': {'lat': 26.6167, 'lng': 87.1500},
    'Itahari': {'lat': 26.6667, 'lng': 87.2833},
  };

  @override
  void initState() {
    super.initState();
    _stops = List.from(widget.stops);
  }

  void _addStopWithCoords(String name, double lat, double lng) {
    if (_stops.any((s) => s['locationName'] == name)) return;
    setState(() {
      _stops.add({
        'locationName': name,
        'lat': lat,
        'lng': lng,
        'stopOrder': _stops.length + 1,
      });
    });
    widget.onStopsChanged(_stops);
  }

  Future<void> _pickStopOnMap() async {
    final result = await Navigator.push<LocationPickerResult>(
      context,
      MaterialPageRoute(
        builder: (context) => const LocationPickerScreen(title: 'Stop'),
      ),
    );
    if (result != null) {
      _addStopWithCoords(result.name, result.lat, result.lng);
    }
  }

  void _removeStop(int index) {
    setState(() {
      _stops.removeAt(index);
      for (int i = 0; i < _stops.length; i++) {
        _stops[i]['stopOrder'] = i + 1;
      }
    });
    widget.onStopsChanged(_stops);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add stops along the way',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Optional — add cities where you can pick up passengers.',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),

        // Pick on map button
        GestureDetector(
          onTap: _pickStopOnMap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.driverLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.driver, width: 1.5),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.add_location_alt_rounded,
                  color: AppColors.driver,
                  size: 22,
                ),
                SizedBox(width: 12),
                Text(
                  'Pick a stop on the map',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.driver,
                  ),
                ),
                Spacer(),
                Icon(Icons.chevron_right_rounded, color: AppColors.driver),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Common stops chips
        const Text(
          'Common stops',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _commonStops.map((city) {
            final added = _stops.any((s) => s['locationName'] == city);
            return GestureDetector(
              onTap: () {
                if (added) {
                  _removeStop(
                    _stops.indexWhere((s) => s['locationName'] == city),
                  );
                } else {
                  final coords =
                      _commonStopCoords[city] ??
                      {'lat': 27.7172, 'lng': 85.3240};
                  _addStopWithCoords(city, coords['lat']!, coords['lng']!);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: added ? AppColors.driver : Colors.white,
                  border: Border.all(
                    color: added ? AppColors.driver : AppColors.border,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (added) ...[
                      const Icon(
                        Icons.check_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      city,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: added ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),

        // Added stops list
        if (_stops.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text(
            'Added stops',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          ..._stops.asMap().entries.map((entry) {
            final i = entry.key;
            final stop = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.driverLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: AppColors.driver,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      stop['locationName'] as String,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _removeStop(i),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppColors.driver,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],

        if (_stops.isEmpty) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.borderLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: AppColors.textTertiary,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No stops added. You can skip this step.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Date Time Step ───────────────────────────────────────────────────────────

class _DateTimeStep extends StatelessWidget {
  final DateTime departureAt;
  final Function(DateTime) onDateChanged;

  const _DateTimeStep({required this.departureAt, required this.onDateChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'When are you departing?',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: departureAt,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 90)),
              builder: (context, child) => Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: AppColors.driver,
                  ),
                ),
                child: child!,
              ),
            );
            if (date != null) {
              onDateChanged(
                DateTime(
                  date.year,
                  date.month,
                  date.day,
                  departureAt.hour,
                  departureAt.minute,
                ),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  color: AppColors.driver,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    DateFormat('EEEE, d MMMM yyyy').format(departureAt),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
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
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () async {
            final time = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(departureAt),
              builder: (context, child) => Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: AppColors.driver,
                  ),
                ),
                child: child!,
              ),
            );
            if (time != null) {
              onDateChanged(
                DateTime(
                  departureAt.year,
                  departureAt.month,
                  departureAt.day,
                  time.hour,
                  time.minute,
                ),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  color: AppColors.driver,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    DateFormat('h:mm a').format(departureAt),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
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
      ],
    );
  }
}

// ─── Vehicle Step ─────────────────────────────────────────────────────────────

class _VehicleStep extends StatelessWidget {
  final List<Map<String, dynamic>> vehicles;
  final String? selectedId;
  final Function(String) onSelect;

  const _VehicleStep({
    required this.vehicles,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select your vehicle',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 24),
        if (vehicles.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.warningLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'No vehicles found. Please complete driver verification first.',
              style: TextStyle(color: AppColors.warning),
            ),
          )
        else
          ...vehicles.map((v) {
            final selected = selectedId == v['id'];
            return GestureDetector(
              onTap: () => onSelect(v['id']),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(
                    color: selected ? AppColors.driver : AppColors.border,
                    width: selected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.driverLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.directions_car_rounded,
                        color: AppColors.driver,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${v['make']} ${v['model']}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${v['plateNumber']} • ${v['totalSeats']} seats',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (selected)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.driver,
                      ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

// ─── Price & Seats Step ───────────────────────────────────────────────────────

class _PriceSeatsStep extends StatelessWidget {
  final double pricePerSeat;
  final int totalSeats;
  final Function(double) onPriceChanged;
  final Function(int) onSeatsChanged;

  const _PriceSeatsStep({
    required this.pricePerSeat,
    required this.totalSeats,
    required this.onPriceChanged,
    required this.onSeatsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Price and seats',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Price per seat (NPR)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Slider(
          value: pricePerSeat,
          min: 100,
          max: 5000,
          divisions: 49,
          activeColor: AppColors.driver,
          label: 'NPR ${pricePerSeat.toStringAsFixed(0)}',
          onChanged: onPriceChanged,
        ),
        Center(
          child: Text(
            'NPR ${pricePerSeat.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.driver,
            ),
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          'Seats to offer',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () {
                if (totalSeats > 1) onSeatsChanged(totalSeats - 1);
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.remove_rounded),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                '$totalSeats',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                if (totalSeats < 20) onSeatsChanged(totalSeats + 1);
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.driverLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_rounded, color: AppColors.driver),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Preferences Step ─────────────────────────────────────────────────────────

class _PreferencesStep extends StatelessWidget {
  final bool womenOnly;
  final String smokingPref;
  final String luggagePref;
  final String notes;
  final Function(bool) onWomenOnlyChanged;
  final Function(String) onSmokingChanged;
  final Function(String) onLuggageChanged;
  final Function(String) onNotesChanged;

  const _PreferencesStep({
    required this.womenOnly,
    required this.smokingPref,
    required this.luggagePref,
    required this.notes,
    required this.onWomenOnlyChanged,
    required this.onSmokingChanged,
    required this.onLuggageChanged,
    required this.onNotesChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ride preferences',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Women passengers only',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    'Only women can book this ride',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: womenOnly,
              activeColor: AppColors.driver,
              onChanged: onWomenOnlyChanged,
            ),
          ],
        ),
        const Divider(height: 24),
        const Text(
          'Smoking',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _ToggleChip(
              label: 'No Smoking',
              selected: smokingPref == 'no_smoking',
              onTap: () => onSmokingChanged('no_smoking'),
            ),
            const SizedBox(width: 8),
            _ToggleChip(
              label: 'Smoking OK',
              selected: smokingPref == 'smoking_ok',
              onTap: () => onSmokingChanged('smoking_ok'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          'Luggage',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            _ToggleChip(
              label: 'Any',
              selected: luggagePref == 'any',
              onTap: () => onLuggageChanged('any'),
            ),
            _ToggleChip(
              label: 'Small only',
              selected: luggagePref == 'small_only',
              onTap: () => onLuggageChanged('small_only'),
            ),
            _ToggleChip(
              label: 'No luggage',
              selected: luggagePref == 'no_luggage',
              onTap: () => onLuggageChanged('no_luggage'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          'Notes for passengers (optional)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: notes,
          maxLines: 3,
          onChanged: onNotesChanged,
          decoration: const InputDecoration(
            hintText: 'e.g. AC car, music allowed...',
          ),
        ),
      ],
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.driver : Colors.white,
          border: Border.all(
            color: selected ? AppColors.driver : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─── Preview Step ─────────────────────────────────────────────────────────────

class _PreviewStep extends StatelessWidget {
  final String originName;
  final String destName;
  final DateTime departureAt;
  final int totalSeats;
  final double pricePerSeat;
  final bool womenOnly;
  final String smokingPref;
  final String luggagePref;
  final String notes;
  final List<Map<String, dynamic>> vehicles;
  final String? selectedVehicleId;
  final List<Map<String, dynamic>> stops;

  const _PreviewStep({
    required this.originName,
    required this.destName,
    required this.departureAt,
    required this.totalSeats,
    required this.pricePerSeat,
    required this.womenOnly,
    required this.smokingPref,
    required this.luggagePref,
    required this.notes,
    required this.vehicles,
    required this.selectedVehicleId,
    required this.stops,
  });

  @override
  Widget build(BuildContext context) {
    final vehicle = vehicles.firstWhere(
      (v) => v['id'] == selectedVehicleId,
      orElse: () => {},
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preview your ride',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Make sure everything looks correct before publishing.',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.driverLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _PreviewRow('From', originName),
              _PreviewRow('To', destName),
              _PreviewRow(
                'Departure',
                DateFormat('EEE, d MMM • h:mm a').format(departureAt),
              ),
              _PreviewRow('Seats', '$totalSeats'),
              _PreviewRow(
                'Price per seat',
                'NPR ${pricePerSeat.toStringAsFixed(0)}',
              ),
              if (vehicle.isNotEmpty)
                _PreviewRow(
                  'Vehicle',
                  '${vehicle['make']} ${vehicle['model']}',
                ),
              _PreviewRow('Women only', womenOnly ? 'Yes' : 'No'),
              _PreviewRow(
                'Smoking',
                smokingPref == 'no_smoking' ? 'No smoking' : 'Allowed',
              ),
              if (stops.isNotEmpty)
                _PreviewRow(
                  'Stops',
                  stops.map((s) => s['locationName']).join(', '),
                ),
              if (notes.isNotEmpty) _PreviewRow('Notes', notes),
            ],
          ),
        ),
      ],
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final String label;
  final String value;

  const _PreviewRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppColors.driver),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
