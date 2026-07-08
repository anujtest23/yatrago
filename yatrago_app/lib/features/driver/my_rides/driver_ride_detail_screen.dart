import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/router/route_names.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/route_map_widget.dart';

class DriverRideDetailScreen extends StatefulWidget {
  final String tripId;
  const DriverRideDetailScreen({super.key, required this.tripId});

  @override
  State<DriverRideDetailScreen> createState() => _DriverRideDetailScreenState();
}

class _DriverRideDetailScreenState extends State<DriverRideDetailScreen> {
  Map<String, dynamic>? _trip;
  bool _isLoading = true;
  bool _isActing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await DioClient.instance.get('/trips/${widget.tripId}');
      setState(() {
        _trip = response.data['data'];
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _startTrip() async {
    setState(() => _isActing = true);
    try {
      await DioClient.instance.patch('/trips/${widget.tripId}/start');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trip started!'),
          backgroundColor: AppColors.success,
        ),
      );
      context.push(
        RouteNames.tripTracking,
        extra: {
          'tripId': widget.tripId,
          'isDriver': true,
          'originLat': (_trip!['originLat'] ?? 0).toDouble(),
          'originLng': (_trip!['originLng'] ?? 0).toDouble(),
          'originName': _trip!['originName'] ?? '',
          'destLat': (_trip!['destLat'] ?? 0).toDouble(),
          'destLng': (_trip!['destLng'] ?? 0).toDouble(),
          'destName': _trip!['destName'] ?? '',
        },
      );
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiException.fromDioError(e).message)),
      );
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _completeTrip() async {
    setState(() => _isActing = true);
    try {
      final response = await DioClient.instance.patch(
        '/trips/${widget.tripId}/complete',
      );
      final data = response.data['data'];
      if (!mounted) return;
      final enrichedData = {
        ...data,
        'tripId': widget.tripId, // guarantee it is always present
      };
      context.pushReplacement(RouteNames.tripSummary, extra: enrichedData);
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiException.fromDioError(e).message)),
      );
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _cancelTrip() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Trip?'),
        content: const Text(
          'All passengers will be notified. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await DioClient.instance.delete('/trips/${widget.tripId}');
                if (!mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Trip cancelled')));
                context.pop();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
            child: const Text(
              'Cancel Trip',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF4F7F5),
        body: Center(child: CircularProgressIndicator(color: AppColors.driver)),
      );
    }

    if (_trip == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F7F5),
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(context, ''),
              const Expanded(child: Center(child: Text('Trip not found'))),
            ],
          ),
        ),
      );
    }

    final status = _trip!['status'] as String? ?? '';
    final bookings = _trip!['bookings'] as List? ?? [];
    DateTime? departure;
    try {
      departure = DateTime.parse(_trip!['departureAt']);
    } catch (_) {}

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F5),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, status),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  children: [
                    // Real route map
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: _cardDecoration(),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: RouteMapWidget(
                          originLat: (_trip!['originLat'] ?? 0).toDouble(),
                          originLng: (_trip!['originLng'] ?? 0).toDouble(),
                          originName: _trip!['originName'] ?? '',
                          destLat: (_trip!['destLat'] ?? 0).toDouble(),
                          destLng: (_trip!['destLng'] ?? 0).toDouble(),
                          destName: _trip!['destName'] ?? '',
                          stops: ((_trip!['stops'] as List?) ?? [])
                              .map(
                                (s) => RouteStop(
                                  lat: (s['lat'] ?? 0).toDouble(),
                                  lng: (s['lng'] ?? 0).toDouble(),
                                  name: s['locationName'] ?? '',
                                ),
                              )
                              .toList(),
                          height: 200,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Route + stats card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.driverLight,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${_trip!['originName']} → ${_trip!['destName']}',
                                  style: GoogleFonts.inter(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.driver,
                                  ),
                                ),
                              ),
                              _StatusChip(status: status),
                            ],
                          ),
                          if (departure != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today_rounded,
                                  size: 14,
                                  color: AppColors.driver,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  DateFormat('EEE, d MMM • h:mm a')
                                      .format(departure),
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: AppColors.driver,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _Stat(
                                label: 'Available',
                                value:
                                    '${_trip!['availableSeats']}/${_trip!['totalSeats']}',
                                icon: Icons.event_seat_rounded,
                              ),
                              _Stat(
                                label: 'Per seat',
                                value:
                                    'NPR ${(_trip!['pricePerSeat'] ?? 0).toStringAsFixed(0)}',
                                icon: Icons.payments_rounded,
                              ),
                              _Stat(
                                label: 'Bookings',
                                value: '${bookings.length}',
                                icon: Icons.confirmation_number_rounded,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    if (bookings.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: _cardDecoration(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Passengers',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...bookings.map((b) {
                              final p =
                                  b['passenger'] as Map<String, dynamic>?;
                              final name = p?['fullName'] ?? 'Passenger';
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  children: [
                                    const CircleAvatar(
                                      radius: 18,
                                      backgroundColor: AppColors.primaryLight,
                                      child: Icon(
                                        Icons.person,
                                        size: 18,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            '${b['seatsBooked']} seat${(b['seatsBooked'] ?? 1) > 1 ? 's' : ''} • ${(b['status'] ?? '').toUpperCase()}',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => context.push(
                                        RouteNames.contactPassenger,
                                        extra: {
                                          'bookingId': b['id'] as String,
                                          'passengerName': name,
                                        },
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryLight,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.chat_rounded,
                                              size: 14,
                                              color: AppColors.primary,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Contact',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Action bar
            if (status == 'published' || status == 'in_progress')
              Container(
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  16 + MediaQuery.of(context).padding.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (status == 'published') ...[
                      _gradientButton(
                        label: 'Start Trip',
                        colors: const [AppColors.driver, Color(0xFF0F3D14)],
                        onTap: _isActing ? null : _startTrip,
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: _cancelTrip,
                        child: Container(
                          width: double.infinity,
                          height: 54,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border:
                                Border.all(color: AppColors.error, width: 1.4),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Cancel Trip',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (status == 'in_progress')
                      _gradientButton(
                        label: 'Complete Trip',
                        colors: const [
                          AppColors.success,
                          Color(0xFF0B5744),
                        ],
                        onTap: _isActing ? null : _completeTrip,
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String status) {
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
                color: AppColors.driver,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            'Ride Detail',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          if (status == 'published')
            GestureDetector(
              onTap: () =>
                  context.push(RouteNames.editRide, extra: widget.tripId),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.driverLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.edit_rounded,
                  color: AppColors.driver,
                  size: 20,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _gradientButton({
    required String label,
    required List<Color> colors,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: _isActing
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFF1F5F9)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  Color get color {
    switch (status) {
      case 'published':
        return AppColors.success;
      case 'in_progress':
        return AppColors.primary;
      case 'completed':
        return AppColors.textSecondary;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.textTertiary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase().replaceAll('_', ' '),
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _Stat({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: AppColors.driver),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.driver,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, color: AppColors.driver),
        ),
      ],
    );
  }
}
