import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/router/route_names.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_exception.dart';
import 'package:dio/dio.dart';

class IncomingBookingsScreen extends StatefulWidget {
  const IncomingBookingsScreen({super.key});

  @override
  State<IncomingBookingsScreen> createState() => _IncomingBookingsScreenState();
}

class _IncomingBookingsScreenState extends State<IncomingBookingsScreen> {
  List<Map<String, dynamic>> _bookings = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await DioClient.instance.get(
        '/bookings',
        queryParameters: {'role': 'driver', 'status': 'pending'},
      );
      if (!mounted) return;
      setState(() {
        _bookings = List<Map<String, dynamic>>.from(
          response.data['data']['bookings'] ?? [],
        );
        _isLoading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ApiException.fromDioError(e).message;
        _isLoading = false;
      });
    }
  }

  Future<void> _accept(String bookingId) async {
    try {
      await DioClient.instance.patch('/bookings/$bookingId/accept');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking accepted'),
          backgroundColor: AppColors.success,
        ),
      );
      _load();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _reject(String bookingId) async {
    try {
      await DioClient.instance.patch(
        '/bookings/$bookingId/reject',
        data: {'reason': 'Sorry, cannot accommodate'},
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Booking rejected')));
      _load();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  String _timeAgo(String iso) {
    try {
      final date = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return DateFormat('d MMM, h:mm a').format(date);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Incoming Bookings${_bookings.isNotEmpty ? ' (${_bookings.length})' : ''}',
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.driver),
            )
          : _error != null
          ? Center(child: Text(_error!))
          : _bookings.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox_rounded,
                    size: 56,
                    color: AppColors.textTertiary,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No pending bookings',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                itemCount: _bookings.length,
                itemBuilder: (context, i) {
                  final booking = _bookings[i];
                  final passenger =
                      booking['passenger'] as Map<String, dynamic>?;
                  final ride = booking['ride'] as Map<String, dynamic>?;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Passenger info
                        Row(
                          children: [
                            const CircleAvatar(
                              radius: 22,
                              backgroundColor: AppColors.primaryLight,
                              child: Icon(
                                Icons.person,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    passenger?['fullName'] ?? 'Passenger',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${booking['seatsBooked']} seat${(booking['seatsBooked'] ?? 1) > 1 ? 's' : ''} • NPR ${(booking['totalAmount'] ?? 0).toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => context.push(
                                RouteNames.passengerDetails,
                                extra: booking['id'] as String,
                              ),
                              child: const Icon(
                                Icons.info_outline_rounded,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Ride route
                        if (ride != null)
                          Text(
                            'Ride: ${ride['originName']} → ${ride['destName']}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        const SizedBox(height: 8),
                        // Passenger pickup & drop
                        _PointLine(
                          icon: Icons.person_pin_circle_rounded,
                          color: AppColors.primary,
                          label: 'Pickup',
                          value: booking['pickupName'] as String? ??
                              (ride?['originName'] as String? ?? '—'),
                        ),
                        const SizedBox(height: 4),
                        _PointLine(
                          icon: Icons.location_on_rounded,
                          color: AppColors.error,
                          label: 'Drop',
                          value: booking['dropName'] as String? ??
                              (ride?['destName'] as String? ?? '—'),
                        ),
                        if (booking['bookedAt'] != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Requested ${_timeAgo(booking['bookedAt'])}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        // Accept / Reject
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.error,
                                  side: const BorderSide(
                                    color: AppColors.error,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () => _reject(booking['id']),
                                child: const Text('Reject'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.driver,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: () => _accept(booking['id']),
                                child: const Text('Accept'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _PointLine extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _PointLine({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
