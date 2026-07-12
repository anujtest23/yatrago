import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/storage/secure_storage.dart';
import 'chat_api.dart';
import 'chat_models.dart';
import 'chat_socket.dart';
import 'chat_unread.dart';

/// One-on-one conversation between the driver and the accepted passenger for
/// a single booking. Real-time via [ChatSocket]; falls back to REST for send
/// and always for history. Read-only once the conversation is closed.
class ChatScreen extends StatefulWidget {
  final String bookingId;
  final String title; // other participant's name
  final String subtitle; // route, e.g. "Kathmandu → Pokhara"
  final Color accent; // brand accent for the current user's bubbles

  const ChatScreen({
    super.key,
    required this.bookingId,
    required this.title,
    required this.subtitle,
    this.accent = AppColors.primary,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <ChatMessage>[];
  final _ids = <String>{};

  String? _myId;
  bool _loading = true;
  bool _canSend = false;
  bool _sending = false;
  String? _error;

  StreamSubscription<ChatMessage>? _msgSub;
  StreamSubscription<String>? _readSub;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _myId = await SecureStorage.getUserId();

    // Realtime: connect, join this booking room, wire listeners.
    await ChatSocket.instance.connect();
    ChatSocket.instance.joinBooking(widget.bookingId);

    _msgSub = ChatSocket.instance.onMessage.listen((m) {
      if (m.bookingId != widget.bookingId) return;
      _append(m);
      // A message arriving while we're looking at it is read immediately.
      if (m.senderId != _myId) {
        ChatSocket.instance.markRead(widget.bookingId);
        ChatUnread.instance.refreshSoon();
      }
    });
    _readSub = ChatSocket.instance.onRead.listen((bookingId) {
      if (bookingId != widget.bookingId) return;
      // The other party read our messages — reflect ticks.
      setState(() {
        for (var i = 0; i < _messages.length; i++) {
          if (_messages[i].senderId == _myId && !_messages[i].isRead) {
            _messages[i] = _copyRead(_messages[i]);
          }
        }
      });
    });

    await _load();
  }

  ChatMessage _copyRead(ChatMessage m) => ChatMessage(
        id: m.id,
        bookingId: m.bookingId,
        senderId: m.senderId,
        content: m.content,
        isRead: true,
        sentAt: m.sentAt,
        senderName: m.senderName,
        senderPhotoUrl: m.senderPhotoUrl,
      );

  Future<void> _load() async {
    try {
      final result = await ChatApi.getMessages(widget.bookingId);
      setState(() {
        _messages
          ..clear()
          ..addAll(result.messages);
        _ids
          ..clear()
          ..addAll(result.messages.map((m) => m.id));
        _canSend = result.canSend;
        _loading = false;
      });
      _scrollToBottom();
      ChatUnread.instance.refreshSoon();
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _append(ChatMessage m) {
    if (_ids.contains(m.id)) return;
    setState(() {
      _ids.add(m.id);
      _messages.add(m);
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _controller.clear();
    try {
      // REST is authoritative and reliable; the server also broadcasts the
      // message over the socket, so [_append] dedupes by id.
      final msg = await ChatApi.sendMessage(widget.bookingId, text);
      _append(msg);
    } catch (e) {
      if (mounted) {
        _controller.text = text; // restore so the user doesn't lose it
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendly(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _friendly(Object e) {
    final s = e.toString();
    return s.contains('closed')
        ? 'This conversation is closed.'
        : 'Could not send. Please try again.';
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _readSub?.cancel();
    ChatSocket.instance.leaveBooking(widget.bookingId);
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgWarm,
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.title, style: const TextStyle(fontSize: 16)),
            if (widget.subtitle.isNotEmpty)
              Text(
                widget.subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody()),
          _buildComposer(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _messages.isEmpty) {
      return _EmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Chat unavailable',
        subtitle: _error!.contains('accepted')
            ? 'Chat opens once the booking is accepted.'
            : 'Could not load this conversation.',
      );
    }
    if (_messages.isEmpty) {
      return const _EmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'Say hello 👋',
        subtitle: 'Send a message to coordinate your ride.',
      );
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      itemCount: _messages.length,
      itemBuilder: (context, i) {
        final m = _messages[i];
        final mine = m.senderId == _myId;
        final showDate = i == 0 ||
            !_sameDay(_messages[i - 1].sentAt, m.sentAt);
        return Column(
          children: [
            if (showDate) _DateChip(date: m.sentAt),
            _Bubble(message: m, mine: mine, accent: widget.accent),
          ],
        );
      },
    );
  }

  Widget _buildComposer() {
    if (!_canSend) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md + MediaQuery.of(context).padding.bottom,
        ),
        color: AppColors.white,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.lock_outline_rounded,
                size: 18, color: AppColors.textTertiary),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'This conversation is closed. You can view past messages.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.borderLight)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Message…',
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sending ? null : _send,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: widget.accent,
                  shape: BoxShape.circle,
                ),
                child: _sending
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final bool mine;
  final Color accent;

  const _Bubble({
    required this.message,
    required this.mine,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(mine ? 18 : 4),
      bottomRight: Radius.circular(mine ? 4 : 18),
    );
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.fromLTRB(14, 9, 14, 7),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.76,
        ),
        decoration: BoxDecoration(
          color: mine ? accent : AppColors.white,
          borderRadius: radius,
          border: mine ? null : Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.content,
              style: TextStyle(
                color: mine ? Colors.white : AppColors.textPrimary,
                fontSize: 15,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _time(message.sentAt),
                  style: TextStyle(
                    fontSize: 10.5,
                    color: mine
                        ? Colors.white.withValues(alpha: 0.8)
                        : AppColors.textTertiary,
                  ),
                ),
                if (mine) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.isRead ? Icons.done_all_rounded : Icons.done_rounded,
                    size: 14,
                    color: message.isRead
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.7),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _time(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ampm';
  }
}

class _DateChip extends StatelessWidget {
  final DateTime date;
  const _DateChip({required this.date});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _label(date),
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  static String _label(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
