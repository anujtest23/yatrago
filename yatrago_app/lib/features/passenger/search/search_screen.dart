import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/router/route_names.dart';
import '../../../core/widgets/location_picker_screen.dart';

class SearchScreen extends StatefulWidget {
  final Map<String, dynamic>? initialParams;
  const SearchScreen({super.key, this.initialParams});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  DateTime _selectedDate = DateTime.now();
  int _seats = 1;
  String? _error;

  // Selected pickup/drop, chosen via the map picker
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

  @override
  void initState() {
    super.initState();
    // Pre-fill display text if coming from home screen quick route chips
    // (no coordinates yet — user can tap to refine on the map).
    if (widget.initialParams != null) {
      _originName = widget.initialParams!['from'] ?? '';
      _destName = widget.initialParams!['to'] ?? '';
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _search() {
    setState(() => _error = null);

    final origin = _originName.trim();
    final dest = _destName.trim();

    // Allow searching with just destination or both
    if (dest.isEmpty && origin.isEmpty) {
      // Show all rides
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
        'origin': origin,
        'destination': dest,
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
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.screenPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),

              // Origin + Destination with swap
              Stack(
                children: [
                  Column(
                    children: [
                      // Pickup — opens map picker
                      _buildLocationTile(
                        label: 'Pickup (optional)',
                        name: _originName,
                        hint: 'Select pickup on map',
                        icon: Icons.trip_origin_rounded,
                        iconColor: AppColors.primary,
                        isSelected: _originLat != null,
                        onTap: () => _selectLocation(true),
                      ),

                      const SizedBox(height: 10),

                      // Drop — opens map picker
                      _buildLocationTile(
                        label: 'Drop',
                        name: _destName,
                        hint: 'Select drop on map',
                        icon: Icons.location_on_rounded,
                        iconColor: AppColors.error,
                        isSelected: _destLat != null,
                        onTap: () => _selectLocation(false),
                      ),
                    ],
                  ),

                  // Swap button
                  Positioned(
                    right: 0,
                    top: 26,
                    child: GestureDetector(
                      onTap: _swapLocations,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primary),
                        ),
                        child: const Icon(
                          Icons.swap_vert_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Proximity info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'We show nearby rides first (within 30km), then other rides between the same cities.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Date picker
              const Text(
                'Date',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(
                      AppSpacing.borderRadius,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat('EEEE, d MMMM yyyy').format(_selectedDate),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textTertiary,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Seats
              const Text(
                'Seats',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.event_seat_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Number of seats',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        if (_seats > 1) setState(() => _seats--);
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _seats > 1
                              ? AppColors.primaryLight
                              : AppColors.borderLight,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.remove_rounded,
                          size: 18,
                          color: _seats > 1
                              ? AppColors.primary
                              : AppColors.textTertiary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$_seats',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        if (_seats < 8) setState(() => _seats++);
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ],

              const SizedBox(height: 32),

              // Search button
              GestureDetector(
                onTap: _search,
                child: Container(
                  width: double.infinity,
                  height: AppSpacing.buttonHeight,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
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

              const SizedBox(height: 16),

              // Browse all button
              SizedBox(
                width: double.infinity,
                height: AppSpacing.buttonHeight,
                child: OutlinedButton(
                  onPressed: () => context.push(
                    RouteNames.searchResults,
                    extra: {
                      'origin': '',
                      'destination': '',
                      'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
                      'seats': 1,
                      'originLat': null,
                      'originLng': null,
                      'destLat': null,
                      'destLng': null,
                    },
                  ),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.borderRadius,
                      ),
                    ),
                  ),
                  child: const Text('Browse All Available Rides'),
                ),
              ),

              const SizedBox(height: 32),

              // Quick date chips
              const Text(
                'Quick select',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  _quickDate('Today', DateTime.now()),
                  _quickDate(
                    'Tomorrow',
                    DateTime.now().add(const Duration(days: 1)),
                  ),
                  _quickDate(
                    'Day after',
                    DateTime.now().add(const Duration(days: 2)),
                  ),
                ],
              ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
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
          const SizedBox(width: 14),
          Text(
            'Find a Ride',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationTile({
    required String label,
    required String name,
    required String hint,
    required IconData icon,
    required Color iconColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
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
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    name.isEmpty ? hint : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: name.isEmpty
                          ? AppColors.textTertiary
                          : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.map_rounded,
              color: isSelected ? AppColors.primary : AppColors.textTertiary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickDate(String label, DateTime date) {
    final isSelected =
        DateFormat('yyyy-MM-dd').format(_selectedDate) ==
        DateFormat('yyyy-MM-dd').format(date);
    return GestureDetector(
      onTap: () => setState(() => _selectedDate = date),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
