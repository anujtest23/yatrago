import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_exception.dart';
import 'package:dio/dio.dart';

class DriverProfileScreen extends StatefulWidget {
  final String driverUserId;
  const DriverProfileScreen({super.key, required this.driverUserId});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final response = await DioClient.instance.get(
        '/drivers/${widget.driverUserId}/profile',
      );
      setState(() {
        _profile = response.data['data'];
        _isLoading = false;
      });
    } on DioException catch (e) {
      setState(() {
        _error = ApiException.fromDioError(e).message;
        _isLoading = false;
      });
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
        title: const Text('Driver Profile'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _error != null
          ? Center(child: Text(_error!))
          : _profile == null
          ? const Center(child: Text('Profile not found'))
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Header
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(AppSpacing.screenPadding),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 44,
                          backgroundColor: AppColors.primaryLight,
                          backgroundImage: _profile!['profilePhotoUrl'] != null
                              ? NetworkImage(_profile!['profilePhotoUrl'])
                              : null,
                          child: _profile!['profilePhotoUrl'] == null
                              ? const Icon(
                                  Icons.person,
                                  size: 44,
                                  color: AppColors.primary,
                                )
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _profile!['fullName'] ?? 'Driver',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Member since ${_profile!['memberSince'] != null ? DateFormat('MMMM yyyy').format(DateTime.parse(_profile!['memberSince'])) : ''}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Stats row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _Stat(
                              value: (_profile!['averageRating'] ?? 0)
                                  .toStringAsFixed(1),
                              label: 'Rating',
                              icon: Icons.star_rounded,
                              color: AppColors.star,
                            ),
                            _Stat(
                              value: '${_profile!['totalTrips'] ?? 0}',
                              label: 'Trips',
                              icon: Icons.directions_car_rounded,
                              color: AppColors.primary,
                            ),
                            _Stat(
                              value: '${(_profile!['totalReviews'] ?? 0)}',
                              label: 'Reviews',
                              icon: Icons.rate_review_rounded,
                              color: AppColors.success,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Vehicle
                  if ((_profile!['vehicles'] as List?)?.isNotEmpty == true) ...[
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(AppSpacing.screenPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Vehicle',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...(_profile!['vehicles'] as List)
                              .map(
                                (v) => Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: AppColors.borderLight,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.directions_car_rounded,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${v['make']} ${v['model']}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          v['color'] ?? '',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              )
                              .toList(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Reviews
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(AppSpacing.screenPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Recent Reviews',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if ((_profile!['recentReviews'] as List?)?.isEmpty !=
                            false)
                          const Text(
                            'No reviews yet.',
                            style: TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 13,
                            ),
                          )
                        else
                          ...(_profile!['recentReviews'] as List)
                              .map((r) => _ReviewTile(review: r))
                              .toList(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _Stat({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
        ),
      ],
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final Map<String, dynamic> review;
  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primaryLight,
            child: const Icon(Icons.person, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      review['rater']?['fullName'] ?? 'Passenger',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          Icons.star_rounded,
                          size: 13,
                          color: i < (review['score'] ?? 0)
                              ? AppColors.star
                              : AppColors.border,
                        ),
                      ),
                    ),
                  ],
                ),
                if (review['reviewText'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    review['reviewText'],
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
