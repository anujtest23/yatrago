import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../auth/data/auth_api.dart';
import '../widgets/settings_ui.dart';

/// Read-only profile view. Loads the signed-in user via the existing
/// [AuthApi.getMe] and offers an entry to the existing Edit Profile screen.
///
/// Visuals adopt the Yatri profile design language — a decorated profile card
/// (wave graphic + avatar/initials) plus, in driver mode, a rating/rides stats
/// card sourced from the real `driverProfile`. The accent follows the active
/// mode (red passenger / green driver); no backend wiring is changed.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _user;
  bool _loading = true;
  String _activeMode = 'passenger';

  bool get _isDriver => _activeMode == 'driver';
  Color get _accent => _isDriver ? AppColors.driver : AppColors.primary;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final user = await AuthApi.getMe();
      final mode = await SecureStorage.getActiveMode();
      if (!mounted) return;
      setState(() {
        _user = user;
        _activeMode = mode ?? (user['activeMode'] as String? ?? 'passenger');
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: const Color(0xFFFEFEFE),
        body: Center(child: CircularProgressIndicator(color: _accent)),
      );
    }

    final name = _user?['fullName'] as String? ?? 'Your Name';
    final phone = _user?['phoneNumber'] as String? ?? '';
    final gender = _user?['gender'] as String?;
    final dob = _user?['dateOfBirth'] as String?;
    final createdAt = _user?['createdAt'] as String?;
    final photo = _user?['profilePhotoUrl'] as String?;
    final isVerified = _user?['isVerified'] == true;
    final driverProfile = _user?['driverProfile'] as Map<String, dynamic>?;

    return Scaffold(
      backgroundColor: const Color(0xFFFEFEFE),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: SettingsPageHeader(title: 'Profile', accent: _accent),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  MediaQuery.of(context).padding.bottom + 32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ProfileCard(
                      name: name,
                      phone: phone,
                      photo: photo,
                      isVerified: isVerified,
                      accent: _accent,
                      onTap: () => context.push(RouteNames.editProfile),
                    ),
                    const SizedBox(height: 16),
                    if (_isDriver && driverProfile != null) ...[
                      _StatsCard(
                        rating:
                            (driverProfile['averageRating'] as num?)?.toDouble() ??
                                0,
                        trips: (driverProfile['totalTrips'] as num?)?.toInt() ?? 0,
                        accent: _accent,
                      ),
                      const SizedBox(height: 16),
                    ],
                    _DetailsCard(
                      accent: _accent,
                      rows: [
                        _Detail('Full name', name),
                        _Detail('Phone', phone.isEmpty ? '—' : phone),
                        _Detail('Gender', _formatGender(gender)),
                        _Detail('Date of birth', _formatDob(dob)),
                        _Detail('Member since', _formatMonthYear(createdAt)),
                        _Detail(
                          'Phone verified',
                          isVerified ? 'Verified' : 'Not verified',
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () => context.push(RouteNames.editProfile),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        label: Text(
                          'Edit Profile',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
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
    );
  }

  // ── formatting helpers ──────────────────────────────────────────
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formatGender(String? g) {
    switch (g) {
      case 'male':
        return 'Male';
      case 'female':
        return 'Female';
      case 'other':
        return 'Other';
      case 'prefer_not_to_say':
        return 'Prefer not to say';
      default:
        return '—';
    }
  }

  String _formatDob(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final d = DateTime.tryParse(iso);
    if (d == null) return '—';
    return '${d.day} ${_months[d.month - 1]} ${d.year}';
  }

  String _formatMonthYear(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final d = DateTime.tryParse(iso);
    if (d == null) return '—';
    return '${_months[d.month - 1]} ${d.year}';
  }
}

String _initials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

// ════════════════════════════════════════════════════════════════
// PROFILE CARD — avatar/initials + name + phone + wave decoration
// ════════════════════════════════════════════════════════════════
class _ProfileCard extends StatelessWidget {
  final String name;
  final String phone;
  final String? photo;
  final bool isVerified;
  final Color accent;
  final VoidCallback onTap;

  const _ProfileCard({
    required this.name,
    required this.phone,
    required this.photo,
    required this.isVerified,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Positioned(
                right: 0,
                bottom: 0,
                width: 100,
                height: 60,
                child: CustomPaint(painter: _ProfileCardWavePainter(accent)),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: accent.withValues(alpha: 0.08),
                      backgroundImage:
                          photo != null ? NetworkImage(photo!) : null,
                      child: photo == null
                          ? Text(
                              _initials(name),
                              style: GoogleFonts.inter(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: accent,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              if (isVerified) ...[
                                const SizedBox(width: 6),
                                Icon(Icons.verified_rounded,
                                    color: accent, size: 18),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.phone_outlined,
                                  color: accent, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                phone.isEmpty ? '—' : phone,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: accent,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.chevron_right_rounded,
                          color: accent, size: 20),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// STATS CARD — driver rating + total rides (real driverProfile data)
// ════════════════════════════════════════════════════════════════
class _StatsCard extends StatelessWidget {
  final double rating;
  final int trips;
  final Color accent;

  const _StatsCard({
    required this.rating,
    required this.trips,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Stat(
              icon: Icons.star_rounded,
              iconColor: AppColors.star,
              value: rating > 0 ? rating.toStringAsFixed(1) : '—',
              label: 'Your Rating',
            ),
          ),
          Container(
            width: 1,
            height: 34,
            color: accent.withValues(alpha: 0.15),
          ),
          Expanded(
            child: _Stat(
              icon: Icons.directions_car_rounded,
              iconColor: accent,
              value: '$trips',
              label: 'Total Rides',
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _Stat({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: iconColor, size: 28),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// DETAILS CARD — real account fields
// ════════════════════════════════════════════════════════════════
class _Detail {
  final String label;
  final String value;
  const _Detail(this.label, this.value);
}

class _DetailsCard extends StatelessWidget {
  final List<_Detail> rows;
  final Color accent;

  const _DetailsCard({required this.rows, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.badge_outlined, color: accent, size: 20),
              const SizedBox(width: 10),
              Text(
                'Account details',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  rows[i].label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(width: 16),
                Flexible(
                  child: Text(
                    rows[i].value,
                    textAlign: TextAlign.right,
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// WAVE PAINTER — decorative corner graphic, tinted to the mode accent
// (ported from Yatri passenger_profile; generalised to any accent)
// ════════════════════════════════════════════════════════════════
class _ProfileCardWavePainter extends CustomPainter {
  final Color accent;
  const _ProfileCardWavePainter(this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    final path1 = Path()
      ..moveTo(0, height)
      ..lineTo(0, height * 0.85)
      ..cubicTo(width * 0.35, height * 0.75, width * 0.7, height * 0.65, width,
          height * 0.5)
      ..lineTo(width, height)
      ..close();
    canvas.drawPath(
      path1,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [
            accent.withValues(alpha: 0.04),
            accent.withValues(alpha: 0.12),
          ],
        ).createShader(Rect.fromLTWH(0, 0, width, height)),
    );

    final path2 = Path()
      ..moveTo(width * 0.1, height)
      ..cubicTo(width * 0.45, height * 0.85, width * 0.75, height * 0.5, width,
          height * 0.25)
      ..lineTo(width, height)
      ..close();
    canvas.drawPath(
      path2,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [
            accent.withValues(alpha: 0.08),
            accent.withValues(alpha: 0.18),
          ],
        ).createShader(Rect.fromLTWH(0, 0, width, height)),
    );

    final path3 = Path()
      ..moveTo(width * 0.35, height)
      ..cubicTo(width * 0.6, height * 0.9, width * 0.82, height * 0.4, width,
          height * 0.05)
      ..lineTo(width, height)
      ..close();
    canvas.drawPath(
      path3,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [
            accent.withValues(alpha: 0.10),
            accent.withValues(alpha: 0.28),
          ],
        ).createShader(Rect.fromLTWH(0, 0, width, height)),
    );
  }

  @override
  bool shouldRepaint(covariant _ProfileCardWavePainter oldDelegate) =>
      oldDelegate.accent != accent;
}
