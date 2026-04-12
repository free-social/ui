import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../models/chat_models.dart';
import 'api_service.dart';

class ChatService {
  final ApiService _apiService;

  ChatService({ApiService? apiService})
    : _apiService = apiService ?? ApiService();

  Future<List<ChatUser>> searchUsers(String query) async {
    try {
      final response = await _apiService.client.get(
        '/chat/users',
        queryParameters: query.trim().isEmpty ? null : {'search': query.trim()},
      );

      final users = (response.data['users'] as List<dynamic>? ?? [])
          .map((item) => ChatUser.fromJson(item as Map<String, dynamic>))
          .toList();

      return users;
    } catch (e) {
      return _handleFetchError<List<ChatUser>>(e, 'Failed to fetch users', []);
    }
  }

  Future<FriendRequestActionResult> sendFriendRequest(String userId) async {
    try {
      final response = await _apiService.client.post(
        '/chat/friends/requests',
        data: {'userId': userId},
      );
      return FriendRequestActionResult.fromJson(
        response.data as Map<String, dynamic>,
      );
    } catch (e) {
      _handleError(e, 'Failed to send friend request');
      rethrow;
    }
  }

  Future<Map<String, List<FriendRequestModel>>> getFriendRequests() async {
    try {
      final response = await _apiService.client.get('/chat/friends/requests');

      final received = (response.data['received'] as List<dynamic>? ?? [])
          .map(
            (item) => FriendRequestModel.fromJson(item as Map<String, dynamic>),
          )
          .toList();
      final sent = (response.data['sent'] as List<dynamic>? ?? [])
          .map(
            (item) => FriendRequestModel.fromJson(item as Map<String, dynamic>),
          )
          .toList();

      return {'received': received, 'sent': sent};
    } catch (e) {
      return _handleFetchError<Map<String, List<FriendRequestModel>>>(
        e,
        'Failed to fetch friend requests',
        {'received': [], 'sent': []},
      );
    }
  }

  Future<void> respondToFriendRequest(String requestId, String action) async {
    try {
      await _apiService.client.patch(
        '/chat/friends/requests/$requestId',
        data: {'action': action},
      );
    } catch (e) {
      _handleError(e, 'Failed to update friend request');
    }
  }

  Future<List<ChatConversation>> getConversations() async {
    try {
      final response = await _apiService.client.get('/chat/conversations');

      return (response.data['conversations'] as List<dynamic>? ?? [])
          .map(
            (item) => ChatConversation.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      return _handleFetchError<List<ChatConversation>>(
        e,
        'Failed to fetch conversations',
        [],
      );
    }
  }

  Future<FriendRequestActionResult> removeFriend(String userId) async {
    try {
      final response = await _apiService.client.delete('/chat/friends/$userId');
      return FriendRequestActionResult.fromJson(
        response.data as Map<String, dynamic>,
      );
    } catch (e) {
      _handleError(e, 'Failed to remove friend');
      rethrow;
    }
  }

  Future<List<ChatMessageModel>> getMessages(
    String conversationId, {
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final response = await _apiService.client.get(
        '/chat/conversations/$conversationId/messages',
        queryParameters: {'page': page, 'limit': limit},
      );

      return (response.data['messages'] as List<dynamic>? ?? [])
          .map(
            (item) => ChatMessageModel.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      return _handleFetchError<List<ChatMessageModel>>(
        e,
        'Failed to fetch messages',
        [],
      );
    }
  }

  Future<ChatMessageModel> sendMessage(
    String conversationId,
    String content,
  ) async {
    try {
      final response = await _apiService.client.post(
        '/chat/conversations/$conversationId/messages',
        data: {'content': content},
      );

      return ChatMessageModel.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );
    } catch (e) {
      _handleError(e, 'Failed to send message');
      rethrow;
    }
  }

  void _handleError(dynamic e, String defaultMessage) {
    throw Exception(_extractErrorMessage(e, defaultMessage));
  }

  T _handleFetchError<T>(dynamic e, String defaultMessage, T fallbackValue) {
    final errorMessage = _extractErrorMessage(e, defaultMessage);
    // Keep fetch-based screens resilient instead of turning refresh issues
    // into hard failures after the primary user action already succeeded.
    debugPrint('ChatService fetch warning: $errorMessage');
    return fallbackValue;
  }

  String _extractErrorMessage(dynamic e, String defaultMessage) {
    String errorMessage = defaultMessage;
    if (e is DioException) {
      if (e.response?.data != null) {
        final responseData = e.response!.data;
        if (responseData is Map && responseData.containsKey('error')) {
          errorMessage = responseData['error'].toString();
        }
      } else if (e.message != null && e.message!.trim().isNotEmpty) {
        errorMessage = e.message!;
      }
    }
    return errorMessage;
  }
}
