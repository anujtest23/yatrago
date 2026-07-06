import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../auth/data/auth_api.dart';

/// Lists the account's active device sessions and lets the user revoke any
/// one, or all of them. Backed by GET/DELETE /auth/sessions and
/// POST /auth/logout-all — the account-takeover response surface.
class DeviceSessionsScreen extends StatefulWidget {
  const DeviceSessionsScreen({super.key});

  @override
  State<DeviceSessionsScreen> createState() => _DeviceSessionsScreenState();
}

class _DeviceSessionsScreenState extends State<DeviceSessionsScreen> {
  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final sessions = await AuthApi.getSessions();
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _revoke(String id) async {
    try {
      await AuthApi.revokeSession(id);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session revoked')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _logoutAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out everywhere?'),
        content: const Text(
          'This ends every active session, including this device. You will '
          'need to log in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out all'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await AuthApi.logoutAll();
    } finally {
      // logoutAll clears local storage; the Dio session-expiry hook or the
      // next guarded route will route back to login.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logged out from all devices')),
        );
      }
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return 'Unknown';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return DateFormat('MMM d, y • h:mm a').format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Active Devices'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_error!),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _load,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'These are the devices currently signed in to your '
                    'account. Revoke any you do not recognise.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  ..._sessions.map(
                    (s) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.devices),
                        title: Text(
                          (s['deviceInfo'] as String?)?.isNotEmpty == true
                              ? s['deviceInfo'] as String
                              : 'Unknown device',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          'IP: ${s['ipAddress'] ?? 'unknown'}\n'
                          'Last used: ${_formatDate(s['lastUsedAt'] as String?)}',
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: const Icon(Icons.logout, color: AppColors.error),
                          onPressed: () => _revoke(s['id'] as String),
                        ),
                      ),
                    ),
                  ),
                  if (_sessions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: Text('No active sessions')),
                    ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                    onPressed: _logoutAll,
                    icon: const Icon(Icons.logout),
                    label: const Text('Log out of all devices'),
                  ),
                ],
              ),
            ),
    );
  }
}
