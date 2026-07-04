import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/secure_storage.dart';

class ContactPassengerScreen extends StatefulWidget {
  final String bookingId;
  final String passengerName;

  const ContactPassengerScreen({
    super.key,
    required this.bookingId,
    required this.passengerName,
  });

  @override
  State<ContactPassengerScreen> createState() => _ContactPassengerScreenState();
}

class _ContactPassengerScreenState extends State<ContactPassengerScreen> {
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _currentUserId;
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _currentUserId = await SecureStorage.getUserId();
    await _loadMessages();
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    try {
      final response = await DioClient.instance.get(
        '/bookings/messages/${widget.bookingId}',
      );
      if (!mounted) return;
      setState(() {
        _messages = List<Map<String, dynamic>>.from(
          response.data['data']['messages'] ?? [],
        );
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    _msgController.clear();

    try {
      final response = await DioClient.instance.post(
        '/bookings/messages',
        data: {'bookingId': widget.bookingId, 'content': text},
      );

      final newMsg = response.data['data']['data'] as Map<String, dynamic>?;
      if (newMsg != null && mounted) {
        setState(() => _messages.add(newMsg));
        _scrollToBottom();
      }
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiException.fromDioError(e).message)),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  bool _isMe(Map<String, dynamic> msg) {
    return msg['senderId'] == _currentUserId;
  }

  String _formatTime(String? sentAt) {
    if (sentAt == null) return '';
    try {
      final date = DateTime.parse(sentAt).toLocal();
      return DateFormat('h:mm a').format(date);
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
            Text(
              widget.passengerName,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const Text(
              'In-trip message',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: _loadMessages,
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 56,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Send a message to your passenger',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(AppSpacing.screenPadding),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) {
                      final msg = _messages[i];
                      final isMe = _isMe(msg);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          mainAxisAlignment: isMe
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (!isMe) ...[
                              const CircleAvatar(
                                radius: 16,
                                backgroundColor: AppColors.primaryLight,
                                child: Icon(
                                  Icons.person,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Column(
                                crossAxisAlignment: isMe
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isMe
                                          ? AppColors.driver
                                          : Colors.white,
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(16),
                                        topRight: const Radius.circular(16),
                                        bottomLeft: Radius.circular(
                                          isMe ? 16 : 4,
                                        ),
                                        bottomRight: Radius.circular(
                                          isMe ? 4 : 16,
                                        ),
                                      ),
                                      border: isMe
                                          ? null
                                          : Border.all(
                                              color: AppColors.borderLight,
                                            ),
                                    ),
                                    child: Text(
                                      msg['content'] ?? '',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isMe
                                            ? Colors.white
                                            : AppColors.textPrimary,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _formatTime(msg['sentAt']),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 8),
                              const CircleAvatar(
                                radius: 16,
                                backgroundColor: AppColors.driverLight,
                                child: Icon(
                                  Icons.drive_eta_rounded,
                                  size: 16,
                                  color: AppColors.driver,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Message input
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 10,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    maxLines: 4,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(
                          color: AppColors.driver,
                          width: 1.5,
                        ),
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _isSending ? null : _sendMessage,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _isSending ? AppColors.border : AppColors.driver,
                      shape: BoxShape.circle,
                    ),
                    child: _isSending
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
