import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../models/chat_models.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../utils/snackbar_helper.dart';

class ChatConversationScreen extends StatefulWidget {
  final ChatConversation conversation;

  const ChatConversationScreen({super.key, required this.conversation});

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final Color kPrimaryColor = const Color(0xFF00BFA5);
  static const double _chatSnackTopOffset = 18;
  static const Duration _typingIdleTimeout = Duration(milliseconds: 1200);
  int _lastRenderedMessageCount = 0;
  bool _isTyping = false;
  String? _editingMessageId;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<ChatProvider>().openConversation(
        widget.conversation.id,
      );
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    context.read<ChatProvider>().stopTyping(widget.conversation.id);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    final text = _messageController.text.trim();
    if (text.isEmpty && _editingMessageId == null) return;

    _setTypingState(false);
    try {
      if (_editingMessageId != null) {
        await context.read<ChatProvider>().updateMessage(
          widget.conversation.id,
          _editingMessageId!,
          text,
        );
      } else {
        await context.read<ChatProvider>().sendMessage(
          widget.conversation.id,
          text,
        );
      }
      _messageController.clear();
      setState(() {
        _editingMessageId = null;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        topOffset: _chatSnackTopOffset,
      );
    }
  }

  Future<void> _handlePickImage() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (pickedFile == null || !mounted) return;

      await context.read<ChatProvider>().sendImageMessage(
        widget.conversation.id,
        imageFile: File(pickedFile.path),
      );
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        topOffset: _chatSnackTopOffset,
      );
    }
  }

  void _handleMessageChanged(String value) {
    final trimmedValue = value.trim();
    if (trimmedValue.isEmpty) {
      _typingTimer?.cancel();
      _setTypingState(false);
      return;
    }

    if (!_isTyping) {
      _setTypingState(true);
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(_typingIdleTimeout, () {
      if (!mounted) return;
      _setTypingState(false);
    });
  }

  void _setTypingState(bool isTyping) {
    if (_isTyping == isTyping) {
      return;
    }

    _isTyping = isTyping;
    final chatProvider = context.read<ChatProvider>();
    if (isTyping) {
      chatProvider.startTyping(widget.conversation.id);
    } else {
      chatProvider.stopTyping(widget.conversation.id);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _startEditing(ChatMessageModel message) {
    setState(() {
      _editingMessageId = message.id;
    });
    _messageController.text = message.content;
    _messageController.selection = TextSelection.fromPosition(
      TextPosition(offset: _messageController.text.length),
    );
  }

  void _cancelEditing() {
    setState(() {
      _editingMessageId = null;
    });
    _messageController.clear();
  }

  Future<void> _showMessageActions(ChatMessageModel message) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message.content.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Edit message'),
                  onTap: () => Navigator.of(context).pop('edit'),
                ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete message'),
                onTap: () => Navigator.of(context).pop('delete'),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || action == null) return;

    if (action == 'edit') {
      _startEditing(message);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await context.read<ChatProvider>().deleteMessage(
        widget.conversation.id,
        message.id,
      );
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        topOffset: _chatSnackTopOffset,
      );
    }
  }

  Future<void> _openImagePreview(String imageUrl) async {
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: InteractiveViewer(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(imageUrl, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final friend = widget.conversation.friend;
    final currentUserId = context.watch<AuthProvider>().user?.id ?? '';
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final inputFill = isDark
        ? const Color(0xFF10312C)
        : const Color(0xFFE7F8F4);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              backgroundImage: friend.avatar.isNotEmpty
                  ? NetworkImage(friend.avatar)
                  : null,
              child: friend.avatar.isEmpty
                  ? const Icon(Icons.person, size: 18)
                  : null,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.username.isNotEmpty ? friend.username : friend.email,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  friend.email,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Consumer<ChatProvider>(
        builder: (context, chatProvider, child) {
          if (chatProvider.messages.length != _lastRenderedMessageCount) {
            _lastRenderedMessageCount = chatProvider.messages.length;
            _scrollToBottom();
          }

          return Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  color: kPrimaryColor,
                  onRefresh: () => chatProvider.refreshConversation(),
                  child: chatProvider.isLoading && chatProvider.messages.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          itemCount: chatProvider.messages.length +
                              (chatProvider.isActiveConversationTyping ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == chatProvider.messages.length) {
                              return _TypingIndicatorBubble(
                                color: isDark
                                    ? const Color(0xFF1E1E1E)
                                    : Colors.white,
                              );
                            }

                            final message = chatProvider.messages[index];
                            final isMine = message.sender.id == currentUserId;
                            return _buildMessageBubble(
                              context,
                              message,
                              isMine,
                            );
                          },
                        ),
                ),
              ),
              Container(
                height: 1,
                color: isDark ? Colors.white10 : Colors.black12,
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_editingMessageId != null)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1A2422)
                                : const Color(0xFFF2FBF8),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Editing message',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                              IconButton(
                                onPressed: _cancelEditing,
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: chatProvider.isSendingMessage
                                ? null
                                : _handlePickImage,
                            child: Container(
                              height: 52,
                              width: 52,
                              decoration: BoxDecoration(
                                color: inputFill,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.image_outlined,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              minLines: 1,
                              maxLines: 4,
                              onChanged: _handleMessageChanged,
                              decoration: InputDecoration(
                                hintText: _editingMessageId != null
                                    ? 'Edit message'
                                    : 'Type a message',
                                filled: true,
                                fillColor: inputFill,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap:
                                chatProvider.isSendingMessage ||
                                    chatProvider.isUpdatingMessage
                                ? null
                                : _handleSend,
                            child: Container(
                              height: 52,
                              width: 52,
                              decoration: BoxDecoration(
                                color: kPrimaryColor,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Center(
                                child: chatProvider.isSendingMessage ||
                                        chatProvider.isUpdatingMessage
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Icon(
                                        _editingMessageId != null
                                            ? Icons.check_rounded
                                            : Icons.send_rounded,
                                        color: Colors.white,
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMessageBubble(
    BuildContext context,
    ChatMessageModel message,
    bool isMine,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bubbleColor = isMine
        ? kPrimaryColor
        : (isDark ? const Color(0xFF1E1E1E) : Colors.white);
    final textColor = isMine
        ? Colors.white
        : Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

    return GestureDetector(
      onLongPress: isMine ? () => _showMessageActions(message) : null,
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72,
          ),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMine ? 18 : 4),
              bottomRight: Radius.circular(isMine ? 4 : 18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.imageUrl.isNotEmpty)
                GestureDetector(
                  onTap: () => _openImagePreview(message.imageUrl),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      message.imageUrl,
                      width: 220,
                      height: 220,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 220,
                          height: 220,
                          color: Colors.black12,
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image_outlined),
                        );
                      },
                    ),
                  ),
                ),
              if (message.imageUrl.isNotEmpty && message.content.isNotEmpty)
                const SizedBox(height: 10),
              if (message.content.isNotEmpty)
                Text(
                  message.content,
                  style: TextStyle(color: textColor, fontSize: 15),
                ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.createdAt != null
                        ? DateFormat('HH:mm').format(message.createdAt!)
                        : '',
                    style: TextStyle(
                      color: isMine ? Colors.white70 : Colors.grey[600],
                      fontSize: 11,
                    ),
                  ),
                  if (message.editedAt != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      'edited',
                      style: TextStyle(
                        color: isMine ? Colors.white70 : Colors.grey[600],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypingIndicatorBubble extends StatefulWidget {
  final Color color;

  const _TypingIndicatorBubble({required this.color});

  @override
  State<_TypingIndicatorBubble> createState() => _TypingIndicatorBubbleState();
}

class _TypingIndicatorBubbleState extends State<_TypingIndicatorBubble> {
  late final Timer _timer;
  int _dotCount = 1;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 350), (_) {
      if (!mounted) return;
      setState(() {
        _dotCount = _dotCount == 3 ? 1 : _dotCount + 1;
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(18),
          ),
        ),
        child: Text(
          '.' * _dotCount,
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black54,
            fontSize: 22,
            height: 0.9,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}
