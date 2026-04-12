import 'package:flutter/material.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';

class ChatProvider with ChangeNotifier {
  final ChatService _chatService;

  ChatProvider({ChatService? chatService})
    : _chatService = chatService ?? ChatService();

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
      _messages = [..._messages, sentMessage];
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
}
