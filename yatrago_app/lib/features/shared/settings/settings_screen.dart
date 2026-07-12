import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/router/route_names.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/network/dio_client.dart';
import '../../auth/data/auth_api.dart';
import 'widgets/settings_ui.dart';

/// Settings Hub — the long-term settings architecture. Yatri card/tile design
/// on top of YatraGo's mode-aware hero and switch-mode banner. Static and
/// backend-dependent sub-pages are reached via named routes; wired actions
/// (profile, logout, mode switch) keep their existing behaviour.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic>? _user;
  bool _isLoading = true;
  String _activeMode = 'passenger';

  bool get _isDriver => _activeMode == 'driver';
  Color get _accent => _isDriver ? AppColors.driver : AppColors.primary;
  bool get _pendingDeletion => _user?['accountStatus'] == 'pending_deletion';

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final user = await AuthApi.getMe();
      final mode = await SecureStorage.getActiveMode();
      if (!mounted) return;
      setState(() {
        _user = user;
        _activeMode = mode ?? 'passenger';
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _switchMode() async {
    final newMode = _activeMode == 'passenger' ? 'driver' : 'passenger';

    try {
      final response = await DioClient.instance.patch(
        '/users/me/mode',
        data: {'mode': newMode},
      );
      final data = response.data['data'];

      if (newMode == 'driver' &&
          data['verificationStatus'] != null &&
          data['verificationStatus'] != 'approved') {
        if (!mounted) return;
        context.push(RouteNames.becomeDriver);
        return;
      }

      await SecureStorage.saveActiveMode(newMode);
      if (!mounted) return;

      if (newMode == 'driver') {
        context.go(RouteNames.driverDashboard);
      } else {
        context.go(RouteNames.passengerHome);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _cancelDeletion() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Deletion'),
        content: const Text(
          'Keep your account active and cancel the scheduled deletion?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel Deletion'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await AuthApi.cancelDeletion();
      await _loadUser();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account deletion cancelled.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _logout() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await AuthApi.logout();
              if (!mounted) return;
              context.go(RouteNames.login);
            },
            child: const Text(
              'Logout',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgWarm,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _accent))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _buildHero(context),
                  const SizedBox(height: 16),
                  if (_pendingDeletion) ...[
                    _buildPendingDeletionBanner(),
                    const SizedBox(height: 16),
                  ],
                  _buildSwitchModeBanner(),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Account ──
                        const SettingsSectionLabel('Account'),
                        SettingsCard(
                          children: [
                            SettingsTile(
                              icon: Icons.person_outline_rounded,
                              accent: _accent,
                              title: 'Profile',
                              subtitle: 'View your account details',
                              onTap: () => context.push(RouteNames.profile),
                            ),
                            const SettingsDivider(),
                            SettingsTile(
                              icon: Icons.edit_outlined,
                              accent: _accent,
                              title: 'Edit Profile',
                              subtitle: 'Update your name, email and photo',
                              onTap: () => context.push(RouteNames.editProfile),
                            ),
                            const SettingsDivider(),
                            SettingsTile(
                              icon: Icons.devices_rounded,
                              accent: _accent,
                              title: 'Active Devices',
                              subtitle: 'Manage your signed-in sessions',
                              onTap: () =>
                                  context.push(RouteNames.deviceSessions),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // ── Preferences ──
                        const SettingsSectionLabel('Preferences'),
                        SettingsCard(
                          children: [
                            SettingsTile(
                              icon: Icons.notifications_none_rounded,
                              accent: _accent,
                              title: 'Notifications',
                              subtitle: 'Manage your ride and app alerts',
                              onTap: () => context
                                  .push(RouteNames.notificationSettings),
                            ),
                            const SettingsDivider(),
                            SettingsTile(
                              icon: Icons.lock_outline_rounded,
                              accent: _accent,
                              title: 'Privacy',
                              subtitle: 'Control your data and visibility',
                              onTap: () =>
                                  context.push(RouteNames.privacySettings),
                            ),
                            const SettingsDivider(),
                            SettingsTile(
                              icon: Icons.contact_phone_outlined,
                              accent: _accent,
                              title: 'Emergency Contacts',
                              subtitle: 'People we can reach in an emergency',
                              onTap: () =>
                                  context.push(RouteNames.emergencyContacts),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // ── Support ──
                        const SettingsSectionLabel('Support'),
                        SettingsCard(
                          children: [
                            SettingsTile(
                              icon: Icons.help_outline_rounded,
                              accent: _accent,
                              title: 'Help & Support',
                              subtitle: 'FAQs and ways to reach us',
                              onTap: () =>
                                  context.push(RouteNames.helpSupport),
                            ),
                            const SettingsDivider(),
                            SettingsTile(
                              icon: Icons.quiz_outlined,
                              accent: _accent,
                              title: 'FAQ',
                              subtitle: 'Answers to common questions',
                              onTap: () => context.push(RouteNames.faq),
                            ),
                            const SettingsDivider(),
                            SettingsTile(
                              icon: Icons.shield_outlined,
                              accent: _accent,
                              title: 'Safety',
                              subtitle: 'Safety tips and emergency info',
                              onTap: () => context.push(RouteNames.safety),
                            ),
                            const SettingsDivider(),
                            SettingsTile(
                              icon: Icons.mail_outline_rounded,
                              accent: _accent,
                              title: 'Contact Us',
                              subtitle: 'Get in touch with support',
                              onTap: () => context.push(RouteNames.contactUs),
                            ),
                            const SettingsDivider(),
                            SettingsTile(
                              icon: Icons.flag_outlined,
                              accent: _accent,
                              title: 'Report an Issue',
                              subtitle: 'Tell us about a problem',
                              onTap: () => context.push(RouteNames.reportIssue),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // ── About ──
                        const SettingsSectionLabel('About'),
                        SettingsCard(
                          children: [
                            SettingsTile(
                              icon: Icons.info_outline_rounded,
                              accent: _accent,
                              title: 'About App',
                              subtitle: 'Learn more about YatraGo',
                              onTap: () => context.push(RouteNames.aboutApp),
                            ),
                            const SettingsDivider(),
                            SettingsTile(
                              icon: Icons.description_outlined,
                              accent: _accent,
                              title: 'Terms & Conditions',
                              subtitle: 'Read our terms of service',
                              onTap: () =>
                                  context.push(RouteNames.termsConditions),
                            ),
                            const SettingsDivider(),
                            SettingsTile(
                              icon: Icons.privacy_tip_outlined,
                              accent: _accent,
                              title: 'Privacy Policy',
                              subtitle: 'How we protect your data',
                              onTap: () =>
                                  context.push(RouteNames.privacyPolicy),
                            ),
                            const SettingsDivider(),
                            SettingsTile(
                              icon: Icons.code_rounded,
                              accent: _accent,
                              title: 'App Version',
                              subtitle: 'You are using the latest version',
                              trailing: Text(
                                '1.0.0',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                              onTap: () => context.push(RouteNames.appVersion),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // ── Account Actions ──
                        const SettingsSectionLabel('Account Actions'),
                        SettingsCard(
                          children: [
                            SettingsTile(
                              icon: Icons.logout_rounded,
                              accent: AppColors.warning,
                              title: 'Logout',
                              subtitle: 'Sign out from this device',
                              onTap: _logout,
                            ),
                            const SettingsDivider(),
                            if (_pendingDeletion)
                              SettingsTile(
                                icon: Icons.restore_rounded,
                                accent: _accent,
                                title: 'Cancel Deletion',
                                subtitle: 'Keep your account active',
                                onTap: _cancelDeletion,
                              )
                            else
                              SettingsTile(
                                icon: Icons.delete_outline_rounded,
                                accent: AppColors.error,
                                title: 'Delete Account',
                                subtitle: 'Schedule your account for deletion',
                                isDestructive: true,
                                onTap: () async {
                                  await context.push(
                                    RouteNames.deleteAccount,
                                    extra: _isDriver
                                        ? RouteNames.driverSettings
                                        : RouteNames.settings,
                                  );
                                  // Refresh so the pending banner appears if
                                  // the user completed the deletion flow.
                                  if (mounted) _loadUser();
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        Center(
                          child: Text(
                            'YatraGo v1.0.0',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ════════════════════════════════════════════════════
  // PENDING DELETION BANNER — grace-period warning + cancel
  // ════════════════════════════════════════════════════
  Widget _buildPendingDeletionBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.error,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Account scheduled for deletion',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Your account will be permanently deleted after the 30-day grace '
              'period. Bookings, rides, top-ups and payouts are disabled until '
              'you cancel.',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: _cancelDeletion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Cancel Deletion',
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
    );
  }

  // ════════════════════════════════════════════════════
  // HERO — mode-aware banner (red passenger / green driver)
  // ════════════════════════════════════════════════════
  Widget _buildHero(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 16,
        20,
        28,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isDriver
              ? const [AppColors.driver, Color(0xFF0F3D14)]
              : const [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Settings',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => context.push(RouteNames.profile),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  backgroundImage: _user?['profilePhotoUrl'] != null
                      ? NetworkImage(_user!['profilePhotoUrl'])
                      : null,
                  child: _user?['profilePhotoUrl'] == null
                      ? const Icon(
                          Icons.person_rounded,
                          size: 34,
                          color: Colors.white,
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _user?['fullName'] ?? 'Your Name',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        _user?['phoneNumber'] ?? '',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _isDriver ? 'DRIVER MODE' : 'PASSENGER MODE',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white70,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════
  // SWITCH MODE BANNER — prominent card
  // ════════════════════════════════════════════════════
  Widget _buildSwitchModeBanner() {
    final targetColor = _isDriver ? AppColors.primary : AppColors.driver;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: _switchMode,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: targetColor.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: targetColor.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: targetColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _isDriver ? Icons.person_rounded : Icons.drive_eta_rounded,
                  color: targetColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isDriver
                          ? 'Switch to Passenger Mode'
                          : 'Switch to Driver Mode',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isDriver
                          ? 'Search and book rides'
                          : 'Start earning by posting rides',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: targetColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.swap_horiz_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
