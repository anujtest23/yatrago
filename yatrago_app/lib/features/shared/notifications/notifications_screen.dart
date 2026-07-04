import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_exception.dart';
import 'package:dio/dio.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  String? _error;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await DioClient.instance.get('/notifications');
      final data = response.data['data'];
      if (!mounted) return;
      setState(() {
        _notifications = List<Map<String, dynamic>>.from(
          data['notifications'] ?? [],
        );
        _unreadCount = data['unreadCount'] ?? 0;
        _isLoading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ApiException.fromDioError(e).message;
        _isLoading = false;
      });
    }
  }

  Future<void> _markAllRead() async {
    try {
      await DioClient.instance.patch('/notifications/read-all');
      await _loadNotifications();
    } catch (_) {}
  }

  Future<void> _markOneRead(String id) async {
    try {
      await DioClient.instance.patch('/notifications/$id/read');
      setState(() {
        final index = _notifications.indexWhere((n) => n['id'] == id);
        if (index != -1) {
          _notifications[index]['isRead'] = true;
          if (_unreadCount > 0) _unreadCount--;
        }
      });
    } catch (_) {}
  }

  IconData _notifIcon(String type) {
    switch (type) {
      case 'booking_confirmed':
        return Icons.check_circle_rounded;
      case 'booking_rejected':
        return Icons.cancel_rounded;
      case 'trip_started':
        return Icons.directions_car_rounded;
      case 'trip_completed':
        return Icons.flag_rounded;
      case 'payment_received':
        return Icons.payments_rounded;
      case 'booking_requested':
        return Icons.inbox_rounded;
      case 'booking_expired':
        return Icons.timer_off_rounded;
      case 'ride_reminder':
        return Icons.alarm_rounded;
      case 'promotion':
        return Icons.local_offer_rounded;
      case 'commission_charged':
        return Icons.percent_rounded;
      case 'wallet_topup':
        return Icons.account_balance_wallet_rounded;
      case 'wallet_low':
        return Icons.warning_amber_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _notifColor(String type) {
    switch (type) {
      case 'booking_confirmed':
      case 'trip_completed':
      case 'payment_received':
        return AppColors.success;
      case 'wallet_topup':
        return AppColors.success;
      case 'booking_rejected':
        return AppColors.error;
      case 'trip_started':
      case 'booking_requested':
        return AppColors.primary;
      case 'ride_reminder':
      case 'wallet_low':
      case 'booking_expired':
        return AppColors.warning;
      case 'commission_charged':
        return const Color(0xFF9B59B6);
      case 'promotion':
        return const Color(0xFF9B59B6);
      default:
        return AppColors.textSecondary;
    }
  }

  String _timeAgo(String? createdAt) {
    if (createdAt == null) return '';
    try {
      final date = DateTime.parse(createdAt).toLocal();
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return DateFormat('d MMM').format(date);
    } catch (_) {
      return '';
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Notifications'),
            if (_unreadCount > 0)
              Text(
                '$_unreadCount unread',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text(
                'Mark all read',
                style: TextStyle(color: AppColors.primary, fontSize: 13),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.wifi_off_rounded,
                    size: 48,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadNotifications,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _notifications.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none_rounded,
                    size: 64,
                    color: AppColors.textTertiary,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'You will be notified about your\nbookings and trips here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadNotifications,
              child: ListView.separated(
                itemCount: _notifications.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final notif = _notifications[i];
                  final isRead = notif['isRead'] == true;
                  final type = notif['type'] as String? ?? 'system';

                  return GestureDetector(
                    onTap: () {
                      if (!isRead) {
                        _markOneRead(notif['id']);
                      }
                    },
                    child: Container(
                      color: isRead ? Colors.white : AppColors.primaryLight,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenPadding,
                        vertical: 14,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Icon
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: _notifColor(type).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _notifIcon(type),
                              size: 22,
                              color: _notifColor(type),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        notif['title'] ?? '',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isRead
                                              ? FontWeight.w500
                                              : FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      _timeAgo(notif['createdAt']),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  notif['body'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                    height: 1.4,
                                  ),
                                ),

                                // Unread dot
                                if (!isRead) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'Tap to mark as read',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
