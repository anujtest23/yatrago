import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../data/preferences_api.dart';
import '../widgets/info_page_scaffold.dart';
import '../widgets/settings_ui.dart';

/// Notification preferences — channel (push / email / SMS) × category matrix,
/// persisted to the backend. Each toggle PATCHes only the single channel it
/// changes; the server merges over stored settings.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  static const _categories = <String, String>{
    'booking': 'Bookings',
    'payment': 'Payments',
    'wallet': 'Wallet',
    'chat': 'Chat',
    'promotions': 'Promotions',
    'security': 'Security',
  };
  static const _channels = <String, String>{
    'push': 'Push',
    'email': 'Email',
    'sms': 'SMS',
  };

  Map<String, dynamic>? _prefs;
  bool _loading = true;
  String? _error;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await PreferencesApi.getNotificationPreferences();
      if (!mounted) return;
      setState(() {
        _prefs = prefs;
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

  Future<void> _toggle(String category, String channel, bool value) async {
    final key = '$category.$channel';
    final prev = (_prefs![category] as Map)[channel] as bool;
    setState(() {
      (_prefs![category] as Map)[channel] = value;
      _busy.add(key);
    });
    try {
      await PreferencesApi.updateNotificationPreferences({
        category: {channel: value},
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => (_prefs![category] as Map)[channel] = prev);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  @override
  Widget build(BuildContext context) {
    return InfoPageScaffold(
      title: 'Notifications',
      subtitle: 'Choose what you hear about, and how',
      children: [
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 60),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          _errorBox(_error!)
        else
          ..._categories.entries.map(_categoryCard),
      ],
    );
  }

  Widget _errorBox(String msg) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: Text(msg,
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.error)),
      );

  Widget _categoryCard(MapEntry<String, String> cat) {
    final channels = _channels.keys.toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsSectionLabel(cat.value),
          SettingsCard(
            children: [
              for (var i = 0; i < channels.length; i++) ...[
                if (i > 0) const SettingsDivider(),
                _channelRow(cat.key, channels[i]),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _channelRow(String category, String channel) {
    final value = (_prefs![category] as Map)[channel] as bool? ?? false;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _channels[channel]!,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: AppColors.primary,
            onChanged: _busy.contains('$category.$channel')
                ? null
                : (v) => _toggle(category, channel, v),
          ),
        ],
      ),
    );
  }
}
