import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../models/chat_models.dart';
import '../utils/constants.dart';

class ChatSocketService {
  io.Socket? _socket;
  VoidCallback? _onUnauthorized;
  void Function(ChatMessageModel message)? _onMessage;
  void Function(ChatMessageModel message)? _onMessageUpdated;
  void Function(String conversationId, String messageId)? _onMessageDeleted;
  void Function(
    String conversationId,
    List<String> messageIds,
    DateTime? seenAt,
  )?
  _onMessagesSeen;
  void Function(ChatCallModel call)? _onCallIncoming;
  void Function(ChatCallModel call)? _onCallStatus;
  void Function(ChatCallModel call)? _onCallEnded;
  void Function({
    required String callId,
    required String conversationId,
    required String senderId,
    required String type,
    String? sdp,
    Map<String, dynamic>? candidate,
  })?
  _onCallSignal;
  void Function(
    String conversationId,
    String lastMessage,
    DateTime? lastMessageAt,
  )?
  _onConversationUpdated;
  void Function(String conversationId, String userId, bool isTyping)?
  _onTypingChanged;
  final Set<String> _joinedConversationIds = <String>{};

  void configure({
    required void Function(ChatMessageModel message) onMessage,
    void Function(ChatMessageModel message)? onMessageUpdated,
    void Function(String conversationId, String messageId)? onMessageDeleted,
    void Function(
      String conversationId,
      List<String> messageIds,
      DateTime? seenAt,
    )?
    onMessagesSeen,
    void Function(ChatCallModel call)? onCallIncoming,
    void Function(ChatCallModel call)? onCallStatus,
    void Function(ChatCallModel call)? onCallEnded,
    void Function({
      required String callId,
      required String conversationId,
      required String senderId,
      required String type,
      String? sdp,
      Map<String, dynamic>? candidate,
    })?
    onCallSignal,
    void Function(
      String conversationId,
      String lastMessage,
      DateTime? lastMessageAt,
    )?
    onConversationUpdated,
    void Function(String conversationId, String userId, bool isTyping)?
    onTypingChanged,
    VoidCallback? onUnauthorized,
  }) {
    _onMessage = onMessage;
    _onMessageUpdated = onMessageUpdated;
    _onMessageDeleted = onMessageDeleted;
    _onMessagesSeen = onMessagesSeen;
    _onCallIncoming = onCallIncoming;
    _onCallStatus = onCallStatus;
    _onCallEnded = onCallEnded;
    _onCallSignal = onCallSignal;
    _onConversationUpdated = onConversationUpdated;
    _onTypingChanged = onTypingChanged;
    _onUnauthorized = onUnauthorized;
  }

  Future<void> connect() async {
    if (_socket?.connected == true) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || token.trim().isEmpty) {
      return;
    }

    if (_socket == null) {
      final socket = io.io(ApiConstants.socketUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
        'forceNew': false,
        'auth': {'token': token},
        'extraHeaders': {'Authorization': 'Bearer $token'},
      });

      socket.onConnect((_) {
        for (final conversationId in _joinedConversationIds) {
          socket.emit('chat:join', conversationId);
        }
      });

      socket.on('chat:message', (data) {
        final payload = data is Map
            ? Map<String, dynamic>.from(data)
            : const <String, dynamic>{};
        final messageData = payload['message'];
        if (messageData is! Map) {
          return;
        }

        try {
          _onMessage?.call(
            ChatMessageModel.fromJson(Map<String, dynamic>.from(messageData)),
          );
          _handleConversationUpdate(payload['conversation']);
        } catch (error, stackTrace) {
          debugPrint('Chat socket payload parse failed: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
      });

      socket.on('chat:messageUpdated', (data) {
        final payload = data is Map
            ? Map<String, dynamic>.from(data)
            : const <String, dynamic>{};
        final messageData = payload['message'];
        if (messageData is! Map) {
          return;
        }

        try {
          _onMessageUpdated?.call(
            ChatMessageModel.fromJson(Map<String, dynamic>.from(messageData)),
          );
          _handleConversationUpdate(payload['conversation']);
        } catch (error, stackTrace) {
          debugPrint('Chat socket update payload parse failed: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
      });

      socket.on('chat:messageDeleted', (data) {
        final payload = data is Map
            ? Map<String, dynamic>.from(data)
            : const <String, dynamic>{};
        final conversationId = (payload['conversationId'] ?? '').toString();
        final messageId = (payload['messageId'] ?? '').toString();
        if (conversationId.trim().isEmpty || messageId.trim().isEmpty) {
          return;
        }

        _onMessageDeleted?.call(conversationId.trim(), messageId.trim());
        _handleConversationUpdate(payload['conversation']);
      });

      socket.on('chat:seen', (data) {
        final payload = data is Map
            ? Map<String, dynamic>.from(data)
            : const <String, dynamic>{};
        final conversationId = (payload['conversationId'] ?? '')
            .toString()
            .trim();
        final rawMessageIds = payload['messageIds'];
        if (conversationId.isEmpty) {
          return;
        }

        List<String> messageIds = [];
        if (rawMessageIds is List) {
          messageIds = rawMessageIds
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList();
        }

        _onMessagesSeen?.call(
          conversationId,
          messageIds,
          _parseLocalDateTime(payload['seenAt']),
        );
      });

      void handleCallPayload(
        dynamic data,
        void Function(ChatCallModel call)? callback,
      ) {
        if (callback == null || data is! Map) {
          return;
        }

        try {
          callback(ChatCallModel.fromJson(Map<String, dynamic>.from(data)));
        } catch (error, stackTrace) {
          debugPrint('Chat socket call payload parse failed: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
      }

      socket.on('call:incoming', (data) {
        handleCallPayload(data, _onCallIncoming);
      });
      socket.on('call:status', (data) {
        handleCallPayload(data, _onCallStatus);
      });
      socket.on('call:ended', (data) {
        handleCallPayload(data, _onCallEnded);
      });

      socket.on('call:signal', (data) {
        final payload = data is Map
            ? Map<String, dynamic>.from(data)
            : const <String, dynamic>{};
        final callId = (payload['callId'] ?? '').toString().trim();
        final conversationId = (payload['conversationId'] ?? '')
            .toString()
            .trim();
        final senderId = (payload['senderId'] ?? '').toString().trim();
        final type = (payload['type'] ?? '').toString().trim();
        if (callId.isEmpty ||
            conversationId.isEmpty ||
            senderId.isEmpty ||
            type.isEmpty) {
          return;
        }

        _onCallSignal?.call(
          callId: callId,
          conversationId: conversationId,
          senderId: senderId,
          type: type,
          sdp: payload['sdp']?.toString(),
          candidate: payload['candidate'] is Map
              ? Map<String, dynamic>.from(payload['candidate'] as Map)
              : null,
        );
      });

      void handleTypingEvent(dynamic data, bool isTyping) {
        final payload = data is Map
            ? Map<String, dynamic>.from(data)
            : const <String, dynamic>{};
        final conversationId = (payload['conversationId'] ?? '').toString();
        final userId = (payload['userId'] ?? '').toString();
        if (conversationId.trim().isEmpty || userId.trim().isEmpty) {
          return;
        }

        _onTypingChanged?.call(conversationId.trim(), userId.trim(), isTyping);
      }

      socket.on('chat:typing', (data) => handleTypingEvent(data, true));
      socket.on('chat:stopTyping', (data) => handleTypingEvent(data, false));

      socket.onConnectError((error) {
        final message = error.toString().toLowerCase();
        if (message.contains('unauthorized')) {
          _onUnauthorized?.call();
        }
      });

      socket.onError((error) {
        final message = error.toString().toLowerCase();
        if (message.contains('unauthorized')) {
          _onUnauthorized?.call();
        }
      });

      _socket = socket;
    }

    _socket?.auth = {'token': token};
    _socket?.io.options?['extraHeaders'] = {'Authorization': 'Bearer $token'};
    _socket?.connect();
  }

  Future<void> syncConversationSubscriptions(
    Iterable<String> conversationIds,
  ) async {
    final normalizedIds = conversationIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();

    final idsToLeave = _joinedConversationIds.difference(normalizedIds);
    final idsToJoin = normalizedIds.difference(_joinedConversationIds);

    for (final conversationId in idsToLeave) {
      _socket?.emit('chat:leave', conversationId);
    }

    _joinedConversationIds
      ..clear()
      ..addAll(normalizedIds);

    await connect();

    for (final conversationId in idsToJoin) {
      _socket?.emit('chat:join', conversationId);
    }
  }

  void startTyping(String conversationId) {
    final normalizedConversationId = conversationId.trim();
    if (normalizedConversationId.isEmpty) {
      return;
    }

    _socket?.emit('chat:typing', normalizedConversationId);
  }

  void stopTyping(String conversationId) {
    final normalizedConversationId = conversationId.trim();
    if (normalizedConversationId.isEmpty) {
      return;
    }

    _socket?.emit('chat:stopTyping', normalizedConversationId);
  }

  void sendCallSignal({
    required String callId,
    required String type,
    String? sdp,
    Map<String, dynamic>? candidate,
  }) {
    final normalizedCallId = callId.trim();
    final normalizedType = type.trim();
    if (normalizedCallId.isEmpty || normalizedType.isEmpty) {
      return;
    }

    _socket?.emit('call:signal', <String, dynamic>{
      'callId': normalizedCallId,
      'type': normalizedType,
      if (sdp != null && sdp.isNotEmpty) 'sdp': sdp,
      if (candidate != null) 'candidate': candidate,
    });
  }

  void _handleConversationUpdate(dynamic data) {
    if (data is! Map) {
      return;
    }

    final payload = Map<String, dynamic>.from(data);
    final conversationId = (payload['id'] ?? '').toString().trim();
    if (conversationId.isEmpty) {
      return;
    }

    _onConversationUpdated?.call(
      conversationId,
      (payload['lastMessage'] ?? '').toString(),
      _parseLocalDateTime(payload['lastMessageAt']),
    );
  }

  void disconnect() {
    _joinedConversationIds.clear();
    _socket?.dispose();
    _socket = null;
  }

  DateTime? _parseLocalDateTime(dynamic value) {
    if (value == null) return null;
    final parsed = DateTime.tryParse(value.toString());
    return parsed?.toLocal();
  }
}
