import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../widgets/info_page_scaffold.dart';
import '../widgets/settings_ui.dart';

/// "Location Permission" — leaf page reached from the Privacy Policy hub.
/// Explains why the app uses location. Purely informational: it does NOT
/// request permissions or touch the live map flow (that stays in the
/// production home/tracking screens). No backend.
class LocationPermissionScreen extends StatelessWidget {
  const LocationPermissionScreen({super.key});

  static const _items = <_PermissionDetail>[
    _PermissionDetail(
      icon: Icons.person_search_outlined,
      text: 'Helps us find nearby rides and drivers.',
    ),
    _PermissionDetail(
      icon: Icons.my_location_outlined,
      text: 'Improves accuracy for pickup and drop locations.',
    ),
    _PermissionDetail(
      icon: Icons.shield_outlined,
      text: 'Ensures safety during your journey.',
    ),
    _PermissionDetail(
      icon: Icons.settings_suggest_outlined,
      text: 'You can change location permission anytime from your device '
          'settings.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return InfoPageScaffold(
      title: 'Location Permission',
      subtitle: 'We use your location to provide better and safer services.',
      children: [
        SettingsCard(
          children: [
            for (var i = 0; i < _items.length; i++) ...[
              _PermissionRow(item: _items[i]),
              if (i < _items.length - 1) const SettingsDivider(),
            ],
          ],
        ),
      ],
    );
  }
}

class _PermissionRow extends StatelessWidget {
  final _PermissionDetail item;
  const _PermissionRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(item.icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              item.text,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF334155),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionDetail {
  final IconData icon;
  final String text;

  const _PermissionDetail({required this.icon, required this.text});
}
