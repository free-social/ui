import 'package:flutter/material.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';
import '../services/chat_socket_service.dart';

class ChatProvider with ChangeNotifier {
  final ChatService _chatService;
  final ChatSocketService _chatSocketService;

  ChatProvider({ChatService? chatService, ChatSocketService? chatSocketService})
    : _chatService = chatService ?? ChatService(),
      _chatSocketService = chatSocketService ?? ChatSocketService() {
    _chatSocketService.configure(onMessage: _handleIncomingMessage);
  }

  bool _isLoading = false;
  bool _isSendingMessage = false;
  String _searchQuery = '';
  String? _activeConversationId;

  List<ChatUser> _searchResults = [];
  List<FriendRequestModel> _receivedRequests = [];
  List<FriendRequestModel> _sentRequests = [];
  List<ChatConversation> _conversations = [];
  List<ChatMessageModel> _messages = [];

  bool get isLoading => _isLoading;
  bool get isSendingMessage => _isSendingMessage;
  String get searchQuery => _searchQuery;
  List<ChatUser> get searchResults => _searchResults;
  List<FriendRequestModel> get receivedRequests => _receivedRequests;
  List<FriendRequestModel> get sentRequests => _sentRequests;
  List<ChatConversation> get conversations => _conversations;
  List<ChatMessageModel> get messages => _messages;

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
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshConversation() async {
    final conversationId = _activeConversationId;
    if (conversationId == null) return;

    _messages = await _chatService.getMessages(conversationId);
    notifyListeners();
  }

  Future<void> sendMessage(String conversationId, String content) async {
    _isSendingMessage = true;
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

  void _handleIncomingMessage(ChatMessageModel message) {
    _upsertConversationPreview(
      message.conversationId,
      message.content,
      message.createdAt,
    );

    if (_activeConversationId == message.conversationId) {
      final previousLength = _messages.length;
      _upsertMessage(message);
      if (_messages.length != previousLength ||
          _messages.any((item) => item.id == message.id)) {
        notifyListeners();
      }
      return;
    }

    notifyListeners();
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
