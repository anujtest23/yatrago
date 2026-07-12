import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/router/route_names.dart';
import 'chat_api.dart';
import 'chat_models.dart';
import 'chat_socket.dart';
import 'chat_unread.dart';

/// The Messages tab: every conversation the user has an accepted booking for,
/// newest activity first, with unread badges and last-message previews.
class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  List<Conversation> _items = [];
  bool _loading = true;
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
    ChatSocket.instance.connect();
    // Any live change to a conversation re-pulls the list so previews and
    // unread counts stay fresh without manual refresh.
    _sub = ChatSocket.instance.onConversationUpdate.listen((_) => _load());
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await ChatApi.getConversations();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
      ChatUnread.instance.refresh();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgWarm,
      appBar: AppBar(title: const Text('Messages')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? _empty()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      indent: 84,
                      color: AppColors.borderLight,
                    ),
                    itemBuilder: (context, i) =>
                        _ConversationTile(conversation: _items[i], onTap: _open),
                  ),
                ),
    );
  }

  void _open(Conversation c) {
    final isDriver = c.role == 'driver';
    context
        .push(RouteNames.chat, extra: {
          'bookingId': c.bookingId,
          'title': c.otherUser.fullName ??
              (isDriver ? 'Passenger' : 'Driver'),
          'subtitle': '${c.originName} → ${c.destName}',
          'accentIsDriver': isDriver,
        })
        .then((_) => _load());
  }

  Widget _empty() {
    return ListView(
      // Scrollable so RefreshIndicator-less empty still feels intentional.
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.22),
        const Icon(Icons.forum_outlined,
            size: 56, color: AppColors.textHint),
        const SizedBox(height: 14),
        const Center(
          child: Text(
            'No conversations yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            'Chats open automatically once a booking request is accepted.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final void Function(Conversation) onTap;

  const _ConversationTile({required this.conversation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final isDriver = c.role == 'driver';
    final accent = isDriver ? AppColors.driver : AppColors.primary;
    final hasUnread = c.unreadCount > 0;
    final name = c.otherUser.fullName ?? (isDriver ? 'Passenger' : 'Driver');
    final preview = c.lastMessage?.content ?? 'Say hello 👋';

    return InkWell(
      onTap: () => onTap(c),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          12,
          AppSpacing.md,
          12,
        ),
        child: Row(
          children: [
            _Avatar(name: name, accent: accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight:
                                hasUnread ? FontWeight.w700 : FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (c.lastMessage != null)
                        Text(
                          _relative(c.lastMessage!.sentAt),
                          style: TextStyle(
                            fontSize: 11.5,
                            color: hasUnread ? accent : AppColors.textTertiary,
                            fontWeight:
                                hasUnread ? FontWeight.w700 : FontWeight.w400,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${c.originName} → ${c.destName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: hasUnread
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontWeight:
                                hasUnread ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          constraints: const BoxConstraints(minWidth: 20),
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Text(
                            c.unreadCount > 99 ? '99+' : '${c.unreadCount}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _relative(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24 && now.day == dt.day) {
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m ${dt.hour < 12 ? 'AM' : 'PM'}';
    }
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.day}/${dt.month}';
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final Color accent;
  const _Avatar({required this.name, required this.accent});

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: accent,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
