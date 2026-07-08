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

  final List<Map<String, String>> _popularRoutes = [
    {'from': 'Kathmandu', 'to': 'Pokhara'},
    {'from': 'Kathmandu', 'to': 'Chitwan'},
    {'from': 'Pokhara', 'to': 'Kathmandu'},
    {'from': 'Kathmandu', 'to': 'Butwal'},
    {'from': 'Kathmandu', 'to': 'Dharan'},
    {'from': 'Kathmandu', 'to': 'Biratnagar'},
  ];

  // Accent colors cycled across popular route cards (Yatri design)
  static const List<Color> _routeAccents = [
    AppColors.primary,
    Color(0xFF059669),
    Color(0xFFF59E0B),
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Load user name
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
        padding: const EdgeInsets.all(40),
      ),
    );
  }

  void _zoomMap(double delta) {
    final camera = _mapController.camera;
    _mapController.move(camera.center, camera.zoom + delta);
  }

  void _searchRide({String? from, String? to}) {
    if (from != null && to != null && from.isNotEmpty && to.isNotEmpty) {
      // Popular route chips go directly to search results
      context.push(
        RouteNames.searchResults,
        extra: {
          'origin': from,
          'destination': to,
          'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
          'seats': 1,
          'originLat': null,
          'originLng': null,
          'destLat': null,
          'destLng': null,
        },
      );
    } else {
      // "View all" still opens the full search page
      context.push(RouteNames.search);
    }
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
    return Scaffold(
      backgroundColor: AppColors.bgWarm,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Hero Section with real map ───
              _buildHeroWithMap(),

              // ─── Search Card (overlapping the map) ───
              Transform.translate(
                offset: const Offset(0, -60),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildSearchCard(),
                ),
              ),

              // ─── Upcoming booking ───
              if (_upcomingBooking != null)
                Transform.translate(
                  offset: const Offset(0, -40),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _UpcomingBookingCard(
                      booking: _upcomingBooking!,
                      onTap: () => context.push(
                        RouteNames.passengerRideDetail,
                        extra: _upcomingBooking!.id,
                      ),
                    ),
                  ),
                ),

              // ─── Popular Routes Section ───
              Transform.translate(
                offset: Offset(0, _upcomingBooking != null ? -24 : -40),
                child: _buildPopularRoutes(),
              ),

              // ─── Available Rides ───
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildAvailableRides(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════
  // HERO SECTION — Background image + greeting + real map
  // ════════════════════════════════════════════════════
  Widget _buildHeroWithMap() {
    return SizedBox(
      height: 520,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background image at the top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 230,
            child: Image.asset(
              'assets/images/passenger_top_bg.png',
              fit: BoxFit.cover,
              alignment: Alignment.bottomCenter,
            ),
          ),

          // Greeting text and notification bell
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hi, ${_userName ?? 'Traveller'} 👋',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF4A4A4A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'Where are you\n',
                              style: GoogleFonts.inter(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                height: 1.2,
                              ),
                            ),
                            TextSpan(
                              text: 'going today?',
                              style: GoogleFonts.inter(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Notification bell
                  GestureDetector(
                    onTap: () => context.push(RouteNames.notifications),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFE8E0DA),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(
                            Icons.notifications_none_rounded,
                            color: Color(0xFF4A4A4A),
                            size: 24,
                          ),
                          Positioned(
                            top: 10,
                            right: 10,
                            child: Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                              ),
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

          // Map card (real FlutterMap preview)
          Positioned(
            top: 185,
            left: 12,
            right: 12,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    // Real map — non-interactive preview; whole card taps
                    // through to search results.
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: () => context.push(
                          RouteNames.searchResults,
                          extra: {
                            'origin': '',
                            'destination': '',
                            'date': DateFormat(
                              'yyyy-MM-dd',
                            ).format(DateTime.now()),
                            'seats': 1,
                            'originLat': null,
                            'originLng': null,
                            'destLat': null,
                            'destLng': null,
                          },
                        ),
                        child: FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: _kathmandu,
                            initialZoom: 11,
                            interactionOptions: const InteractionOptions(
                              flags: InteractiveFlag.none,
                            ),
                            onMapReady: () {
                              _mapReady = true;
                              _fitMapToRides();
                            },
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.yatrago.app',
                            ),
                            MarkerLayer(
                              markers: _popularRides
                                  .map(
                                    (ride) => Marker(
                                      point: LatLng(
                                        ride.originLat,
                                        ride.originLng,
                                      ),
                                      width: 32,
                                      height: 32,
                                      child: const Icon(
                                        Icons.location_on_rounded,
                                        color: AppColors.primary,
                                        size: 28,
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Map controls (top-right) — wired to MapController
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Column(
                        children: [
                          // Recenter button
                          GestureDetector(
                            onTap: () {
                              if (_popularRides.isNotEmpty) {
                                _fitMapToRides();
                              } else {
                                _mapController.move(_kathmandu, 11);
                              }
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.my_location,
                                color: Color(0xFF333333),
                                size: 18,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Zoom in
                          GestureDetector(
                            onTap: () => _zoomMap(1),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(12),
                                ),
                                border: Border.all(
                                  color: const Color(0xFFE8E8E8),
                                  width: 0.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.add,
                                color: Color(0xFF333333),
                                size: 20,
                              ),
                            ),
                          ),
                          // Zoom out
                          GestureDetector(
                            onTap: () => _zoomMap(-1),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(12),
                                ),
                                border: Border.all(
                                  color: const Color(0xFFE8E8E8),
                                  width: 0.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.remove,
                                color: Color(0xFF333333),
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════
  // SEARCH CARD — From/To + Date + Passengers + Search
  // ════════════════════════════════════════════════════
  Widget _buildSearchCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // From field
          Row(
            children: [
              // Blue dot
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6),
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: const Color(0xFFBFDBFE), width: 2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectLocation(true),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'From',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF9CA3AF),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _originName.isEmpty
                            ? 'Select pickup on map'
                            : _originName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: _originName.isEmpty
                              ? AppColors.textHint
                              : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Swap button
              GestureDetector(
                onTap: _swapLocations,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFE8E8E8),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.swap_vert_rounded,
                    color: Color(0xFF666666),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),

          // Divider line
          Padding(
            padding: const EdgeInsets.only(left: 24, top: 12, bottom: 12),
            child: Container(
              height: 1,
              color: const Color(0xFFF0F0F0),
            ),
          ),

          // To field
          Row(
            children: [
              // Red dot
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: const Color(0xFFFECACA), width: 2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectLocation(false),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'To',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF9CA3AF),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _destName.isEmpty ? 'Select drop on map' : _destName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: _destName.isEmpty
                              ? AppColors.textHint
                              : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Date and Passengers row
          Row(
            children: [
              // Date
              Expanded(
                child: GestureDetector(
                  onTap: _selectDate,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF5F5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.calendar_today_outlined,
                          color: AppColors.primary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Date',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                                color: const Color(0xFF9CA3AF),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('EEE, d MMM y').format(_selectedDate),
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Vertical divider
              Container(
                width: 1,
                height: 40,
                color: const Color(0xFFF0F0F0),
              ),

              const SizedBox(width: 16),

              // Passengers
              Expanded(
                child: GestureDetector(
                  onTap: _selectSeats,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF5F5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.person_outline_rounded,
                          color: AppColors.primary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Passengers',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                                color: const Color(0xFF9CA3AF),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$_seats ${_seats == 1 ? 'Seat' : 'Seats'}',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Search Rides button
          Container(
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
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.directions_car_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
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
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════
  // POPULAR ROUTES SECTION
  // ════════════════════════════════════════════════════
  Widget _buildPopularRoutes() {
    return Column(
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Popular Routes',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              GestureDetector(
                onTap: () => _searchRide(),
                child: Text(
                  'View all',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Route items with temple illustration
        Stack(
          children: [
            // Temple illustration (bottom-right background)
            Positioned(
              right: -10,
              bottom: 0,
              child: Opacity(
                opacity: 0.3,
                child: Image.asset(
                  'assets/images/passenger_bottom_bg.png',
                  width: 180,
                  height: 160,
                  fit: BoxFit.contain,
                ),
              ),
            ),

            // Route list
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: List.generate(_popularRoutes.length, (i) {
                  final route = _popularRoutes[i];
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: i == _popularRoutes.length - 1 ? 0 : 8,
                    ),
                    child: _buildRouteItem(
                      fromCity: route['from']!,
                      toCity: route['to']!,
                      color: _routeAccents[i % _routeAccents.length],
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRouteItem({
    required String fromCity,
    required String toCity,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF0F0F0),
          width: 1,
        ),
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
          onTap: () => _searchRide(from: fromCity, to: toCity),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Car icon with colored background
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.directions_car_rounded,
                    color: color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),

                // Route details
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          fromCity,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(
                          Icons.arrow_forward,
                          color: Color(0xFF9CA3AF),
                          size: 16,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          toCity,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                // Chevron
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFD1D5DB),
                  size: 24,
                ),
              ],
            ),
          ),
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
                onPressed: () => _searchRide(),
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
                    onPressed: () => _searchRide(),
                    child: const Text('Search rides'),
                  ),
                ],
              ),
            ),
          )
        else
          ...(_popularRides
              .take(5)
              .map(
                (ride) => RideCard(
                  ride: ride,
                  onTap: () => context.push(
                    RouteNames.rideDetail,
                    extra: ride.toJson(),
                  ),
                ),
              )),
        const SizedBox(height: 80),
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
