import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/route_names.dart';
import '../../../auth/data/auth_api.dart';
import '../widgets/info_page_scaffold.dart';

/// Read-only profile view. Loads the signed-in user via the existing
/// [AuthApi.getMe] and offers an entry to the existing Edit Profile screen.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _user;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final user = await AuthApi.getMe();
      if (!mounted) return;
      setState(() {
        _user = user;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFFEFEFE),
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final name = _user?['fullName'] as String? ?? 'Your Name';
    final phone = _user?['phoneNumber'] as String? ?? '';
    final email = _user?['email'] as String?;
    final photo = _user?['profilePhotoUrl'] as String?;

    return InfoPageScaffold(
      title: 'Profile',
      children: [
        const SizedBox(height: 8),
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 46,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                backgroundImage:
                    photo != null ? NetworkImage(photo) : null,
                child: photo == null
                    ? const Icon(Icons.person_rounded,
                        size: 48, color: AppColors.primary)
                    : null,
              ),
              const SizedBox(height: 14),
              Text(
                name,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              if (phone.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  phone,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        InfoSection(
          title: 'Account details',
          icon: Icons.badge_outlined,
          children: [
            _DetailRow(label: 'Full name', value: name),
            const SizedBox(height: 12),
            _DetailRow(label: 'Phone', value: phone.isEmpty ? '—' : phone),
            const SizedBox(height: 12),
            _DetailRow(
                label: 'Email', value: (email == null || email.isEmpty) ? '—' : email),
          ],
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () => context.push(RouteNames.editProfile),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
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
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }
}
