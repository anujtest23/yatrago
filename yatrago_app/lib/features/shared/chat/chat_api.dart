import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/constants/api_constants.dart';
import 'chat_models.dart';

/// REST access to the chat feature. Durable path for loading history and a
/// send fallback when the realtime socket is unavailable. Every write here is
/// also fanned out over the socket by the server, so transports stay in sync.
class ChatApi {
  static Future<List<Conversation>> getConversations() async {
    try {
      final res = await DioClient.instance.get(ApiConstants.chatConversations);
      final data = res.data['data'] ?? res.data;
      return List<Map<String, dynamic>>.from(data['conversations'] ?? [])
          .map(Conversation.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  static Future<int> getUnreadCount() async {
    try {
      final res = await DioClient.instance.get(ApiConstants.chatUnreadCount);
      final data = res.data['data'] ?? res.data;
      return data['unreadCount'] as int? ?? 0;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Loads history and marks received messages read as a side effect.
  /// Returns the messages plus whether the conversation is still open.
  static Future<({List<ChatMessage> messages, bool canSend})> getMessages(
    String bookingId,
  ) async {
    try {
      final res = await DioClient.instance.get(
        ApiConstants.chatMessages(bookingId),
      );
      final data = res.data['data'] ?? res.data;
      final messages =
          List<Map<String, dynamic>>.from(data['messages'] ?? [])
              .map(ChatMessage.fromJson)
              .toList();
      return (messages: messages, canSend: data['canSend'] as bool? ?? false);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  static Future<ChatMessage> sendMessage(
    String bookingId,
    String content,
  ) async {
    try {
      final res = await DioClient.instance.post(
        ApiConstants.chatMessages(bookingId),
        data: {'content': content},
      );
      final data = res.data['data'] ?? res.data;
      return ChatMessage.fromJson(data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  static Future<void> markRead(String bookingId) async {
    try {
      await DioClient.instance.post(ApiConstants.chatRead(bookingId));
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
