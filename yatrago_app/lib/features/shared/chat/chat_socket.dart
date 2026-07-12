import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../core/constants/api_constants.dart';
import '../../../core/storage/secure_storage.dart';
import 'chat_models.dart';

/// Singleton Socket.IO client for real-time chat. Connects to the `/chat`
/// namespace, authenticating the handshake with the current access token —
/// the server refuses any socket that cannot present a valid access token,
/// and authorizes every room join against booking participation.
class ChatSocket {
  ChatSocket._();
  static final ChatSocket instance = ChatSocket._();

  io.Socket? _socket;

  // Incoming new messages (any joined room).
  final _messages = StreamController<ChatMessage>.broadcast();
  Stream<ChatMessage> get onMessage => _messages.stream;

  // The other party read our messages in a booking → flip ticks to "read".
  final _reads = StreamController<String>.broadcast();
  Stream<String> get onRead => _reads.stream;

  // A conversation changed off-screen (new msg for us, or newly opened) →
  // refresh the conversation list / unread badge.
  final _conversationUpdates = StreamController<String>.broadcast();
  Stream<String> get onConversationUpdate => _conversationUpdates.stream;

  bool get isConnected => _socket?.connected ?? false;

  Future<void> connect() async {
    if (_socket != null) {
      if (!(_socket!.connected)) _socket!.connect();
      return;
    }

    final token = await SecureStorage.getAccessToken();
    if (token == null || token.isEmpty) return;

    final socket = io.io(
      '${ApiConstants.socketUrl}/chat',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setAuth({'token': token})
          .build(),
    );

    socket.on('message', (data) {
      if (data is Map) {
        _messages.add(ChatMessage.fromJson(Map<String, dynamic>.from(data)));
      }
    });
    socket.on('read', (data) {
      if (data is Map && data['bookingId'] != null) {
        _reads.add(data['bookingId'] as String);
      }
    });
    socket.on('conversation_update', (data) {
      if (data is Map && data['bookingId'] != null) {
        _conversationUpdates.add(data['bookingId'] as String);
      }
    });
    socket.on('conversation_opened', (data) {
      if (data is Map && data['bookingId'] != null) {
        _conversationUpdates.add(data['bookingId'] as String);
      }
    });

    _socket = socket;
    socket.connect();
  }

  void joinBooking(String bookingId) {
    _socket?.emit('join', {'bookingId': bookingId});
  }

  void leaveBooking(String bookingId) {
    _socket?.emit('leave', {'bookingId': bookingId});
  }

  /// Send over the socket. The ack carries the persisted message (or an
  /// error). Callers should fall back to [ChatApi.sendMessage] if not connected.
  void sendMessage(
    String bookingId,
    String content, {
    void Function(Map<String, dynamic>)? ack,
  }) {
    _socket?.emitWithAck(
      'message',
      {'bookingId': bookingId, 'content': content},
      ack: (data) {
        if (ack != null && data is Map) {
          ack(Map<String, dynamic>.from(data));
        }
      },
    );
  }

  void markRead(String bookingId) {
    _socket?.emit('read', {'bookingId': bookingId});
  }

  /// Full teardown on logout — the socket carries the user's identity.
  void dispose() {
    _socket?.dispose();
    _socket = null;
  }
}
