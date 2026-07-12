import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/router/route_names.dart';
import '../../../core/widgets/location_picker_screen.dart';
import '../../../core/widgets/ride_card.dart';
import '../data/search_api.dart';
import '../data/booking_api.dart';
import '../models/ride_model.dart';
import '../models/booking_model.dart';
import '../../auth/data/auth_api.dart';

/// Passenger home — Yatri v2 map-first layout.
///
/// A full-screen live map sits behind floating controls and a draggable
/// bottom-sheet search card. The sheet collapses to reveal the map and
/// expands (drag up) to surface the Upcoming Trip card and the live
/// Available Rides list. All backend wiring (search, bookings, geocoded
/// location picker, map controller) is preserved from the previous layout.
class PassengerHomeScreen extends ConsumerStatefulWidget {
  const PassengerHomeScreen({super.key});

  @override
  ConsumerState<PassengerHomeScreen> createState() =>
      _PassengerHomeScreenState();
}

class _PassengerHomeScreenState extends ConsumerState<PassengerHomeScreen> {
  static const LatLng _kathmandu = LatLng(27.7172, 85.3240);

  String? _userName;
  List<RideModel> _popularRides = [];
  BookingModel? _upcomingBooking;
  bool _isLoading = true;

  final MapController _mapController = MapController();
  bool _mapReady = false;

  // Search card state (same mechanics as SearchScreen)
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

  DateTime _selectedDate = DateTime.now();
  int _seats = 1;
  // Yatri v2 adds a return-type selector. It is a visual affordance only —
  // the backend search endpoint is one-way, so this is not sent upstream.
  String _returnType = 'One way';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final user = await AuthApi.getMe();
      final bookings = await BookingApi.getMyBookings(
        role: 'passenger',
        status: 'confirmed',
      );
      final rides = await SearchApi.getAllRides(limit: 20);

      if (!mounted) return;
      setState(() {
        _userName = user['fullName'];
        _popularRides = rides;
        _upcomingBooking = bookings.isNotEmpty ? bookings.first : null;
        _isLoading = false;
      });
      _fitMapToRides();
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _fitMapToRides() {
    if (!_mapReady || _popularRides.isEmpty) return;
    final points = _popularRides
        .map((r) => LatLng(r.originLat, r.originLng))
        .toList();
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.all(60),
      ),
    );
  }

  void _zoomMap(double delta) {
    final camera = _mapController.camera;
    _mapController.move(camera.center, camera.zoom + delta);
  }

  void _searchRide() {
    // "View all" / "See all" opens the full search page.
    context.push(RouteNames.search);
  }

  Future<void> _selectLocation(bool isOrigin) async {
    final initial = isOrigin
        ? (_originLat != null ? LatLng(_originLat!, _originLng!) : null)
        : (_destLat != null ? LatLng(_destLat!, _destLng!) : null);

    final result = await Navigator.push<LocationPickerResult>(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          title: isOrigin ? 'Pickup' : 'Drop',
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

  void _swapLocations() {
    setState(() {
      final tempName = _originName;
      final tempLat = _originLat;
      final tempLng = _originLng;
      final tempCity = _originCity;
      final tempState = _originState;

      _originName = _destName;
      _originLat = _destLat;
      _originLng = _destLng;
      _originCity = _destCity;
      _originState = _destState;

      _destName = tempName;
      _destLat = tempLat;
      _destLng = tempLng;
      _destCity = tempCity;
      _destState = tempState;
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _selectSeats() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Seats'),
        children: List.generate(6, (index) => index + 1).map((seats) {
          return SimpleDialogOption(
            onPressed: () {
              setState(() => _seats = seats);
              Navigator.pop(context);
            },
            child: Text(
              '$seats ${seats == 1 ? 'Seat' : 'Seats'}',
              style: const TextStyle(fontSize: 16),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _selectReturnType() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Return Option'),
        children: ['One way', 'Round trip'].map((type) {
          return SimpleDialogOption(
            onPressed: () {
              setState(() => _returnType = type);
              Navigator.pop(context);
            },
            child: Text(type, style: const TextStyle(fontSize: 16)),
          );
        }).toList(),
      ),
    );
  }

  void _submitSearchCard() {
    if (_originName.isEmpty && _destName.isEmpty) {
      // Nothing selected — browse all rides
      context.push(
        RouteNames.searchResults,
        extra: {
          'origin': '',
          'destination': '',
          'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
          'seats': _seats,
          'originLat': null,
          'originLng': null,
          'destLat': null,
          'destLng': null,
        },
      );
      return;
    }

    context.push(
      RouteNames.searchResults,
      extra: {
        'origin': _originName,
        'destination': _destName,
        'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'seats': _seats,
        'originLat': _originLat,
        'originLng': _originLng,
        'destLat': _destLat,
        'destLng': _destLng,
        'originCity': _originCity,
        'destCity': _destCity,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.bgWarm,
      body: Stack(
        children: [
          // ─── Full-screen live map ───
          Positioned.fill(child: _buildMap()),

          // ─── Floating menu button (top-left) ───
          Positioned(
            top: topPad + 12,
            left: 16,
            child: _circleButton(
              icon: Icons.menu_rounded,
              iconColor: AppColors.primary,
              onTap: () => context.push(RouteNames.settings),
            ),
          ),

          // ─── Floating notification button (top-right) ───
          Positioned(
            top: topPad + 12,
            right: 16,
            child: _circleButton(
              icon: Icons.notifications_none_rounded,
              iconColor: const Color(0xFF1E293B),
              badge: true,
              onTap: () => context.push(RouteNames.notifications),
            ),
          ),

          // ─── GPS + zoom controls (middle-right) ───
          Positioned(
            right: 16,
            top: MediaQuery.of(context).size.height * 0.26,
            child: _buildMapControls(),
          ),

          // ─── Draggable search sheet ───
          _buildSearchSheet(),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════
  // MAP — real FlutterMap with live ride markers
  // ════════════════════════════════════════════════════
  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _kathmandu,
        initialZoom: 11,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
        ),
        onMapReady: () {
          _mapReady = true;
          _fitMapToRides();
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.yatrago.app',
        ),
        MarkerLayer(
          markers: _popularRides
              .map(
                (ride) => Marker(
                  point: LatLng(ride.originLat, ride.originLng),
                  width: 36,
                  height: 36,
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: AppColors.primary,
                    size: 32,
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _circleButton({
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
    bool badge = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, color: iconColor, size: 24),
            if (badge)
              Positioned(
                top: 11,
                right: 11,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapControls() {
    return Column(
      children: [
        _circleButton(
          icon: Icons.gps_fixed,
          iconColor: const Color(0xFF1E293B),
          onTap: () {
            if (_popularRides.isNotEmpty) {
              _fitMapToRides();
            } else {
              _mapController.move(_kathmandu, 11);
            }
          },
        ),
        const SizedBox(height: 12),
        Container(
          width: 46,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(23),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              IconButton(
                icon: const Icon(Icons.add, color: Color(0xFF1E293B), size: 20),
                onPressed: () => _zoomMap(1),
              ),
              Container(width: 22, height: 1, color: const Color(0xFFE2E8F0)),
              IconButton(
                icon: const Icon(Icons.remove,
                    color: Color(0xFF1E293B), size: 20),
                onPressed: () => _zoomMap(-1),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════
  // SEARCH SHEET — draggable; expands to reveal live content
  // ════════════════════════════════════════════════════
  Widget _buildSearchSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.32,
      maxChildSize: 0.94,
      snap: true,
      snapSizes: const [0.32, 0.55, 0.94],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Greeting
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12),
                child: Text(
                  'Hi, ${_userName ?? 'Traveller'} 👋  Where to?',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),

              // From / To card
              _buildLocationCard(),
              const SizedBox(height: 8),

              // Date + Return row
              Row(
                children: [
                  Expanded(
                    child: _buildParamCard(
                      icon: Icons.calendar_today_outlined,
                      label: 'Date',
                      value: DateFormat('EEE, d MMM y').format(_selectedDate),
                      onTap: _selectDate,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildParamCard(
                      icon: Icons.autorenew_rounded,
                      label: 'Return',
                      value: _returnType,
                      onTap: _selectReturnType,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Passengers
              _buildParamCard(
                icon: Icons.person_outline_rounded,
                label: 'Passengers',
                value: '$_seats ${_seats == 1 ? 'Seat' : 'Seats'}',
                onTap: _selectSeats,
              ),
              const SizedBox(height: 12),

              // Search button
              _buildSearchButton(),
              const SizedBox(height: 20),

              // Upcoming trip (live)
              if (_upcomingBooking != null) ...[
                _UpcomingBookingCard(
                  booking: _upcomingBooking!,
                  onTap: () => context.push(
                    RouteNames.passengerRideDetail,
                    extra: _upcomingBooking!.id,
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Available rides (live)
              _buildAvailableRides(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLocationCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
      ),
      child: Column(
        children: [
          // Pickup
          Row(
            children: [
              _locationRing(AppColors.primary),
              const SizedBox(width: 14),
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectLocation(true),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pickup location',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _originName.isEmpty ? 'Select pickup' : _originName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _originName.isEmpty
                              ? AppColors.textHint
                              : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Swap
              GestureDetector(
                onTap: _swapLocations,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE8E8E8)),
                  ),
                  child: const Icon(
                    Icons.swap_vert_rounded,
                    color: Color(0xFF666666),
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          // Connector
          Padding(
            padding: const EdgeInsets.only(left: 5, top: 10, bottom: 10),
            child: Row(
              children: [
                _verticalDots(),
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: 14),
                    child: Divider(
                      color: Color(0xFFF1F5F9),
                      height: 1,
                      thickness: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Drop-off
          Row(
            children: [
              _locationRing(const Color(0xFF3B82F6)),
              const SizedBox(width: 14),
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectLocation(false),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Drop-off location',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF3B82F6),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _destName.isEmpty ? 'Select drop-off' : _destName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _destName.isEmpty
                              ? AppColors.textHint
                              : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _locationRing(Color color) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: color, width: 2.2),
      ),
    );
  }

  Widget _verticalDots() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        3,
        (index) => Container(
          width: 1.5,
          height: 1.5,
          margin: const EdgeInsets.symmetric(vertical: 1.5),
          decoration: const BoxDecoration(
            color: Color(0xFFCBD5E1),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget _buildParamCard({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchButton() {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _submitSearchCard,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Text(
              'Search Rides',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════
  // AVAILABLE RIDES — live API data
  // ════════════════════════════════════════════════════
  Widget _buildAvailableRides() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Available Rides',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              TextButton(
                onPressed: _searchRide,
                child: Text(
                  'See all',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          )
        else if (_popularRides.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  const Icon(
                    Icons.directions_car_outlined,
                    size: 48,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No rides available right now',
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _searchRide,
                    child: const Text('Search rides'),
                  ),
                ],
              ),
            ),
          )
        else
          ...(_popularRides.take(5).map(
                (ride) => RideCard(
                  ride: ride,
                  onTap: () => context.push(
                    RouteNames.rideDetail,
                    extra: ride.toJson(),
                  ),
                ),
              )),
      ],
    );
  }
}

// Upcoming booking card
class _UpcomingBookingCard extends StatelessWidget {
  final BookingModel booking;
  final VoidCallback onTap;

  const _UpcomingBookingCard({required this.booking, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ride = booking.ride;
    if (ride == null) return const SizedBox.shrink();

    final departure = ride['departureAt'] != null
        ? DateTime.parse(ride['departureAt'])
        : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.25),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Upcoming Trip',
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    booking.status.toUpperCase(),
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${ride['originName']} → ${ride['destName']}',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (departure != null) ...[
              const SizedBox(height: 8),
              Text(
                DateFormat('EEE, d MMM • h:mm a').format(departure),
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${booking.seatsBooked} seat${booking.seatsBooked > 1 ? 's' : ''} • NPR ${booking.totalAmount.toStringAsFixed(0)}',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      'View details',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: Colors.white,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
