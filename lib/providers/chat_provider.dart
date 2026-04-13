import 'package:flutter/material.dart';
import 'dart:io';
import '../models/chat_models.dart';
import '../services/chat_service.dart';
import '../services/chat_socket_service.dart';

class ChatProvider with ChangeNotifier {
  final ChatService _chatService;
  final ChatSocketService _chatSocketService;

  ChatProvider({ChatService? chatService, ChatSocketService? chatSocketService})
    : _chatService = chatService ?? ChatService(),
      _chatSocketService = chatSocketService ?? ChatSocketService() {
    _chatSocketService.configure(
      onMessage: _handleIncomingMessage,
      onMessageUpdated: _handleUpdatedMessage,
      onMessageDeleted: _handleDeletedMessage,
      onMessagesSeen: _handleMessagesSeen,
      onConversationUpdated: _handleConversationUpdated,
      onTypingChanged: _handleTypingChanged,
    );
  }

  bool _isLoading = false;
  bool _isSendingMessage = false;
  bool _isUpdatingMessage = false;
  String _searchQuery = '';
  String? _activeConversationId;
  final Map<String, Set<String>> _typingUserIdsByConversation = {};

  List<ChatUser> _searchResults = [];
  List<FriendRequestModel> _receivedRequests = [];
  List<FriendRequestModel> _sentRequests = [];
  List<ChatConversation> _conversations = [];
  List<ChatMessageModel> _messages = [];

  bool get isLoading => _isLoading;
  bool get isSendingMessage => _isSendingMessage;
  bool get isUpdatingMessage => _isUpdatingMessage;
  String get searchQuery => _searchQuery;
  List<ChatUser> get searchResults => _searchResults;
  List<FriendRequestModel> get receivedRequests => _receivedRequests;
  List<FriendRequestModel> get sentRequests => _sentRequests;
  List<ChatConversation> get conversations => _conversations;
  List<ChatMessageModel> get messages => _messages;
  bool get isActiveConversationTyping {
    final conversationId = _activeConversationId;
    if (conversationId == null) {
      return false;
    }

    return (_typingUserIdsByConversation[conversationId] ?? const <String>{})
        .isNotEmpty;
  }

  bool isFriend(String userId) {
    return _conversations.any(
      (conversation) => conversation.friend.id == userId,
    );
  }

  bool hasPendingSentRequest(String userId) {
    return _sentRequests.any((request) => request.receiver.id == userId);
  }

  bool hasPendingReceivedRequest(String userId) {
    return _receivedRequests.any((request) => request.sender.id == userId);
  }

  ChatConversation? findConversationByUserId(String userId) {
    for (final conversation in _conversations) {
      if (conversation.friend.id == userId) {
        return conversation;
      }
    }
    return null;
  }

  void markUserRelationship(
    String userId, {
    required String relationshipStatus,
    String conversationId = '',
    String requestId = '',
  }) {
    _searchResults = _searchResults.map((user) {
      if (user.id != userId) return user;

      return user.copyWith(
        relationshipStatus: relationshipStatus,
        conversationId: conversationId,
        requestId: requestId,
      );
    }).toList();

    notifyListeners();
  }

  Future<void> refreshRelationshipState() async {
    await loadInbox(forceSearchRefresh: true);
  }

  Future<void> loadInbox({bool forceSearchRefresh = false}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        _chatService.getConversations(),
        _chatService.getFriendRequests(),
        if (forceSearchRefresh || _searchQuery.trim().isNotEmpty)
          _chatService.searchUsers(_searchQuery)
        else
          Future.value(<ChatUser>[]),
      ]);

      _conversations = results[0] as List<ChatConversation>;
      final requestMap = results[1] as Map<String, List<FriendRequestModel>>;
      _receivedRequests = requestMap['received'] ?? [];
      _sentRequests = requestMap['sent'] ?? [];
      await _chatSocketService.syncConversationSubscriptions(
        _conversations.map((conversation) => conversation.id),
      );

      if (forceSearchRefresh || _searchQuery.trim().isNotEmpty) {
        _searchResults = results[2] as List<ChatUser>;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> searchUsers(String query) async {
    _searchQuery = query;
    notifyListeners();

    if (query.trim().isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      _searchResults = await _chatService.searchUsers(query);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<FriendRequestActionResult> sendFriendRequest(String userId) async {
    try {
      final result = await _chatService.sendFriendRequest(userId);
      await loadInbox(forceSearchRefresh: true);
      return result;
    } catch (e) {
      final message = e.toString().toLowerCase();
      if (message.contains('already friends') ||
          message.contains('already sent') ||
          message.contains('already processed') ||
          message.contains('already')) {
        await loadInbox(forceSearchRefresh: true);
      }
      rethrow;
    }
  }

  Future<void> acceptFriendRequest(String requestId) async {
    await _chatService.respondToFriendRequest(requestId, 'accepted');
    await loadInbox(forceSearchRefresh: true);
  }

  Future<void> rejectFriendRequest(String requestId) async {
    await _chatService.respondToFriendRequest(requestId, 'rejected');
    await loadInbox(forceSearchRefresh: true);
  }

  Future<FriendRequestActionResult> removeFriend(String userId) async {
    final result = await _chatService.removeFriend(userId);
    markUserRelationship(
      userId,
      relationshipStatus: result.relationshipStatus,
      conversationId: result.conversationId,
      requestId: result.requestId,
    );
    await loadInbox(forceSearchRefresh: true);
    return result;
  }

  Future<void> openConversation(String conversationId) async {
    _activeConversationId = conversationId;
    _clearTypingUsers(conversationId);
    _isLoading = true;
    notifyListeners();

    try {
      await _chatSocketService.syncConversationSubscriptions(
        {
          ..._conversations.map((conversation) => conversation.id),
          conversationId,
        },
      );
      _messages = await _chatService.getMessages(conversationId);
      await _chatService.markConversationAsSeen(conversationId);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshConversation() async {
    final conversationId = _activeConversationId;
    if (conversationId == null) return;

    _messages = await _chatService.getMessages(conversationId);
    await _chatService.markConversationAsSeen(conversationId);
    notifyListeners();
  }

  Future<void> sendMessage(String conversationId, String content) async {
    _isSendingMessage = true;
    stopTyping(conversationId);
    notifyListeners();

    try {
      final sentMessage = await _chatService.sendMessage(
        conversationId,
        content,
      );
      _upsertMessage(sentMessage);
      _upsertConversationPreview(
        conversationId,
        sentMessage.content,
        sentMessage.createdAt,
      );
      try {
        await loadInbox(forceSearchRefresh: true);
      } catch (_) {
        // The message send already succeeded. Keep the conversation usable even
        // if a secondary inbox refresh fails.
      }
    } finally {
      _isSendingMessage = false;
      notifyListeners();
    }
  }

  Future<void> sendImageMessage(
    String conversationId, {
    required File imageFile,
    String content = '',
  }) async {
    _isSendingMessage = true;
    stopTyping(conversationId);
    notifyListeners();

    try {
      final sentMessage = await _chatService.sendMessage(
        conversationId,
        content,
        imageFile: imageFile,
      );
      _upsertMessage(sentMessage);
      _upsertConversationPreview(
        conversationId,
        sentMessage.content.isNotEmpty ? sentMessage.content : 'Photo',
        sentMessage.createdAt,
      );
      try {
        await loadInbox(forceSearchRefresh: true);
      } catch (_) {}
    } finally {
      _isSendingMessage = false;
      notifyListeners();
    }
  }

  Future<void> updateMessage(
    String conversationId,
    String messageId,
    String content,
  ) async {
    _isUpdatingMessage = true;
    notifyListeners();

    try {
      final updatedMessage = await _chatService.updateMessage(
        conversationId,
        messageId,
        content,
      );
      _upsertMessage(updatedMessage);
      _upsertConversationPreview(
        conversationId,
        updatedMessage.content.isNotEmpty ? updatedMessage.content : 'Photo',
        updatedMessage.createdAt,
      );
      try {
        await loadInbox(forceSearchRefresh: true);
      } catch (_) {}
    } finally {
      _isUpdatingMessage = false;
      notifyListeners();
    }
  }

  Future<void> deleteMessage(String conversationId, String messageId) async {
    await _chatService.deleteMessage(conversationId, messageId);
    _removeMessage(conversationId, messageId);
    try {
      await loadInbox(forceSearchRefresh: true);
    } catch (_) {}
    notifyListeners();
  }

  void _handleIncomingMessage(ChatMessageModel message) {
    _removeTypingUser(message.conversationId, message.sender.id);
    _upsertConversationPreview(
      message.conversationId,
      message.content,
      message.createdAt,
    );

    if (_activeConversationId == message.conversationId) {
      final previousLength = _messages.length;
      _upsertMessage(message);
      _markConversationAsSeen(message.conversationId);
      if (_messages.length != previousLength ||
          _messages.any((item) => item.id == message.id)) {
        notifyListeners();
      }
      return;
    }

    notifyListeners();
  }

  void _handleUpdatedMessage(ChatMessageModel message) {
    _upsertMessage(message);
    _upsertConversationPreview(
      message.conversationId,
      message.content.isNotEmpty ? message.content : 'Photo',
      message.createdAt,
    );
    if (_activeConversationId == message.conversationId) {
      notifyListeners();
    }
  }

  void _handleDeletedMessage(String conversationId, String messageId) {
    final removed = _removeMessage(conversationId, messageId);
    if (removed && _activeConversationId == conversationId) {
      notifyListeners();
    }
  }

  void _handleMessagesSeen(
    String conversationId,
    List<String> messageIds,
    DateTime? seenAt,
  ) {
    final updated = _markMessagesAsSeen(conversationId, messageIds, seenAt);
    if (updated && _activeConversationId == conversationId) {
      notifyListeners();
    }
  }

  void _handleConversationUpdated(
    String conversationId,
    String lastMessage,
    DateTime? lastMessageAt,
  ) {
    _upsertConversationPreview(conversationId, lastMessage, lastMessageAt);
    notifyListeners();
  }

  void startTyping(String conversationId) {
    _chatSocketService.startTyping(conversationId);
  }

  void stopTyping(String conversationId) {
    _chatSocketService.stopTyping(conversationId);
  }

  void _handleTypingChanged(String conversationId, String userId, bool isTyping) {
    final normalizedConversationId = conversationId.trim();
    final normalizedUserId = userId.trim();
    if (normalizedConversationId.isEmpty || normalizedUserId.isEmpty) {
      return;
    }

    final typingUsers = {
      ...(_typingUserIdsByConversation[normalizedConversationId] ?? <String>{}),
    };

    if (isTyping) {
      typingUsers.add(normalizedUserId);
      _typingUserIdsByConversation[normalizedConversationId] = typingUsers;
    } else if (typingUsers.remove(normalizedUserId)) {
      if (typingUsers.isEmpty) {
        _typingUserIdsByConversation.remove(normalizedConversationId);
      } else {
        _typingUserIdsByConversation[normalizedConversationId] = typingUsers;
      }
    } else {
      return;
    }

    if (_activeConversationId == normalizedConversationId) {
      notifyListeners();
    }
  }

  void _removeTypingUser(String conversationId, String userId) {
    final typingUsers = _typingUserIdsByConversation[conversationId];
    if (typingUsers == null || !typingUsers.remove(userId)) {
      return;
    }

    if (typingUsers.isEmpty) {
      _typingUserIdsByConversation.remove(conversationId);
    }
  }

  void _clearTypingUsers(String conversationId) {
    _typingUserIdsByConversation.remove(conversationId);
  }

  Future<void> _markConversationAsSeen(String conversationId) async {
    try {
      await _chatService.markConversationAsSeen(conversationId);
    } catch (_) {}
  }

  void _upsertMessage(ChatMessageModel message) {
    final existingIndex = _messages.indexWhere((item) => item.id == message.id);
    if (existingIndex >= 0) {
      final updatedMessages = [..._messages];
      updatedMessages[existingIndex] = message;
      _messages = updatedMessages;
      return;
    }

    _messages = [..._messages, message]
      ..sort((a, b) {
        final left = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final right = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return left.compareTo(right);
      });
  }

  bool _markMessagesAsSeen(
    String conversationId,
    List<String> messageIds,
    DateTime? seenAt,
  ) {
    if (_activeConversationId != conversationId || messageIds.isEmpty) {
      return false;
    }

    final targetIds = messageIds.toSet();
    var hasChanges = false;
    final updatedMessages = _messages.map((message) {
      if (!targetIds.contains(message.id) || message.isSeen) {
        return message;
      }

      hasChanges = true;
      return message.copyWith(
        isSeen: true,
        seenAt: seenAt ?? message.seenAt,
      );
    }).toList();

    if (!hasChanges) {
      return false;
    }

    _messages = updatedMessages;
    return true;
  }

  bool _removeMessage(String conversationId, String messageId) {
    if (_activeConversationId != conversationId) {
      return false;
    }

    final previousLength = _messages.length;
    _messages = _messages.where((item) => item.id != messageId).toList();
    return _messages.length != previousLength;
  }

  void _upsertConversationPreview(
    String conversationId,
    String content,
    DateTime? timestamp,
  ) {
    final existingIndex = _conversations.indexWhere(
      (conversation) => conversation.id == conversationId,
    );
    if (existingIndex < 0) {
      return;
    }

    final existingConversation = _conversations[existingIndex];
    final updatedConversation = ChatConversation(
      id: existingConversation.id,
      friend: existingConversation.friend,
      lastMessage: content,
      lastMessageAt: timestamp ?? existingConversation.lastMessageAt,
      updatedAt: timestamp ?? existingConversation.updatedAt,
    );

    final updatedConversations = [..._conversations];
    updatedConversations.removeAt(existingIndex);
    updatedConversations.insert(0, updatedConversation);
    _conversations = updatedConversations;
  }

  @override
  void dispose() {
    _chatSocketService.disconnect();
    super.dispose();
  }
}
