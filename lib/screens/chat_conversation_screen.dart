import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_radii.dart';
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

      final imageFile = File(pickedFile.path);
      final shouldSend = await _confirmSendImage(imageFile);
      if (shouldSend != true || !mounted) return;

      await context.read<ChatProvider>().sendImageMessage(
        widget.conversation.id,
        imageFile: imageFile,
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
      );
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

  String _formatClock(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _showMessageActions(ChatMessageModel message) async {
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
                if (message.content.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: const Text('Edit message'),
                    onTap: () => Navigator.of(context).pop('edit'),
                  ),
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
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
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
          result is Map && (result['isSuccess'] == true || result['success'] == true);
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

  @override
  Widget build(BuildContext context) {
    final friend = widget.conversation.friend;
    final currentUserId = context.watch<AuthProvider>().user?.id ?? '';
    final isCallLoading = context.watch<ChatProvider>().isCallLoading;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: scheme.surfaceContainerHighest,
              backgroundImage: friend.avatar.isNotEmpty
                  ? NetworkImage(friend.avatar)
                  : null,
              child: friend.avatar.isEmpty
                  ? Icon(Icons.person_rounded, size: 20, color: scheme.primary)
                  : null,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.username.isNotEmpty ? friend.username : friend.email,
                    style: theme.textTheme.titleLarge?.copyWith(fontSize: 18),
                  ),
                  Text(friend.email, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Audio call',
            onPressed: isCallLoading ? null : () => _startCall('audio'),
            icon: const Icon(Icons.call_outlined),
          ),
          IconButton(
            tooltip: 'Video call',
            onPressed: isCallLoading ? null : () => _startCall('video'),
            icon: const Icon(Icons.videocam_outlined),
          ),
        ],
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
                  onRefresh: () => chatProvider.refreshConversation(),
                  child: chatProvider.isLoading && chatProvider.messages.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg,
                            AppSpacing.lg,
                            AppSpacing.lg,
                            AppSpacing.sm,
                          ),
                          itemCount:
                              chatProvider.messages.length +
                              (chatProvider.isActiveConversationTyping ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == chatProvider.messages.length) {
                              return _TypingIndicatorBubble(
                                color: scheme.surfaceContainerHighest,
                              );
                            }

                            final message = chatProvider.messages[index];
                            final isMine = message.sender.id == currentUserId;
                            return _MessageBubble(
                              message: message,
                              isMine: isMine,
                              onLongPress: isMine
                                  ? () => _showMessageActions(message)
                                  : null,
                              onOpenImage: _openImagePreview,
                            );
                          },
                        ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: scheme.surface,
                  border: Border(top: BorderSide(color: theme.dividerColor)),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isRecordingVoice)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: scheme.errorContainer,
                              borderRadius: BorderRadius.circular(AppRadii.md),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.mic_rounded,
                                  color: scheme.onErrorContainer,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    'Recording voice note ${_formatClock(_recordingElapsedSeconds)}',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          color: scheme.onErrorContainer,
                                        ),
                                  ),
                                ),
                                Text(
                                  'Tap mic to send',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: scheme.onErrorContainer.withValues(
                                      alpha: 0.8,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_editingMessageId != null)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(AppRadii.md),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Editing message',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                ),
                                IconButton(
                                  onPressed: _cancelEditing,
                                  icon: const Icon(Icons.close_rounded),
                                ),
                              ],
                            ),
                          ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            IconButton.filledTonal(
                              onPressed: chatProvider.isSendingMessage
                                  ? null
                                  : _handlePickImage,
                              icon: const Icon(Icons.image_outlined),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            IconButton.filledTonal(
                              onPressed:
                                  chatProvider.isSendingMessage ||
                                      chatProvider.isUpdatingMessage
                                  ? null
                                  : _toggleVoiceRecording,
                              icon: Icon(
                                _isRecordingVoice
                                    ? Icons.stop_circle_outlined
                                    : Icons.mic_none_rounded,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
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
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 0,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            FilledButton(
                              onPressed:
                                  chatProvider.isSendingMessage ||
                                      chatProvider.isUpdatingMessage
                                  ? null
                                  : _handleSend,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(40, 40),
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.lg,
                                  ),
                                ),
                              ),
                              child:
                                  chatProvider.isSendingMessage ||
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

class _MessageBubble extends StatelessWidget {
  static const Color _previewBackground = Color(0xFFF5F7FA);
  final ChatMessageModel message;
  final bool isMine;
  final VoidCallback? onLongPress;
  final Future<void> Function(String imageUrl) onOpenImage;

  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.onLongPress,
    required this.onOpenImage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bubbleColor = isMine
        ? scheme.primary
        : scheme.surfaceContainerHighest;
    final textColor = isMine ? Colors.white : scheme.onSurface;
    final metaColor = isMine
        ? Colors.white.withValues(alpha: 0.72)
        : theme.textTheme.bodyMedium?.color;

    return GestureDetector(
      onLongPress: onLongPress,
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.74,
          ),
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(isMine ? 20 : 6),
              bottomRight: Radius.circular(isMine ? 6 : 20),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.imageUrl.isNotEmpty)
                GestureDetector(
                  onTap: () => onOpenImage(message.imageUrl),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 220,
                      height: 220,
                      color: _previewBackground,
                      child: Image.network(
                        message.imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            alignment: Alignment.center,
                            color: _previewBackground,
                            child: const Icon(Icons.broken_image_outlined),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              if (message.audioUrl.isNotEmpty) ...[
                if (message.imageUrl.isNotEmpty)
                  const SizedBox(height: AppSpacing.sm),
                _AudioMessageView(
                  audioUrl: message.audioUrl,
                  durationSeconds: message.audioDurationSeconds,
                  isMine: isMine,
                ),
              ],
              if ((message.imageUrl.isNotEmpty ||
                      message.audioUrl.isNotEmpty) &&
                  message.content.isNotEmpty)
                const SizedBox(height: AppSpacing.sm),
              if (message.content.isNotEmpty)
                Text(
                  message.content,
                  style: theme.textTheme.bodyLarge?.copyWith(color: textColor),
                ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    message.createdAt != null
                        ? DateFormat('HH:mm').format(message.createdAt!)
                        : '',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: metaColor,
                      fontSize: 11,
                    ),
                  ),
                  if (message.editedAt != null)
                    Text(
                      'edited',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: metaColor,
                        fontSize: 11,
                      ),
                    ),
                  if (isMine)
                    Text(
                      message.isSeen ? 'Seen' : 'Sent',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: metaColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ],
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
    _player.positionStream.listen((position) {
      if (!mounted) return;
      setState(() {
        _position = position;
      });
    });
    _player.durationStream.listen((duration) {
      if (!mounted) return;
      setState(() {
        _duration = duration;
      });
    });
    _player.playerStateStream.listen((state) {
      if (!mounted) return;
      if (state.processingState == ProcessingState.completed) {
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
    if (_isLoading) {
      return;
    }

    if (_player.playing) {
      await _player.pause();
      return;
    }

    try {
      if (!_isPrepared) {
        setState(() {
          _isLoading = true;
        });
        await _player.setUrl(widget.audioUrl);
        _isPrepared = true;
      }

      await _player.play();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foregroundColor = widget.isMine ? Colors.white : scheme.onSurface;
    final progressColor = widget.isMine
        ? Colors.white.withValues(alpha: 0.28)
        : scheme.primary.withValues(alpha: 0.18);
    final totalDuration =
        _duration ?? Duration(seconds: widget.durationSeconds ?? 0);
    final safePosition = _position > totalDuration ? totalDuration : _position;
    final progressValue = totalDuration.inMilliseconds == 0
        ? 0.0
        : safePosition.inMilliseconds / totalDuration.inMilliseconds;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: widget.isMine
            ? Colors.white.withValues(alpha: 0.12)
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: _togglePlayback,
            icon: _isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: foregroundColor,
                    ),
                  )
                : Icon(
                    _player.playing
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_fill_rounded,
                    color: foregroundColor,
                    size: 30,
                  ),
            visualDensity: VisualDensity.compact,
          ),
          SizedBox(
            width: 120,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: progressValue,
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(999),
                  backgroundColor: progressColor,
                  valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${_formatDuration(safePosition)} / ${_formatDuration(totalDuration)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: foregroundColor.withValues(alpha: 0.82),
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
