import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

import '../models/chat_models.dart';

typedef CallKitActionHandler = Future<void> Function(String callId);

class CallKitService {
  CallKitService._();

  static final CallKitService instance = CallKitService._();

  StreamSubscription<CallEvent?>? _eventSubscription;

  Future<void> initialize() async {
    try {
      await FlutterCallkitIncoming.requestNotificationPermission({
        'title': 'Notification permission',
        'rationaleMessagePermission':
            'Notification permission is required to show incoming calls.',
        'postNotificationMessageRequired':
            'Please allow notification permission from settings.',
      });
    } catch (error) {
      debugPrint('CallKit notification permission request failed: $error');
    }

    try {
      await FlutterCallkitIncoming.requestFullIntentPermission();
    } catch (error) {
      debugPrint('CallKit full-screen permission request failed: $error');
    }
  }

  void configure({
    CallKitActionHandler? onAccept,
    CallKitActionHandler? onDecline,
    CallKitActionHandler? onEnded,
    CallKitActionHandler? onTimeout,
  }) {
    _eventSubscription?.cancel();
    _eventSubscription = FlutterCallkitIncoming.onEvent.listen((event) async {
      if (event == null) {
        return;
      }

      final body = event.body is Map<String, dynamic>
          ? event.body as Map<String, dynamic>
          : Map<String, dynamic>.from(event.body as Map? ?? const {});
      final callId = (body['id'] ?? body['callId'] ?? '').toString().trim();
      if (callId.isEmpty) {
        return;
      }

      try {
        switch (event.event) {
          case Event.actionCallAccept:
            await onAccept?.call(callId);
            break;
          case Event.actionCallDecline:
            await onDecline?.call(callId);
            break;
          case Event.actionCallEnded:
            await onEnded?.call(callId);
            break;
          case Event.actionCallTimeout:
            await onTimeout?.call(callId);
            break;
          default:
            break;
        }
      } catch (error) {
        debugPrint('CallKit event handler failed: $error');
      }
    });
  }

  Future<void> showIncomingCall(ChatCallModel call) {
    final caller = call.initiator;
    return showIncomingCallFromPayload(
      callId: call.id,
      conversationId: call.conversationId,
      callerName: caller.username.isNotEmpty ? caller.username : caller.email,
      callerHandle: caller.email,
      avatar: caller.avatar,
      isVideo: call.isVideo,
    );
  }

  Future<void> showIncomingCallFromPayload({
    required String callId,
    required String conversationId,
    required String callerName,
    required bool isVideo,
    String callerHandle = '',
    String avatar = '',
  }) async {
    final params = CallKitParams(
      id: callId,
      nameCaller: callerName,
      appName: 'Spendwise',
      avatar: avatar.isNotEmpty ? avatar : null,
      handle: callerHandle.isNotEmpty ? callerHandle : callerName,
      type: isVideo ? 1 : 0,
      duration: 30000,
      textAccept: 'Answer',
      textDecline: 'Decline',
      missedCallNotification: const NotificationParams(
        showNotification: true,
        isShowCallback: false,
        subtitle: 'Missed call',
        callbackText: 'Call back',
      ),
      extra: <String, dynamic>{
        'callId': callId,
        'conversationId': conversationId,
        'isVideo': isVideo,
      },
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#111111',
        actionColor: '#22C55E',
        textColor: '#FFFFFF',
        incomingCallNotificationChannelName: 'Incoming Call',
        missedCallNotificationChannelName: 'Missed Call',
        isShowCallID: false,
      ),
      ios: IOSParams(
        iconName: 'AppIcon',
        handleType: 'generic',
        supportsVideo: isVideo,
        maximumCallGroups: 1,
        maximumCallsPerCallGroup: 1,
        audioSessionMode: 'default',
        audioSessionActive: true,
        audioSessionPreferredSampleRate: 44100.0,
        audioSessionPreferredIOBufferDuration: 0.005,
        supportsDTMF: false,
        supportsHolding: false,
        supportsGrouping: false,
        supportsUngrouping: false,
        ringtonePath: 'system_ringtone_default',
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  bool isIncomingCallPayload(Map<String, dynamic> data) {
    final callId = (data['callId'] ?? data['id'] ?? '').toString().trim();
    final conversationId = (data['conversationId'] ?? '').toString().trim();
    final event = (data['event'] ?? data['type'] ?? '').toString().trim();

    return callId.isNotEmpty &&
        (conversationId.isNotEmpty ||
            event == 'incoming_call' ||
            event == 'call:incoming');
  }

  Future<bool> showIncomingCallFromRemoteData(
    Map<String, dynamic> data,
  ) async {
    if (!isIncomingCallPayload(data)) {
      return false;
    }

    await showIncomingCallFromPayload(
      callId: (data['callId'] ?? data['id']).toString(),
      conversationId: (data['conversationId'] ?? '').toString(),
      callerName:
          (data['callerName'] ??
                  data['senderName'] ??
                  data['nameCaller'] ??
                  'Incoming call')
              .toString(),
      callerHandle:
          (data['callerHandle'] ?? data['email'] ?? data['handle'] ?? '')
              .toString(),
      avatar: (data['avatar'] ?? '').toString(),
      isVideo:
          ((data['isVideo'] ?? data['type'])?.toString().toLowerCase() ==
              'video') ||
          (data['isVideo']?.toString().toLowerCase() == 'true'),
    );
    return true;
  }

  Future<void> endCall(String callId) async {
    if (callId.trim().isEmpty) {
      return;
    }
    await FlutterCallkitIncoming.endCall(callId);
  }

  Future<void> setCallConnected(String callId) async {
    if (callId.trim().isEmpty) {
      return;
    }
    await FlutterCallkitIncoming.setCallConnected(callId);
  }

  Future<void> dispose() async {
    await _eventSubscription?.cancel();
    _eventSubscription = null;
  }
}
