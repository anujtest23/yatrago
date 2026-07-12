import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../../core/widgets/location_picker_screen.dart';

/// Driver "Post a New Ride" screen — single scrolling page in the Yatri design
/// language (map card, vehicle selector, one details card, gradient publish
/// button). Optional stops/preferences live in a collapsible section so the
/// full trip payload is still captured without a multi-step wizard.
class PostRideWizard extends StatefulWidget {
  const PostRideWizard({super.key});

  @override
  State<PostRideWizard> createState() => _PostRideWizardState();
}

class _PostRideWizardState extends State<PostRideWizard> {
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
  final _priceController = TextEditingController(text: '500');

  // Preferences
  bool _womenOnly = false;
  String _smokingPref = 'no_smoking';
  String _luggagePref = 'any';
  String _notes = '';

  bool _moreExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
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

    final result = await Navigator.of(context, rootNavigator: true)
        .push<LocationPickerResult>(
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

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _departureAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.driver),
        ),
        child: child!,
      ),
    );
    if (date != null) {
      setState(() {
        _departureAt = DateTime(
          date.year,
          date.month,
          date.day,
          _departureAt.hour,
          _departureAt.minute,
        );
      });
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_departureAt),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.driver),
        ),
        child: child!,
      ),
    );
    if (time != null) {
      setState(() {
        _departureAt = DateTime(
          _departureAt.year,
          _departureAt.month,
          _departureAt.day,
          time.hour,
          time.minute,
        );
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
      if (_selectedVehicleId == null) {
        setState(() {
          _error = 'Please select a vehicle';
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
      final ex = ApiException.fromDioError(e);
      // Low wallet balance is a recoverable, expected outcome — offer a themed
      // dialog that takes the driver straight to Top Up instead of a dead-end
      // error message.
      if (ex.code == 'INSUFFICIENT_WALLET_BALANCE') {
        if (mounted) setState(() => _isLoading = false);
        await _handleInsufficientBalance(ex.message);
        return;
      }
      setState(() => _error = ex.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleInsufficientBalance(String message) async {
    final topUp = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: AppColors.driverLight,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.account_balance_wallet_rounded,
            color: AppColors.driver,
            size: 28,
          ),
        ),
        title: const Text(
          'Not Enough Balance',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        actions: [
          SizedBox(
            width: double.infinity,
            height: AppSpacing.buttonHeight,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.driver,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Top Up'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'Not now',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );

    if (topUp != true || !mounted) return;

    // Go to Top Up; if the driver successfully tops up, retry publishing so
    // they never have to re-enter the form manually.
    final credited = await context.push<bool>(RouteNames.topUp);
    if (credited == true && mounted) {
      await _publish();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgWarm,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                child: Column(
                  children: [
                    _buildMapCard(),
                    const SizedBox(height: 16),
                    _buildVehicleSelector(),
                    const SizedBox(height: 16),
                    _buildDetailsCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.driverLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back,
                  color: AppColors.driver, size: 20),
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 40),
                child: Text(
                  'Post a New Ride',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Map card (decorative backdrop reflecting the chosen route) ─
  Widget _buildMapCard() {
    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/map_route.png',
                fit: BoxFit.cover,
              ),
            ),
            // Origin chip (top-left) — tap to set origin.
            Positioned(
              left: 12,
              top: 12,
              child: _mapPointChip(
                label: _originName.isEmpty ? 'Set origin' : _originName,
                badge: 'Start',
                badgeBg: const Color(0xFFE6F6EE),
                badgeFg: AppColors.driver,
                filledDot: true,
                onTap: () => _selectLocation(true),
              ),
            ),
            // Destination chip (bottom-right) — tap to set destination.
            Positioned(
              right: 12,
              bottom: 40,
              child: _mapPointChip(
                label: _destName.isEmpty ? 'Set destination' : _destName,
                badge: 'Destination',
                badgeBg: const Color(0xFFFEE2E2),
                badgeFg: const Color(0xFFEF4444),
                filledDot: false,
                onTap: () => _selectLocation(false),
              ),
            ),
            // Hint (bottom-left)
            Positioned(
              left: 12,
              bottom: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.touch_app_rounded,
                        color: AppColors.driver, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Tap a pin to set route',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.driver,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mapPointChip({
    required String label,
    required String badge,
    required Color badgeBg,
    required Color badgeFg,
    required bool filledDot,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 190),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filledDot ? Colors.white : badgeFg,
                border: Border.all(color: badgeFg, width: 2.5),
              ),
              child: filledDot
                  ? Center(
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: badgeFg,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                badge,
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: badgeFg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Vehicle selector (replaces Yatri's static category row) ────
  Widget _buildVehicleSelector() {
    if (_vehicles.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.warningLight,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'No vehicles found. Complete driver verification to add one.',
                style: TextStyle(color: AppColors.warning, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _vehicles.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final v = _vehicles[i];
          final selected = _selectedVehicleId == v['id'];
          return GestureDetector(
            onTap: () => setState(() {
              _selectedVehicleId = v['id'];
              _totalSeats = v['totalSeats'] ?? _totalSeats;
            }),
            child: Container(
              width: 150,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? AppColors.driver : Colors.transparent,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: selected
                        ? AppColors.driver.withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: 0.03),
                    blurRadius: selected ? 10 : 4,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    _vehicleIcon(v['vehicleType'] as String?),
                    color: selected ? AppColors.driver : AppColors.textTertiary,
                    size: 26,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${v['make']} ${v['model']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${v['totalSeats']} seats',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _vehicleIcon(String? type) {
    switch (type) {
      case 'motorcycle':
        return Icons.directions_bike_rounded;
      case 'suv':
        return Icons.airport_shuttle_rounded;
      case 'microbus':
        return Icons.directions_bus_rounded;
      case 'car':
      default:
        return Icons.directions_car_rounded;
    }
  }

  // ── Details card ───────────────────────────────────────────────
  Widget _buildDetailsCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildRouteRows(),
            const Divider(height: 32, color: Color(0xFFF1F5F9), thickness: 1.2),
            _buildDateTimeRow(),
            const Divider(height: 32, color: Color(0xFFF1F5F9), thickness: 1.2),
            _buildSeatsRow(),
            const Divider(height: 32, color: Color(0xFFF1F5F9), thickness: 1.2),
            _buildPriceRow(),
            const SizedBox(height: 8),
            _buildMoreOptions(),
            const SizedBox(height: 20),
            if (_error != null) ...[
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.error, fontSize: 13),
              ),
              const SizedBox(height: 12),
            ],
            _buildPublishButton(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.verified_user,
                    color: Color(0xFF94A3B8), size: 15),
                const SizedBox(width: 6),
                Text(
                  'Your ride will be reviewed before it goes live',
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
    );
  }

  Widget _buildRouteRows() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          _routeRow(
            leading: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.driver, width: 2),
                color: Colors.white,
              ),
              child: Center(
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.driver,
                  ),
                ),
              ),
            ),
            hint: 'Enter Source',
            value: _originName,
            onTap: () => _selectLocation(true),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          _routeRow(
            leading: const Icon(Icons.location_on,
                color: Color(0xFFEF4444), size: 20),
            hint: 'Enter Destination',
            value: _destName,
            onTap: () => _selectLocation(false),
          ),
        ],
      ),
    );
  }

  Widget _routeRow({
    required Widget leading,
    required String hint,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value.isEmpty ? hint : value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: value.isEmpty ? FontWeight.w500 : FontWeight.w600,
                  color:
                      value.isEmpty ? const Color(0xFF94A3B8) : AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimeRow() {
    return Row(
      children: [
        Expanded(
          child: _iconField(
            icon: Icons.calendar_today_rounded,
            label: 'Date',
            value: DateFormat('d/M/yyyy').format(_departureAt),
            onTap: _pickDate,
          ),
        ),
        Container(height: 36, width: 1, color: const Color(0xFFE2E8F0)),
        const SizedBox(width: 12),
        Expanded(
          child: _iconField(
            icon: Icons.access_time_rounded,
            label: 'Departure Time',
            value: DateFormat('h:mm a').format(_departureAt),
            onTap: _pickTime,
          ),
        ),
      ],
    );
  }

  Widget _iconField({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.driver, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
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
    );
  }

  Widget _buildSeatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.person_outline_rounded,
                  color: AppColors.driver, size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Available Seats',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$_totalSeats Seats',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _stepBtn(Icons.remove, () {
                if (_totalSeats > 1) setState(() => _totalSeats--);
              }),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '$_totalSeats',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _stepBtn(Icons.add, () {
                if (_totalSeats < 20) setState(() => _totalSeats++);
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: AppColors.driverLight,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.driver, size: 16),
      ),
    );
  }

  Widget _buildPriceRow() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.account_balance_wallet_outlined,
              color: AppColors.driver, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Price per seat',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    'Rs. ',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      onChanged: (v) =>
                          _pricePerSeat = double.tryParse(v) ?? 0,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        hintText: '0',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Collapsible advanced options (stops + preferences) ─────────
  Widget _buildMoreOptions() {
    final stopCount = _stops.length;
    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _moreExpanded = !_moreExpanded),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.tune_rounded,
                    color: AppColors.driver, size: 20),
                const SizedBox(width: 10),
                Text(
                  'More options',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                if (stopCount > 0 || _womenOnly)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.driverLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _summaryBadge(stopCount),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.driver,
                      ),
                    ),
                  ),
                const Spacer(),
                AnimatedRotation(
                  turns: _moreExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
        if (_moreExpanded) ...[
          const Divider(height: 8, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          _AddStopsStep(
            stops: _stops,
            onStopsChanged: (s) => setState(() => _stops = s),
          ),
          const SizedBox(height: 20),
          _PreferencesStep(
            womenOnly: _womenOnly,
            smokingPref: _smokingPref,
            luggagePref: _luggagePref,
            notes: _notes,
            onWomenOnlyChanged: (v) => setState(() => _womenOnly = v),
            onSmokingChanged: (v) => setState(() => _smokingPref = v),
            onLuggageChanged: (v) => setState(() => _luggagePref = v),
            onNotesChanged: (v) => _notes = v,
          ),
        ],
      ],
    );
  }

  String _summaryBadge(int stopCount) {
    final parts = <String>[];
    if (stopCount > 0) parts.add('$stopCount stop${stopCount > 1 ? 's' : ''}');
    if (_womenOnly) parts.add('women only');
    return parts.join(' • ');
  }

  // ── Publish button (Yatri gradient + car asset) ────────────────
  Widget _buildPublishButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _publish,
      child: Container(
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          gradient: AppColors.driverGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.driver.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              bottom: -2,
              top: -2,
              width: 90,
              child: Image.asset(
                'assets/images/green_car.png',
                fit: BoxFit.contain,
              ),
            ),
            Center(
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Publish Ride',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
            if (!_isLoading)
              Positioned(
                right: 12,
                top: 12,
                bottom: 12,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_forward,
                      color: AppColors.driver, size: 20),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Add Stops (reused inside "More options") ─────────────────────────────────

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
    final result = await Navigator.of(context, rootNavigator: true)
        .push<LocationPickerResult>(
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
        const Text(
          'Stops along the way',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Optional — add cities where you can pick up passengers.',
          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: _pickStopOnMap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.driverLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.driver, width: 1.5),
            ),
            child: const Row(
              children: [
                Icon(Icons.add_location_alt_rounded,
                    color: AppColors.driver, size: 22),
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
        const SizedBox(height: 16),
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
                  final coords = _commonStopCoords[city] ??
                      {'lat': 27.7172, 'lng': 85.3240};
                  _addStopWithCoords(city, coords['lat']!, coords['lng']!);
                }
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
                      const Icon(Icons.check_rounded,
                          size: 12, color: Colors.white),
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
        if (_stops.isNotEmpty) ...[
          const SizedBox(height: 16),
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
                    child: const Icon(Icons.close_rounded,
                        size: 18, color: AppColors.driver),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}

// ─── Preferences (reused inside "More options") ───────────────────────────────

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
        const Text(
          'Ride preferences',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
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
