import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../data/preferences_api.dart';
import '../widgets/info_page_scaffold.dart';
import '../widgets/settings_ui.dart';

/// Privacy settings — profile/phone/ride visibility + marketing & analytics
/// consent, persisted to the backend. Each control PATCHes its single field.
class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  static const _visibility = ['public', 'contacts', 'private'];

  Map<String, dynamic>? _s;
  bool _loading = true;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await PreferencesApi.getPrivacySettings();
      if (!mounted) return;
      setState(() {
        _s = s;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _patch(String key, dynamic value) async {
    final prev = _s![key];
    setState(() {
      _s![key] = value;
      _saving = true;
    });
    try {
      await PreferencesApi.updatePrivacySettings({key: value});
    } catch (e) {
      if (!mounted) return;
      setState(() => _s![key] = prev);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InfoPageScaffold(
      title: 'Privacy',
      subtitle: 'Control your data and visibility',
      children: [
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 60),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          Text(_error!,
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.error))
        else ...[
          const SettingsSectionLabel('Visibility'),
          SettingsCard(
            children: [
              _visibilityRow('Profile', 'profileVisibility'),
              const SettingsDivider(),
              _visibilityRow('Phone number', 'phoneVisibility'),
              const SettingsDivider(),
              _visibilityRow('Ride activity', 'rideVisibility'),
            ],
          ),
          const SizedBox(height: 16),
          const SettingsSectionLabel('Consent'),
          SettingsCard(
            children: [
              _consentRow(
                'Marketing',
                'Receive offers and product news',
                'marketingConsent',
              ),
              const SettingsDivider(),
              _consentRow(
                'Analytics',
                'Help improve YatraGo with usage data',
                'analyticsConsent',
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _visibilityRow(String label, String key) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
          DropdownButton<String>(
            value: _s![key] as String,
            underline: const SizedBox.shrink(),
            borderRadius: BorderRadius.circular(12),
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
            items: _visibility
                .map((v) => DropdownMenuItem(
                      value: v,
                      child: Text(v[0].toUpperCase() + v.substring(1)),
                    ))
                .toList(),
            onChanged: _saving
                ? null
                : (v) {
                    if (v != null) _patch(key, v);
                  },
          ),
        ],
      ),
    );
  }

  Widget _consentRow(String title, String subtitle, String key) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A))),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B))),
              ],
            ),
          ),
          Switch(
            value: _s![key] as bool,
            activeThumbColor: AppColors.primary,
            onChanged: _saving ? null : (v) => _patch(key, v),
          ),
        ],
      ),
    );
  }
}
