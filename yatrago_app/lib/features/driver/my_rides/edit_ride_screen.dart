import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/primary_button.dart';

class EditRideScreen extends StatefulWidget {
  final String tripId;
  const EditRideScreen({super.key, required this.tripId});

  @override
  State<EditRideScreen> createState() => _EditRideScreenState();
}

class _EditRideScreenState extends State<EditRideScreen> {
  Map<String, dynamic>? _trip;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  double _pricePerSeat = 500;
  String _notes = '';
  DateTime? _departureAt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await DioClient.instance.get('/trips/${widget.tripId}');
      final trip = response.data['data'];
      setState(() {
        _trip = trip;
        _pricePerSeat = (trip['pricePerSeat'] ?? 500).toDouble();
        _notes = trip['notes'] ?? '';
        _departureAt = DateTime.parse(trip['departureAt']);
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await DioClient.instance.patch(
        '/trips/${widget.tripId}',
        data: {
          'pricePerSeat': _pricePerSeat,
          'notes': _notes.isEmpty ? null : _notes,
          if (_departureAt != null)
            'departureAt': _departureAt!.toUtc().toIso8601String(),
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ride updated successfully'),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop();
    } on DioException catch (e) {
      setState(() => _error = ApiException.fromDioError(e).message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgWarm,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(onBack: () => context.pop()),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.driver),
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.screenPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Route (read only)
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.driverLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.directions_car_rounded,
                                  color: AppColors.driver,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  '${_trip?['originName']} → ${_trip?['destName']}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.driver,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Departure time
                          const Text(
                            'Departure Time',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.fromDateTime(
                                  _departureAt ?? DateTime.now(),
                                ),
                                builder: (ctx, child) => Theme(
                                  data: Theme.of(ctx).copyWith(
                                    colorScheme: const ColorScheme.light(
                                      primary: AppColors.driver,
                                    ),
                                  ),
                                  child: child!,
                                ),
                              );
                              if (time != null && _departureAt != null) {
                                setState(() {
                                  _departureAt = DateTime(
                                    _departureAt!.year,
                                    _departureAt!.month,
                                    _departureAt!.day,
                                    time.hour,
                                    time.minute,
                                  );
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.border),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.access_time_rounded,
                                    color: AppColors.driver,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    _departureAt != null
                                        ? DateFormat(
                                            'EEE, d MMM • h:mm a',
                                          ).format(_departureAt!)
                                        : 'Select time',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Price
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
                            value: _pricePerSeat,
                            min: 100,
                            max: 5000,
                            divisions: 49,
                            activeColor: AppColors.driver,
                            label: 'NPR ${_pricePerSeat.toStringAsFixed(0)}',
                            onChanged: (v) => setState(() => _pricePerSeat = v),
                          ),
                          Center(
                            child: Text(
                              'NPR ${_pricePerSeat.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: AppColors.driver,
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Notes
                          const Text(
                            'Notes',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            initialValue: _notes,
                            maxLines: 3,
                            onChanged: (v) => setState(() => _notes = v),
                            decoration: const InputDecoration(
                              hintText: 'Any notes for passengers...',
                            ),
                          ),

                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _error!,
                              style: const TextStyle(
                                color: AppColors.error,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                        Container(
                          color: Colors.white,
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                          child: PrimaryButton(
                            text: 'Save Changes',
                            isLoading: _isSaving,
                            backgroundColor: AppColors.driver,
                            onPressed: _save,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader({required VoidCallback onBack}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
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
            'Edit Ride',
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
}
