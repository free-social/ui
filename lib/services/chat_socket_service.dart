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
  final Set<String> _joinedConversationIds = <String>{};

  void configure({
    required void Function(ChatMessageModel message) onMessage,
    VoidCallback? onUnauthorized,
  }) {
    _onMessage = onMessage;
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
      final socket = io.io(
        ApiConstants.socketUrl,
        <String, dynamic>{
          'transports': ['websocket'],
          'autoConnect': false,
          'forceNew': false,
          'auth': {'token': token},
          'extraHeaders': {'Authorization': 'Bearer $token'},
        },
      );

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
        } catch (error, stackTrace) {
          debugPrint('Chat socket payload parse failed: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
      });

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

  Future<void> syncConversationSubscriptions(Iterable<String> conversationIds) async {
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

  void disconnect() {
    _joinedConversationIds.clear();
    _socket?.dispose();
    _socket = null;
  }
}
