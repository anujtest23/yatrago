import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/router/route_names.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/network/dio_client.dart';
import '../../auth/data/auth_api.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic>? _user;
  bool _isLoading = true;
  String _activeMode = 'passenger';

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

  Future<void> _deleteAccount() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This will permanently deactivate your account. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await DioClient.instance.delete('/users/me');
                await SecureStorage.clearAll();
                if (!mounted) return;
                context.go(RouteNames.login);
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
            child: const Text(
              'Delete',
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text('Settings'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 16),

                  // Profile card
                  GestureDetector(
                    onTap: () => context.push(RouteNames.editProfile),
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenPadding,
                      ),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: AppColors.primaryLight,
                            backgroundImage: _user?['profilePhotoUrl'] != null
                                ? NetworkImage(_user!['profilePhotoUrl'])
                                : null,
                            child: _user?['profilePhotoUrl'] == null
                                ? const Icon(
                                    Icons.person_rounded,
                                    size: 32,
                                    color: AppColors.primary,
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
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  _user?['phoneNumber'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.textTertiary,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Mode switch
                  _Section(
                    title: 'Mode',
                    children: [
                      _SettingsTile(
                        icon: _activeMode == 'passenger'
                            ? Icons.drive_eta_rounded
                            : Icons.person_rounded,
                        iconColor: _activeMode == 'passenger'
                            ? AppColors.driver
                            : AppColors.primary,
                        title: _activeMode == 'passenger'
                            ? 'Switch to Driver Mode'
                            : 'Switch to Passenger Mode',
                        subtitle: _activeMode == 'passenger'
                            ? 'Start earning by posting rides'
                            : 'Search and book rides',
                        onTap: _switchMode,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Account
                  _Section(
                    title: 'Account',
                    children: [
                      _SettingsTile(
                        icon: Icons.person_outline_rounded,
                        iconColor: AppColors.primary,
                        title: 'Edit Profile',
                        onTap: () => context.push(RouteNames.editProfile),
                      ),
                      _SettingsTile(
                        icon: Icons.notifications_none_rounded,
                        iconColor: AppColors.primary,
                        title: 'Notifications',
                        onTap: () => context.push(
                          _activeMode == 'driver'
                              ? RouteNames.driverNotifications
                              : RouteNames.notifications,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Danger zone
                  _Section(
                    title: 'Account Actions',
                    children: [
                      _SettingsTile(
                        icon: Icons.logout_rounded,
                        iconColor: AppColors.warning,
                        title: 'Logout',
                        onTap: _logout,
                      ),
                      _SettingsTile(
                        icon: Icons.delete_outline_rounded,
                        iconColor: AppColors.error,
                        title: 'Delete Account',
                        titleColor: AppColors.error,
                        onTap: _deleteAccount,
                        showDivider: false,
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // App version
                  const Text(
                    'YatraGo v1.0.0',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.screenPadding,
            bottom: 8,
          ),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Color? titleColor;
  final VoidCallback onTap;
  final bool showDivider;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.titleColor,
    required this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          onTap: onTap,
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: titleColor ?? AppColors.textPrimary,
            ),
          ),
          subtitle: subtitle != null
              ? Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                )
              : null,
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textTertiary,
            size: 20,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
        ),
        if (showDivider) const Divider(height: 1, indent: 68, endIndent: 16),
      ],
    );
  }
}
