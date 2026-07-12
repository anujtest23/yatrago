import 'dart:async';

import 'package:flutter/foundation.dart';

import 'chat_api.dart';
import 'chat_socket.dart';

/// App-wide unread-message counter that drives the Messages nav badge.
/// Refreshed from the server and kept live by socket `conversation_update`
/// events, so the badge ticks even while the user is on another screen.
class ChatUnread extends ChangeNotifier {
  ChatUnread._();
  static final ChatUnread instance = ChatUnread._();

  int _count = 0;
  int get count => _count;

  StreamSubscription<String>? _sub;

  /// Call once after login: connect the socket, seed the count and subscribe
  /// to live updates.
  Future<void> start() async {
    await ChatSocket.instance.connect();
    _sub ??= ChatSocket.instance.onConversationUpdate.listen((_) => refresh());
    await refresh();
  }

  Future<void> refresh() async {
    try {
      final next = await ChatApi.getUnreadCount();
      if (next != _count) {
        _count = next;
        notifyListeners();
      }
    } catch (_) {
      // Badge is best-effort; a failed refresh just keeps the last value.
    }
  }

  /// Optimistically clear a conversation's contribution when the user opens it.
  void refreshSoon() {
    // Give the server a beat to persist the read before re-counting.
    Future.delayed(const Duration(milliseconds: 300), refresh);
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _count = 0;
    notifyListeners();
  }
}
