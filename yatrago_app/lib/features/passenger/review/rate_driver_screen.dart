import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_exception.dart';
import 'package:dio/dio.dart';

/// Rate Driver — Yatri v2 design. Carded layout with a green-check route
/// header, rating card, review card with live counter, and icon quick tags.
/// All review submission wiring (`POST /reviews`) is preserved.
class RateDriverScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  const RateDriverScreen({super.key, required this.data});

  @override
  State<RateDriverScreen> createState() => _RateDriverScreenState();
}

class _RateDriverScreenState extends State<RateDriverScreen> {
  int _rating = 0;
  final _reviewController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  static const Color _darkText = Color(0xFF1E293B);
  static const Color _subtitleText = Color(0xFF64748B);

  final List<Map<String, dynamic>> _quickTags = [
    {'label': 'Safe Driving', 'icon': Icons.verified_user_outlined},
    {'label': 'On Time', 'icon': Icons.access_time_rounded},
    {'label': 'Polite', 'icon': Icons.sentiment_satisfied_alt_rounded},
    {'label': 'Clean Vehicle', 'icon': Icons.directions_car_rounded},
    {'label': 'Friendly', 'icon': Icons.emoji_emotions_outlined},
    {'label': 'Good Music', 'icon': Icons.music_note_rounded},
  ];
  final Set<String> _selectedTags = {};

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  String get _ratingLabel {
    switch (_rating) {
      case 1:
        return 'Very Bad';
      case 2:
        return 'Bad';
      case 3:
        return 'Average';
      case 4:
        return 'Very Good';
      case 5:
        return 'Excellent';
      default:
        return 'Tap a star to rate';
    }
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      setState(() => _error = 'Please select a rating');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final tags = _selectedTags.join(', ');
      final review = _reviewController.text.trim();
      final fullReview = [
        if (tags.isNotEmpty) tags,
        if (review.isNotEmpty) review,
      ].join('. ');

      await DioClient.instance.post(
        '/reviews',
        data: {
          'bookingId': widget.data['bookingId'],
          'rateeId': widget.data['rateeId'],
          'rateeType': 'driver',
          'score': _rating,
          if (fullReview.isNotEmpty) 'reviewText': fullReview,
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Review submitted. Thank you!'),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop();
    } on DioException catch (e) {
      setState(() => _error = ApiException.fromDioError(e).message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final driverName = widget.data['driverName'] as String? ?? 'Driver';

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 16),
                  _buildDriverCard(driverName),
                  const SizedBox(height: 12),
                  _buildRatingSection(driverName),
                  const SizedBox(height: 12),
                  _buildReviewSection(),
                  const SizedBox(height: 16),
                  _buildQuickTags(),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          _buildSubmitButton(),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════
  // HEADER — Green check, dashed route illustration, title
  // ════════════════════════════════════════════════════
  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => context.pop(),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F8F8),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 90,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(260, 60),
                  painter: _RouteDashedPainter(),
                ),
                const Positioned(
                  left: 60,
                  top: 28,
                  child: Icon(Icons.location_on,
                      color: AppColors.primary, size: 22),
                ),
                const Positioned(
                  right: 60,
                  top: 28,
                  child: Icon(Icons.location_on,
                      color: AppColors.primary, size: 22),
                ),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF16A34A).withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 36),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Rate Driver',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: _darkText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your feedback helps us improve your next rides',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: _subtitleText,
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════
  // DRIVER CARD — avatar + name (data-driven, no fabrication)
  // ════════════════════════════════════════════════════
  Widget _buildDriverCard(String driverName) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryLight,
              border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
            ),
            child: const Icon(Icons.person_rounded,
                color: AppColors.primary, size: 32),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driverName,
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _darkText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your recent ride',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _subtitleText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════
  // RATING SECTION
  // ════════════════════════════════════════════════════
  Widget _buildRatingSection(String driverName) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Text(
            'How was your ride?',
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _darkText,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starIndex = index + 1;
              final isSelected = starIndex <= _rating;
              return GestureDetector(
                onTap: () => setState(() {
                  _rating = starIndex;
                  _error = null;
                }),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    isSelected
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color:
                        isSelected ? AppColors.primary : const Color(0xFFCBD5E1),
                    size: 44,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          Text(
            _ratingLabel,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _rating == 0 ? _subtitleText : AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════
  // REVIEW SECTION — with live character counter
  // ════════════════════════════════════════════════════
  Widget _buildReviewSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Write a review (optional)',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _darkText,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _reviewController,
                  maxLines: 3,
                  maxLength: 500,
                  onChanged: (value) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Share your experience with this driver...',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF94A3B8),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    counterText: '',
                  ),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: _darkText,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 16, bottom: 10),
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      '${_reviewController.text.length}/500',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════
  // QUICK TAGS
  // ════════════════════════════════════════════════════
  Widget _buildQuickTags() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: _quickTags.map((tag) {
          final label = tag['label'] as String;
          final icon = tag['icon'] as IconData;
          final isSelected = _selectedTags.contains(label);

          return GestureDetector(
            onTap: () => setState(() {
              if (isSelected) {
                _selectedTags.remove(label);
              } else {
                _selectedTags.add(label);
              }
            }),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFFFF1F1) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    color:
                        isSelected ? AppColors.primary : const Color(0xFF94A3B8),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? AppColors.primary : _darkText,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ════════════════════════════════════════════════════
  // SUBMIT BUTTON (pinned)
  // ════════════════════════════════════════════════════
  Widget _buildSubmitButton() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
        top: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: _isLoading ? null : _submit,
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Submit Review',
                        style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.arrow_forward_rounded,
                          color: Colors.white, size: 22),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════
// Custom painter for dashed route line in header
// ════════════════════════════════════════════════════
class _RouteDashedPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.35)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    path.moveTo(centerX - 100, centerY + 10);
    path.quadraticBezierTo(centerX - 50, centerY - 30, centerX, centerY - 10);
    path.quadraticBezierTo(
        centerX + 50, centerY - 30, centerX + 100, centerY + 10);

    final dashPath = _createDashedPath(path, 5, 4);
    canvas.drawPath(dashPath, paint);

    final dotPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    for (final metric in path.computeMetrics()) {
      final length = metric.length;
      for (double i = 0; i < length; i += length / 6) {
        final tangent = metric.getTangentForOffset(i);
        if (tangent != null) {
          canvas.drawCircle(tangent.position, 2.5, dotPaint);
        }
      }
    }
  }

  Path _createDashedPath(Path source, double dashLength, double gapLength) {
    final dashedPath = Path();
    for (final metric in source.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashLength).clamp(0, metric.length).toDouble();
        dashedPath.addPath(metric.extractPath(distance, end), Offset.zero);
        distance += dashLength + gapLength;
      }
    }
    return dashedPath;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
