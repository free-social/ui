import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'dart:io';
import '../models/chat_models.dart';
import 'api_service.dart';

class ChatService {
  final ApiService _apiService;

  ChatService({ApiService? apiService})
    : _apiService = apiService ?? ApiService();

  Future<List<Map<String, dynamic>>> getRtcIceServers() async {
    try {
      final response = await _apiService.client.get('/chat/rtc/config');
      final servers = response.data['iceServers'] as List<dynamic>? ?? [];
      return servers
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (e) {
      return _handleFetchError<List<Map<String, dynamic>>>(
        e,
        'Failed to fetch RTC config',
        const <Map<String, dynamic>>[],
      );
    }
  }

  Future<List<ChatUser>> searchUsers(String query) async {
    try {
      final normalizedQuery = query.trim();
      final queryParameters = <String, dynamic>{};

      if (normalizedQuery.isNotEmpty) {
        queryParameters['search'] = normalizedQuery;
      }

      final response = await _apiService.client.get(
        '/chat/users',
        queryParameters: queryParameters.isEmpty ? null : queryParameters,
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

  Future<Map<String, List<FriendRequestModel>>> getFriendRequests({
    FriendRequestStatusFilter? status,
  }) async {
    try {
      final response = await _apiService.client.get(
        '/chat/friends/requests',
        queryParameters: status == null ? null : {'status': status.apiValue},
      );

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

  Future<MessagesPage> getMessages(
    String conversationId, {
    int page = 1,
    int limit = 40,
  }) async {
    try {
      final response = await _apiService.client.get(
        '/chat/conversations/$conversationId/messages',
        queryParameters: {'page': page, 'limit': limit},
      );

      final data = response.data as Map<String, dynamic>;
      final messages = (data['messages'] as List<dynamic>? ?? [])
          .map(
            (item) => ChatMessageModel.fromJson(item as Map<String, dynamic>),
          )
          .toList();

      return MessagesPage(
        messages: messages,
        page: (data['page'] as num?)?.toInt() ?? page,
        limit: (data['limit'] as num?)?.toInt() ?? limit,
        total: (data['total'] as num?)?.toInt() ?? messages.length,
        totalPages: (data['totalPages'] as num?)?.toInt() ?? 1,
      );
    } catch (e) {
      return _handleFetchError<MessagesPage>(
        e,
        'Failed to fetch messages',
        MessagesPage(
          messages: const [],
          page: page,
          limit: limit,
          total: 0,
          totalPages: 1,
        ),
      );
    }
  }

  Future<ChatMessageModel> sendMessage(
    String conversationId,
    String content, {
    File? imageFile,
    File? audioFile,
    int? audioDurationSeconds,
    String? replyTo,
  }) async {
    try {
      final attachmentFile = imageFile ?? audioFile;
      final response = await _apiService.client.post(
        '/chat/conversations/$conversationId/messages',
        data: attachmentFile == null
            ? {
                'content': content, 
                if (replyTo != null) 'replyTo': replyTo
              }
            : await _buildMessageFormData(
                content,
                imageFile: imageFile,
                audioFile: audioFile,
                audioDurationSeconds: audioDurationSeconds,
                replyTo: replyTo,
              ),
        options: attachmentFile == null
            ? null
            : Options(contentType: 'multipart/form-data'),
      );

      return ChatMessageModel.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );
    } catch (e) {
      _handleError(e, 'Failed to send message');
      rethrow;
    }
  }

  Future<ChatMessageModel> updateMessage(
    String conversationId,
    String messageId,
    String content,
  ) async {
    try {
      final response = await _apiService.client.patch(
        '/chat/conversations/$conversationId/messages/$messageId',
        data: {'content': content},
      );

      return ChatMessageModel.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );
    } catch (e) {
      _handleError(e, 'Failed to update message');
      rethrow;
    }
  }

  Future<ChatMessageModel> reactToMessage(
    String conversationId,
    String messageId,
    String? reaction,
  ) async {
    try {
      final response = await _apiService.client.patch(
        '/chat/conversations/$conversationId/messages/$messageId/react',
        data: {'reaction': reaction},
      );

      return ChatMessageModel.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );
    } catch (e) {
      _handleError(e, 'Failed to react to message');
      rethrow;
    }
  }

  Future<void> deleteMessage(String conversationId, String messageId) async {
    try {
      await _apiService.client.delete(
        '/chat/conversations/$conversationId/messages/$messageId',
      );
    } catch (e) {
      _handleError(e, 'Failed to delete message');
      rethrow;
    }
  }

  Future<void> markConversationAsSeen(String conversationId) async {
    try {
      await _apiService.client.patch(
        '/chat/conversations/$conversationId/messages/seen',
      );
    } catch (e) {
      final errorMessage = _extractErrorMessage(
        e,
        'Failed to mark messages as seen',
      );
      debugPrint('ChatService fetch warning: $errorMessage');
    }
  }

  Future<ChatCallModel?> getActiveCall(String conversationId) async {
    try {
      final response = await _apiService.client.get(
        '/chat/conversations/$conversationId/calls/active',
      );
      final callData = response.data['call'];
      if (callData is! Map<String, dynamic>) {
        return null;
      }

      return ChatCallModel.fromJson(callData);
    } catch (e) {
      return _handleFetchError<ChatCallModel?>(
        e,
        'Failed to fetch active call',
        null,
      );
    }
  }

  Future<ChatCallModel> startCall(String conversationId, String type) async {
    try {
      final response = await _apiService.client.post(
        '/chat/conversations/$conversationId/calls/active',
        data: {'type': type},
      );

      return ChatCallModel.fromJson(
        response.data['call'] as Map<String, dynamic>,
      );
    } catch (e) {
      _handleError(e, 'Failed to start call');
      rethrow;
    }
  }

  Future<ChatCallModel> respondToCall(String callId, String action) async {
    try {
      final response = await _apiService.client.patch(
        '/chat/calls/$callId/respond',
        data: {'action': action},
      );

      return ChatCallModel.fromJson(
        response.data['call'] as Map<String, dynamic>,
      );
    } catch (e) {
      _handleError(e, 'Failed to respond to call');
      rethrow;
    }
  }

  Future<ChatCallModel> endCall(String callId, String status) async {
    try {
      final response = await _apiService.client.patch(
        '/chat/calls/$callId/end',
        data: {'status': status},
      );

      return ChatCallModel.fromJson(
        response.data['call'] as Map<String, dynamic>,
      );
    } catch (e) {
      _handleError(e, 'Failed to end call');
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

  Future<FormData> _buildMessageFormData(
    String content, {
    File? imageFile,
    File? audioFile,
    int? audioDurationSeconds,
    String? replyTo,
  }) async {
    final file = imageFile ?? audioFile;
    if (file == null) {
      throw ArgumentError('An image or audio file is required');
    }

    final fileName = file.path.split('/').last;
    final isAudio = audioFile != null;

    return FormData.fromMap({
      'content': content,
      if (audioDurationSeconds != null)
        'audioDurationSeconds': audioDurationSeconds.toString(),
      if (replyTo != null) 'replyTo': replyTo,
      isAudio ? 'audio' : 'image': await MultipartFile.fromFile(
        file.path,
        filename: fileName,
        contentType: isAudio
            ? _audioMediaType(fileName)
            : _imageMediaType(fileName),
      ),
    });
  }

  MediaType _imageMediaType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'png':
        return MediaType('image', 'png');
      case 'gif':
        return MediaType('image', 'gif');
      case 'webp':
        return MediaType('image', 'webp');
      default:
        return MediaType('image', 'jpeg');
    }
  }

  MediaType _audioMediaType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'm4a':
        return MediaType('audio', 'x-m4a');
      case 'aac':
        return MediaType('audio', 'aac');
      case 'mp3':
        return MediaType('audio', 'mpeg');
      case 'ogg':
        return MediaType('audio', 'ogg');
      case 'wav':
        return MediaType('audio', 'wav');
      case 'webm':
        return MediaType('audio', 'webm');
      default:
        return MediaType('audio', 'mp4');
    }
  }
}
