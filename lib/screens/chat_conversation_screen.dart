import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

import '../core/theme/app_colors.dart';

import '../core/theme/app_spacing.dart';
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
  final AudioRecorder _audioRecorder = AudioRecorder();
  static const double _chatSnackTopOffset = 18;
  static const Duration _typingIdleTimeout = Duration(milliseconds: 1200);
  static const Color _imagePreviewBackground = Color(0xFFF5F7FA);
  int _lastRenderedMessageCount = 0;
  bool _isTyping = false;
  bool _isRecordingVoice = false;
  String? _editingMessageId;
  ChatMessageModel? _replyingToMessage;
  int _recordingElapsedSeconds = 0;
  Timer? _typingTimer;
  Timer? _recordingTimer;

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
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
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
          replyTo: _replyingToMessage?.id,
        );
      }
      _messageController.clear();
      setState(() {
        _editingMessageId = null;
        _replyingToMessage = null;
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

      final imageFile = File(pickedFile.path);
      final shouldSend = await _confirmSendImage(imageFile);
      if (shouldSend != true || !mounted) return;

      await context.read<ChatProvider>().sendImageMessage(
        widget.conversation.id,
        imageFile: imageFile,
        replyTo: _replyingToMessage?.id,
      );
      setState(() {
        _replyingToMessage = null;
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

  Future<void> _toggleVoiceRecording() async {
    if (_isRecordingVoice) {
      await _stopVoiceRecordingAndSend();
      return;
    }

    await _startVoiceRecording();
  }

  Future<void> _startVoiceRecording() async {
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        throw Exception('Microphone permission is required');
      }

      final tempDir = await getTemporaryDirectory();
      final filePath =
          '${tempDir.path}/voice-${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 44100,
        ),
        path: filePath,
      );

      _recordingTimer?.cancel();
      setState(() {
        _isRecordingVoice = true;
        _recordingElapsedSeconds = 0;
      });
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          _recordingElapsedSeconds += 1;
        });
      });
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        topOffset: _chatSnackTopOffset,
      );
    }
  }

  Future<void> _stopVoiceRecordingAndSend() async {
    File? audioFile;

    try {
      final filePath = await _audioRecorder.stop();
      _recordingTimer?.cancel();
      if (!mounted) return;

      setState(() {
        _isRecordingVoice = false;
      });

      if (filePath == null || filePath.trim().isEmpty) {
        return;
      }

      audioFile = File(filePath);
      if (!audioFile.existsSync()) {
        throw Exception('Voice recording file was not created');
      }

      await context.read<ChatProvider>().sendVoiceMessage(
        widget.conversation.id,
        audioFile: audioFile,
        durationSeconds: _recordingElapsedSeconds,
        replyTo: _replyingToMessage?.id,
      );
      setState(() {
        _replyingToMessage = null;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        topOffset: _chatSnackTopOffset,
      );
    } finally {
      _recordingTimer?.cancel();
      if (mounted) {
        setState(() {
          _isRecordingVoice = false;
          _recordingElapsedSeconds = 0;
        });
      } else {
        _isRecordingVoice = false;
        _recordingElapsedSeconds = 0;
      }

      if (audioFile != null && audioFile.existsSync()) {
        try {
          await audioFile.delete();
        } catch (_) {}
      }
    }
  }

  Future<bool?> _confirmSendImage(File imageFile) {
    final caption = _messageController.text.trim();

    return showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);

        return AlertDialog(
          title: const Text('Send image?'),
          contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 280),
                  color: _imagePreviewBackground,
                  width: double.infinity,
                  child: Image.file(imageFile, fit: BoxFit.contain),
                ),
              ),
              if (caption.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text('Message', style: theme.textTheme.labelLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(caption, style: theme.textTheme.bodyMedium),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
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

  void _cancelReplying() {
    setState(() {
      _replyingToMessage = null;
    });
  }

  void _startReplying(ChatMessageModel message) {
    setState(() {
      _replyingToMessage = message;
      _editingMessageId = null;
    });
  }

  String _formatClock(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _showMessageActions(
    ChatMessageModel message, {
    required bool isMine,
  }) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.reply),
                  title: const Text('Reply'),
                  onTap: () => Navigator.of(context).pop('reply'),
                ),
                ListTile(
                  leading: const Icon(Icons.check_circle_outline),
                  title: const Text('React Ok'),
                  onTap: () => Navigator.of(context).pop('react_ok'),
                ),
                ListTile(
                  leading: const Icon(Icons.cancel_outlined),
                  title: const Text('React No'),
                  onTap: () => Navigator.of(context).pop('react_no'),
                ),
                if (isMine && message.content.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: const Text('Edit message'),
                    onTap: () => Navigator.of(context).pop('edit'),
                  ),
                if (isMine)
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline,
                      color: AppColors.danger,
                    ),
                    title: const Text('Delete message'),
                    onTap: () => Navigator.of(context).pop('delete'),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) return;

    if (action == 'reply') {
      _startReplying(message);
      return;
    }

    if (action == 'react_ok') {
      await context.read<ChatProvider>().reactToMessage(
        widget.conversation.id,
        message.id,
        'Ok',
      );
      return;
    }

    if (action == 'react_no') {
      await context.read<ChatProvider>().reactToMessage(
        widget.conversation.id,
        message.id,
        'No',
      );
      return;
    }

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
      builder: (dialogContext) {
        var isSaving = false;

        return StatefulBuilder(
          builder: (context, setDialogState) => Dialog(
            insetPadding: const EdgeInsets.all(16),
            backgroundColor: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                color: _imagePreviewBackground,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxHeight: 520,
                        minHeight: 240,
                      ),
                      child: InteractiveViewer(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.contain,
                            placeholder: (context, url) => const SizedBox(
                              width: 240,
                              height: 240,
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) {
                              return const SizedBox(
                                width: 240,
                                height: 240,
                                child: Center(
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    size: 28,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        // border: Border(top: BorderSide(color: Color(0xFFE6E9EF))),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: FilledButton.tonal(
                              onPressed: isSaving
                                  ? null
                                  : () => Navigator.of(dialogContext).pop(),
                              child: const Text('Close'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      setDialogState(() {
                                        isSaving = true;
                                      });
                                      await _saveImageToGallery(imageUrl);
                                      if (mounted) {
                                        setDialogState(() {
                                          isSaving = false;
                                        });
                                      }
                                    },
                              icon: isSaving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.download_rounded),
                              label: Text(isSaving ? 'Saving...' : 'Save'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveImageToGallery(String imageUrl) async {
    try {
      final response = await Dio().get<List<int>>(
        imageUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        throw Exception('Image download failed');
      }

      final fileName = 'chat-image-${DateTime.now().millisecondsSinceEpoch}';
      final result = await ImageGallerySaverPlus.saveImage(
        Uint8List.fromList(bytes),
        name: fileName,
      );

      final isSuccess =
          result is Map &&
          (result['isSuccess'] == true || result['success'] == true);
      if (!isSuccess) {
        throw Exception('Failed to save image');
      }

      if (!mounted) return;
      showSuccessSnackBar(
        context,
        'Image saved to gallery',
        topOffset: _chatSnackTopOffset,
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

  // ── Telegram colour tokens ───────────────────────────────────────────────
  static const Color _lightBg = Color(0xFFDAE8F5); // wallpaper blue-gray
  static const Color _darkBg = Color(0xFF17212B);
  static const Color _lightSenderBubble = AppColors.seed; // App primary color
  static const Color _darkSenderBubble = AppColors.seed; // App primary color
  static const Color _lightReceiverBubble = Colors.white;
  static const Color _darkReceiverBubble = Color(0xFF182533);

  String _dateLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    if (d == today) return 'Today';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('MMMM d, y').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final friend = widget.conversation.friend;
    final currentUserId = context.watch<AuthProvider>().user?.id ?? '';
    final isCallLoading = context.watch<ChatProvider>().isCallLoading;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? _darkBg : _lightBg;
    final senderColor = isDark ? _darkSenderBubble : _lightSenderBubble;
    final receiverColor = isDark ? _darkReceiverBubble : _lightReceiverBubble;
    final inputSurface = isDark ? const Color(0xFF1C2733) : Colors.white;
    final inputBg = isDark ? const Color(0xFF131D26) : const Color(0xFFF0F2F5);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF17212B) : scheme.primary,
        foregroundColor: Colors.white,
        leadingWidth: 60,
        leading: BackButton(
          color: Colors.white,
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 4,
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white24,
              backgroundImage: friend.avatar.isNotEmpty
                  ? CachedNetworkImageProvider(friend.avatar)
                  : null,
              child: friend.avatar.isEmpty
                  ? const Icon(
                      Icons.person_rounded,
                      size: 20,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.username.isNotEmpty ? friend.username : friend.email,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    friend.email,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Video call',
            onPressed: isCallLoading ? null : () => _startCall('video'),
            icon: const Icon(Icons.videocam_outlined, color: Colors.white),
          ),
        ],
      ),
      body: Consumer<ChatProvider>(
        builder: (context, chatProvider, child) {
          if (chatProvider.messages.length != _lastRenderedMessageCount) {
            _lastRenderedMessageCount = chatProvider.messages.length;
            _scrollToBottom();
          }

          final messages = chatProvider.messages;

          // Build a flat list: date separators + message items
          final items = <_ChatListItem>[];
          for (int i = 0; i < messages.length; i++) {
            final msg = messages[i];
            final prev = i > 0 ? messages[i - 1] : null;
            final next = i < messages.length - 1 ? messages[i + 1] : null;

            // Date separator
            if (msg.createdAt != null) {
              final prevDate = prev?.createdAt;
              if (prevDate == null || !_sameDay(prevDate, msg.createdAt!)) {
                items.add(_ChatListItem.separator(_dateLabel(msg.createdAt!)));
              }
            }

            final isMine = msg.sender.id == currentUserId;
            final sameSenderAsPrev =
                prev != null && prev.sender.id == msg.sender.id;
            final sameSenderAsNext =
                next != null && next.sender.id == msg.sender.id;
            // isFirst / isLast in a contiguous same-sender group
            final isFirst = !sameSenderAsPrev;
            final isLast = !sameSenderAsNext;
            items.add(
              _ChatListItem.message(
                msg,
                isMine,
                isFirst,
                isLast,
                senderColor,
                receiverColor,
                friend.avatar,
              ),
            );
          }

          // Typing indicator
          if (chatProvider.isActiveConversationTyping) {
            items.add(_ChatListItem.typing(receiverColor));
          }

          return Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => chatProvider.refreshConversation(),
                  child: chatProvider.isLoading && messages.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            if (item.isSeparator) {
                              return _DateSeparator(
                                label: item.separatorLabel!,
                              );
                            }
                            if (item.isTyping) {
                              return Padding(
                                padding: const EdgeInsets.only(left: 44),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: _TypingIndicatorBubble(
                                    color: item.receiverColor!,
                                  ),
                                ),
                              );
                            }
                            return _TelegramBubble(
                              message: item.message!,
                              isMine: item.isMine!,
                              isFirst: item.isFirst!,
                              isLast: item.isLast!,
                              senderColor: item.senderColor!,
                              receiverColor: item.receiverColor!,
                              senderAvatarUrl: item.senderAvatarUrl!,
                              onLongPress: () => _showMessageActions(
                                item.message!,
                                isMine: item.isMine!,
                              ),
                              onOpenImage: _openImagePreview,
                            );
                          },
                        ),
                ),
              ),

              // ── Telegram-style input bar ───────────────────────────────
              Container(
                color: inputBg,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 6,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_replyingToMessage != null)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(
                              bottom: 4,
                              left: 12,
                              right: 12,
                            ),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.reply,
                                  size: 20,
                                  color: AppColors.seed,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Replying to ${_replyingToMessage!.sender.username}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: AppColors.seed,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _replyingToMessage!.content.isNotEmpty
                                            ? _replyingToMessage!.content
                                            : (_replyingToMessage!
                                                      .imageUrl
                                                      .isNotEmpty
                                                  ? 'Image'
                                                  : 'Voice message'),
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 20),
                                  onPressed: _cancelReplying,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ),
                        // Recording banner
                        if (_isRecordingVoice)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.errorContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.mic_rounded,
                                  color: scheme.onErrorContainer,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Recording ${_formatClock(_recordingElapsedSeconds)}',
                                    style: TextStyle(
                                      color: scheme.onErrorContainer,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                Text(
                                  'Tap mic to send',
                                  style: TextStyle(
                                    color: scheme.onErrorContainer.withValues(
                                      alpha: 0.7,
                                    ),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Editing banner
                        if (_editingMessageId != null)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: inputSurface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border(
                                left: BorderSide(
                                  color: scheme.primary,
                                  width: 3,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Edit message',
                                        style: TextStyle(
                                          color: scheme.primary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _messageController.text,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black54,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: _cancelEditing,
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.black45,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Attachment button
                            GestureDetector(
                              onTap: chatProvider.isSendingMessage
                                  ? null
                                  : _handlePickImage,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: inputSurface,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.attach_file_rounded,
                                  color: isDark
                                      ? Colors.white60
                                      : Colors.black45,
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),

                            // Text field pill
                            Expanded(
                              child: Container(
                                constraints: const BoxConstraints(
                                  minHeight: 40,
                                ),
                                decoration: BoxDecoration(
                                  color: inputSurface,
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          14,
                                          0,
                                          8,
                                          0,
                                        ),
                                        child: TextField(
                                          controller: _messageController,
                                          minLines: 1,
                                          maxLines: 5,
                                          onChanged: _handleMessageChanged,
                                          style: TextStyle(
                                            fontSize: 15,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black87,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: _editingMessageId != null
                                                ? 'Edit message…'
                                                : 'Message',
                                            hintStyle: TextStyle(
                                              color: isDark
                                                  ? Colors.white38
                                                  : Colors.black38,
                                              fontSize: 15,
                                            ),
                                            border: InputBorder.none,
                                            enabledBorder: InputBorder.none,
                                            focusedBorder: InputBorder.none,
                                            disabledBorder: InputBorder.none,
                                            isDense: true,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  vertical: 10,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Mic inside the pill
                                    if (_editingMessageId == null)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 8,
                                          bottom: 8,
                                        ),
                                        child: GestureDetector(
                                          onTap:
                                              (chatProvider.isSendingMessage ||
                                                  chatProvider
                                                      .isUpdatingMessage)
                                              ? null
                                              : _toggleVoiceRecording,
                                          child: Icon(
                                            _isRecordingVoice
                                                ? Icons.stop_circle_outlined
                                                : Icons.mic_none_rounded,
                                            color: isDark
                                                ? Colors.white54
                                                : Colors.black45,
                                            size: 22,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),

                            // Send / confirm button
                            GestureDetector(
                              onTap:
                                  (chatProvider.isSendingMessage ||
                                      chatProvider.isUpdatingMessage)
                                  ? null
                                  : _handleSend,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: scheme.primary,
                                  shape: BoxShape.circle,
                                ),
                                child:
                                    (chatProvider.isSendingMessage ||
                                        chatProvider.isUpdatingMessage)
                                    ? const Padding(
                                        padding: EdgeInsets.all(10),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Icon(
                                        _editingMessageId != null
                                            ? Icons.check_rounded
                                            : Icons.send_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _startCall(String type) async {
    try {
      await context.read<ChatProvider>().startOutgoingCall(
        widget.conversation.id,
        type: type,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      showErrorSnackBar(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        topOffset: _chatSnackTopOffset,
      );
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Data model for the flat chat list (separators + messages + typing)
// ═══════════════════════════════════════════════════════════════════════════
class _ChatListItem {
  final bool isSeparator;
  final bool isTyping;
  final String? separatorLabel;
  final ChatMessageModel? message;
  final bool? isMine;
  final bool? isFirst;
  final bool? isLast;
  final Color? senderColor;
  final Color? receiverColor;
  final String? senderAvatarUrl;

  const _ChatListItem._({
    required this.isSeparator,
    required this.isTyping,
    this.separatorLabel,
    this.message,
    this.isMine,
    this.isFirst,
    this.isLast,
    this.senderColor,
    this.receiverColor,
    this.senderAvatarUrl,
  });

  factory _ChatListItem.separator(String label) => _ChatListItem._(
    isSeparator: true,
    isTyping: false,
    separatorLabel: label,
  );

  factory _ChatListItem.typing(Color receiverColor) => _ChatListItem._(
    isSeparator: false,
    isTyping: true,
    receiverColor: receiverColor,
  );

  factory _ChatListItem.message(
    ChatMessageModel msg,
    bool isMine,
    bool isFirst,
    bool isLast,
    Color senderColor,
    Color receiverColor,
    String senderAvatarUrl,
  ) => _ChatListItem._(
    isSeparator: false,
    isTyping: false,
    message: msg,
    isMine: isMine,
    isFirst: isFirst,
    isLast: isLast,
    senderColor: senderColor,
    receiverColor: receiverColor,
    senderAvatarUrl: senderAvatarUrl,
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// Date separator pill  ("Today", "Yesterday", "January 1, 2025")
// ═══════════════════════════════════════════════════════════════════════════
class _DateSeparator extends StatelessWidget {
  final String label;
  const _DateSeparator({required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Telegram-style message bubble
// ═══════════════════════════════════════════════════════════════════════════
class _TelegramBubble extends StatelessWidget {
  final ChatMessageModel message;
  final bool isMine;
  final bool isFirst;
  final bool isLast;
  final Color senderColor;
  final Color receiverColor;
  final String senderAvatarUrl;
  final VoidCallback? onLongPress;
  final Future<void> Function(String) onOpenImage;

  const _TelegramBubble({
    required this.message,
    required this.isMine,
    required this.isFirst,
    required this.isLast,
    required this.senderColor,
    required this.receiverColor,
    required this.senderAvatarUrl,
    required this.onLongPress,
    required this.onOpenImage,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final bubbleColor = isMine ? senderColor : receiverColor;
    final textColor = isMine
        ? Colors
              .white // Force white on dark teal sender bubble
        : (isDark ? Colors.white : const Color(0xFF1A1A1A));
    final metaColor = isMine
        ? Colors.white.withValues(alpha: 0.65) // Readable white meta text
        : const Color(0xFF9E9E9E);

    // Telegram tail: large radius on all corners except the "tail" corner
    final topLeft = const Radius.circular(18);
    final topRight = const Radius.circular(18);
    final bottomLeft = isMine
        ? const Radius.circular(18)
        : const Radius.circular(4);
    final bottomRight = isMine
        ? const Radius.circular(4)
        : const Radius.circular(18);
    final borderRadius = BorderRadius.only(
      topLeft: isFirst && !isMine ? const Radius.circular(4) : topLeft,
      topRight: isFirst && isMine ? const Radius.circular(4) : topRight,
      bottomLeft: bottomLeft,
      bottomRight: bottomRight,
    );

    final timeStr = message.createdAt != null
        ? DateFormat('HH:mm').format(message.createdAt!)
        : '';

    // ── Shared meta widgets ────────────────────────────────────────────────
    // Pill for image overlay (semi-transparent dark background)
    Widget _overlayPill(Widget child) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );

    Widget timeWidget = Text(
      timeStr,
      style: TextStyle(fontSize: 11, color: metaColor),
    );

    Widget? tickWidget = isMine
        ? Icon(
            message.isSeen ? Icons.done_all_rounded : Icons.check_rounded,
            size: 14,
            color: message.isSeen
                ? (isDark ? const Color(0xFF6BCFF8) : theme.colorScheme.primary)
                : metaColor,
          )
        : null;

    Widget editedWidget = Text(
      'edited',
      style: TextStyle(
        fontSize: 10,
        color: metaColor,
        fontStyle: FontStyle.italic,
      ),
    );

    // Inline meta: time [edited] [tick] — aligned to bottom-right
    Widget inlineMeta = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (message.editedAt != null) ...[
          editedWidget,
          const SizedBox(width: 3),
        ],
        timeWidget,
        if (tickWidget != null) ...[const SizedBox(width: 3), tickWidget],
      ],
    );

    final hasImage = message.imageUrl.isNotEmpty;
    final hasText = message.content.isNotEmpty;
    final hasAudio = message.audioUrl.isNotEmpty;

    // ── Image-only: overlay time top-right, tick bottom-right ─────────────
    Widget imageWidget(bool isOverlay) => GestureDetector(
      onTap: () => onOpenImage(message.imageUrl),
      child: Stack(
        children: [
          CachedNetworkImage(
            imageUrl: message.imageUrl,
            width: double.infinity,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              height: 180,
              alignment: Alignment.center,
              color: isDark
                  ? Colors.white10
                  : Colors.black.withValues(alpha: 0.05),
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
            errorWidget: (context, url, error) => Container(
              height: 120,
              color: isDark
                  ? Colors.white10
                  : Colors.black.withValues(alpha: 0.05),
              alignment: Alignment.center,
              child: const Icon(Icons.broken_image_outlined, size: 32),
            ),
          ),
          if (isOverlay) ...[
            // Time — top-right
            Positioned(
              top: 6,
              right: 6,
              child: _overlayPill(
                Text(
                  timeStr,
                  style: const TextStyle(fontSize: 11, color: Colors.white),
                ),
              ),
            ),
            // Tick — bottom-right
            if (tickWidget != null)
              Positioned(
                bottom: 6,
                right: 6,
                child: _overlayPill(
                  Icon(
                    message.isSeen
                        ? Icons.done_all_rounded
                        : Icons.check_rounded,
                    size: 14,
                    color: message.isSeen
                        ? const Color(0xFF6BCFF8)
                        : Colors.white70,
                  ),
                ),
              ),
          ],
        ],
      ),
    );

    Widget bubbleContent;
    Widget? replyQuoteWidget;
    if (message.replyTo != null) {
      final rm = message.replyTo!;
      replyQuoteWidget = Container(
        margin: EdgeInsets.fromLTRB(10, 8, 10, hasImage ? 6 : 0),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border(left: BorderSide(color: isDark ? Colors.white54 : Colors.black54, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              rm.sender.username.isNotEmpty ? rm.sender.username : 'User',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textColor),
            ),
            const SizedBox(height: 2),
            Text(
              rm.content.isNotEmpty ? rm.content : (rm.imageUrl.isNotEmpty ? 'Photo' : 'Voice Message'),
              style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.85)),
              maxLines: 1, 
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    if (hasImage && !hasText && !hasAudio && replyQuoteWidget == null) {
      // Pure image: overlay everything, no extra rows
      bubbleContent = imageWidget(true);
    } else {
      // Has text and/or audio (may also have image)
      final contentCol = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (replyQuoteWidget != null) replyQuoteWidget,
          if (hasImage) imageWidget(false),
          // Text + audio + inline meta row
          Padding(
            padding: EdgeInsets.fromLTRB(10, hasImage ? 6 : 6, 6, 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Content (audio + text)
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasAudio) ...[
                        _AudioMessageView(
                          audioUrl: message.audioUrl,
                          durationSeconds: message.audioDurationSeconds,
                          isMine: isMine,
                        ),
                        if (hasText) const SizedBox(height: 4),
                      ],
                      if (hasText)
                        Text(
                          message.content,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.35,
                            color: textColor,
                          ),
                        ),
                    ],
                  ),
                ),
                // Meta inline to the right, pinned to bottom
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: inlineMeta,
                ),
              ],
            ),
          ),
        ],
      );
      bubbleContent = contentCol;
    }

    final bubble = GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
          minWidth: 80,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.10),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: bubbleContent,
      ),
    );

    Widget fullBubble = bubble;
    if (message.reaction != null && message.reaction!.isNotEmpty) {
      fullBubble = Stack(
        clipBehavior: Clip.none,
        children: [
          bubble,
          Positioned(
            bottom: -10,
            right: isMine ? 10 : null,
            left: isMine ? null : 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2C3A) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1)),
                ],
              ),
              child: Text(
                message.reaction == 'Ok' ? 'Ok' : 'No',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: message.reaction == 'Ok' ? Colors.green : Colors.red,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Wrap in row with avatar space
    return Padding(
      padding: EdgeInsets.only(
        top: isFirst ? 6 : 2,
        bottom: isLast ? (message.reaction != null ? 14 : 2) : 0,
        left: isMine ? 48 : 0,
        right: isMine ? 0 : 48,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isMine) ...[
            // Avatar (only on last in group, blank placeholder otherwise)
            SizedBox(
              width: 32,
              child: isLast
                  ? CircleAvatar(
                      radius: 16,
                      backgroundImage: senderAvatarUrl.isNotEmpty
                          ? CachedNetworkImageProvider(senderAvatarUrl)
                          : null,
                      backgroundColor: theme.colorScheme.primary.withValues(
                        alpha: 0.2,
                      ),
                      child: senderAvatarUrl.isEmpty
                          ? const Icon(
                              Icons.person_rounded,
                              size: 16,
                              color: Colors.white,
                            )
                          : null,
                    )
                  : null,
            ),
            const SizedBox(width: 6),
          ],
          fullBubble,
          if (isMine) const SizedBox(width: 2),
        ],
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
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(6),
            bottomRight: Radius.circular(20),
          ),
        ),
        child: Text(
          '.' * _dotCount,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontSize: 22,
            height: 0.9,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}

class _AudioMessageView extends StatefulWidget {
  final String audioUrl;
  final int? durationSeconds;
  final bool isMine;

  const _AudioMessageView({
    required this.audioUrl,
    required this.durationSeconds,
    required this.isMine,
  });

  @override
  State<_AudioMessageView> createState() => _AudioMessageViewState();
}

class _AudioMessageViewState extends State<_AudioMessageView> {
  final AudioPlayer _player = AudioPlayer();
  bool _isLoading = false;
  bool _isPrepared = false;
  Duration _position = Duration.zero;
  Duration? _duration;

  @override
  void initState() {
    super.initState();
    _player.positionStream.listen((p) {
      if (!mounted) return;
      setState(() => _position = p);
    });
    _player.durationStream.listen((d) {
      if (!mounted) return;
      setState(() => _duration = d);
    });
    _player.playerStateStream.listen((s) {
      if (!mounted) return;
      if (s.processingState == ProcessingState.completed) {
        _player.seek(Duration.zero);
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    if (_isLoading) return;
    if (_player.playing) {
      await _player.pause();
      return;
    }
    try {
      if (!_isPrepared) {
        setState(() => _isLoading = true);
        await _player.setUrl(widget.audioUrl);
        _isPrepared = true;
      }
      await _player.play();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _fmt(Duration d) {
    final m = (d.inSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Sender uses the primary color (dark teal), so enforce white text/tracks
    final fg = widget.isMine
        ? Colors.white
        : (isDark ? Colors.white : const Color(0xFF1A1A1A));

    final trackBg = widget.isMine
        ? Colors.white.withValues(alpha: 0.25)
        : (isDark
              ? Colors.white.withValues(alpha: 0.28)
              : scheme.primary.withValues(alpha: 0.15));

    final trackFg = widget.isMine
        ? Colors.white
        : (isDark ? Colors.white : scheme.primary);

    final total = _duration ?? Duration(seconds: widget.durationSeconds ?? 0);
    final safePos = _position > total ? total : _position;
    final progress = total.inMilliseconds == 0
        ? 0.0
        : safePos.inMilliseconds / total.inMilliseconds;
    final isPlaying = _player.playing;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Circular play/pause button
        SizedBox(
          width: 36,
          height: 36,
          child: Material(
            color: widget.isMine
                ? Colors.white.withValues(alpha: 0.20)
                : scheme.primary.withValues(alpha: 0.12),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _togglePlayback,
              child: Center(
                child: _isLoading
                    ? SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          color: fg,
                        ),
                      )
                    : Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: widget.isMine ? Colors.white : scheme.primary,
                        size: 20,
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        // Progress + timer
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 3,
                  backgroundColor: trackBg,
                  valueColor: AlwaysStoppedAnimation<Color>(trackFg),
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Icon(
                    Icons.mic_rounded,
                    size: 10,
                    color: fg.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    isPlaying || _position > Duration.zero
                        ? '${_fmt(safePos)} / ${_fmt(total)}'
                        : _fmt(total),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: fg.withValues(alpha: 0.7),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
