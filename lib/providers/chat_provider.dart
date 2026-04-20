import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/navigation/app_navigator.dart';
import '../models/chat_models.dart';
import '../services/call_sound_service.dart';
import '../services/callkit_service.dart';
import '../services/chat_service.dart';
import '../services/chat_socket_service.dart';
import '../services/chat_webrtc_service.dart';
import '../widgets/chat/incoming_call_popup.dart';

class ChatProvider with ChangeNotifier {
  final ChatService _chatService;
  final ChatSocketService _chatSocketService;
  final ChatWebRtcService _chatWebRtcService;
  final CallKitService _callKitService;

  ChatProvider({
    ChatService? chatService,
    ChatSocketService? chatSocketService,
    ChatWebRtcService? chatWebRtcService,
    CallKitService? callKitService,
  }) : _chatService = chatService ?? ChatService(),
       _chatSocketService = chatSocketService ?? ChatSocketService(),
       _chatWebRtcService = chatWebRtcService ?? ChatWebRtcService(),
       _callKitService = callKitService ?? CallKitService.instance {
    _chatSocketService.configure(
      onMessage: _handleIncomingMessage,
      onMessageUpdated: _handleUpdatedMessage,
      onMessageDeleted: _handleDeletedMessage,
      onMessagesSeen: _handleMessagesSeen,
      onCallIncoming: _handleIncomingCall,
      onCallStatus: _handleCallStatus,
      onCallEnded: _handleCallEnded,
      onCallSignal: _handleCallSignal,
      onConversationUpdated: _handleConversationUpdated,
      onTypingChanged: _handleTypingChanged,
    );
    _callKitService.configure(
      onAccept: _handleNativeCallAccept,
      onDecline: _handleNativeCallDecline,
      onEnded: _handleNativeCallEnd,
      onTimeout: _handleNativeCallTimeout,
    );
    unawaited(_bootstrapIfNeeded());
  }

  bool _isLoading = false;
  bool _isSendingMessage = false;
  bool _isUpdatingMessage = false;
  bool _isCallLoading = false;
  bool _isBootstrapping = false;
  bool _isSessionReady = false;
  bool _isMicEnabled = true;
  bool _isCameraEnabled = true;
  bool _hasRemoteVideo = false;
  bool _callRouteVisible = false;
  bool _incomingCallDialogVisible = false;
  bool _renderersReady = false;
  String _searchQuery = '';
  String _currentUserId = '';
  String? _activeConversationId;
  String? _lastNegotiatedCallId;
  String? _lastEndedCallId; // tracks last locally-torn-down call to ignore stale incoming events
  FriendRequestStatusFilter _requestStatusFilter =
      FriendRequestStatusFilter.pending;
  Timer? _ringingTimer;
  Timer? _callDurationTimer;
  int _callDurationSeconds = 0;
  Completer<void>? _signalLock;
  final Map<String, Set<String>> _typingUserIdsByConversation = {};

  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  List<ChatUser> _searchResults = [];
  List<FriendRequestModel> _receivedRequests = [];
  List<FriendRequestModel> _sentRequests = [];
  List<FriendRequestModel> _pendingReceivedRequests = [];
  List<FriendRequestModel> _pendingSentRequests = [];
  List<ChatConversation> _conversations = [];
  List<ChatMessageModel> _messages = [];
  ChatCallModel? _activeCall;
  // In-memory message cache: conversationId → last known message list.
  // Enables stale-while-revalidate so the chat opens instantly.
  final Map<String, List<ChatMessageModel>> _messageCache = {};

  bool get isLoading => _isLoading;
  bool get isSendingMessage => _isSendingMessage;
  bool get isUpdatingMessage => _isUpdatingMessage;
  bool get isCallLoading => _isCallLoading;
  bool get isMicEnabled => _isMicEnabled;
  bool get isCameraEnabled => _isCameraEnabled;
  bool get hasRemoteVideo => _hasRemoteVideo;
  String get searchQuery => _searchQuery;
  String get currentUserId => _currentUserId;
  FriendRequestStatusFilter get requestStatusFilter => _requestStatusFilter;
  List<ChatUser> get searchResults => _searchResults;
  List<FriendRequestModel> get receivedRequests => _receivedRequests;
  List<FriendRequestModel> get sentRequests => _sentRequests;
  List<ChatConversation> get conversations => _conversations;
  List<ChatMessageModel> get messages => _messages;
  ChatCallModel? get activeCall => _activeCall;
  RTCVideoRenderer get localRenderer => _localRenderer;
  RTCVideoRenderer get remoteRenderer => _remoteRenderer;
  bool get hasActiveCall => _activeCall != null;
  bool get isActiveConversationTyping {
    final conversationId = _activeConversationId;
    if (conversationId == null) {
      return false;
    }

    return (_typingUserIdsByConversation[conversationId] ?? const <String>{})
        .isNotEmpty;
  }

  ChatCallParticipant? get activeCallPeer {
    final call = _activeCall;
    if (call == null || _currentUserId.isEmpty) {
      return null;
    }

    return call.initiator.id == _currentUserId
        ? call.recipient
        : call.initiator;
  }

  String get callDurationLabel {
    final hours = _callDurationSeconds ~/ 3600;
    final minutes = (_callDurationSeconds % 3600) ~/ 60;
    final seconds = _callDurationSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  String get activeCallStatusLabel {
    final call = _activeCall;
    if (call == null) {
      return '';
    }

    switch (call.status) {
      case 'ringing':
        return call.initiator.id == _currentUserId
            ? 'Calling...'
            : 'Incoming call';
      case 'accepted':
        return _callDurationSeconds > 0 ? callDurationLabel : 'Connecting...';
      case 'rejected':
        return 'Declined';
      case 'cancelled':
        return 'Cancelled';
      case 'missed':
        return 'Missed';
      case 'failed':
        return 'Call failed';
      case 'ended':
        return 'Call ended';
      default:
        return call.status;
    }
  }

  Future<void> syncAuthState(bool isAuthenticated) async {
    if (isAuthenticated) {
      await _bootstrapIfNeeded(forceReconnect: !_isSessionReady);
      return;
    }

    _isSessionReady = false;
    _currentUserId = ''; // reset so _ensureCurrentUserId re-reads on next login
    _activeConversationId = null;
    _searchResults = [];
    _receivedRequests = [];
    _sentRequests = [];
    _pendingReceivedRequests = [];
    _pendingSentRequests = [];
    _conversations = [];
    _messages = [];
    _messageCache.clear(); // clear per-account cache on logout
    await _resetCallState();
    _chatSocketService.disconnect();
    notifyListeners();
  }

  bool isFriend(String userId) {
    return _conversations.any(
      (conversation) => conversation.friend.id == userId,
    );
  }

  bool hasPendingSentRequest(String userId) {
    return _pendingSentRequests.any((request) => request.receiver.id == userId);
  }

  bool hasPendingReceivedRequest(String userId) {
    return _pendingReceivedRequests.any(
      (request) => request.sender.id == userId,
    );
  }

  ChatConversation? findConversationByUserId(String userId) {
    for (final conversation in _conversations) {
      if (conversation.friend.id == userId) {
        return conversation;
      }
    }
    return null;
  }

  String findPendingReceivedRequestId(String userId) {
    for (final request in _pendingReceivedRequests) {
      if (request.sender.id == userId) {
        return request.id;
      }
    }
    return '';
  }

  void markUserRelationship(
    String userId, {
    required String relationshipStatus,
    String conversationId = '',
    String requestId = '',
  }) {
    _searchResults = _searchResults.map((user) {
      if (user.id != userId) {
        return user;
      }

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

  Future<void> setRequestStatusFilter(
    FriendRequestStatusFilter status, {
    bool forceSearchRefresh = false,
  }) async {
    if (_requestStatusFilter == status && !forceSearchRefresh) {
      return;
    }

    await loadInbox(
      forceSearchRefresh: forceSearchRefresh,
      requestStatus: status,
    );
  }

  Future<void> loadInbox({
    bool forceSearchRefresh = false,
    FriendRequestStatusFilter? requestStatus,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final activeRequestStatus = requestStatus ?? _requestStatusFilter;
      _requestStatusFilter = activeRequestStatus;

      final results = await Future.wait<dynamic>([
        _chatService.getConversations(),
        _chatService.getFriendRequests(status: activeRequestStatus),
        if (activeRequestStatus != FriendRequestStatusFilter.pending)
          _chatService.getFriendRequests(
            status: FriendRequestStatusFilter.pending,
          ),
        if (forceSearchRefresh || _searchQuery.trim().isNotEmpty)
          _chatService.searchUsers(_searchQuery)
        else
          Future.value(<ChatUser>[]),
      ]);

      _conversations = results[0] as List<ChatConversation>;
      final requestMap = results[1] as Map<String, List<FriendRequestModel>>;
      _receivedRequests = requestMap['received'] ?? [];
      _sentRequests = requestMap['sent'] ?? [];

      final pendingRequestMap =
          activeRequestStatus == FriendRequestStatusFilter.pending
          ? requestMap
          : results[2] as Map<String, List<FriendRequestModel>>;
      _pendingReceivedRequests = pendingRequestMap['received'] ?? [];
      _pendingSentRequests = pendingRequestMap['sent'] ?? [];

      await _chatSocketService.syncConversationSubscriptions(
        _conversations.map((conversation) => conversation.id),
      );

      if (forceSearchRefresh || _searchQuery.trim().isNotEmpty) {
        _searchResults = results.last as List<ChatUser>;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, List<FriendRequestModel>>> getFriendRequestsByStatus(
    FriendRequestStatusFilter status,
  ) {
    return _chatService.getFriendRequests(status: status);
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
    try {
      await _chatService.respondToFriendRequest(requestId, 'accepted');
    } catch (e) {
      if (!_isAlreadyHandledFriendRequestError(e)) {
        rethrow;
      }
    }
    await loadInbox(forceSearchRefresh: true);
  }

  Future<void> rejectFriendRequest(String requestId) async {
    try {
      await _chatService.respondToFriendRequest(requestId, 'rejected');
    } catch (e) {
      if (!_isAlreadyHandledFriendRequestError(e)) {
        rethrow;
      }
    }
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

    // ── Stale-while-revalidate ────────────────────────────────────────────
    // 1. Immediately serve cached messages so the list renders at once
    //    (no spinner, no blank screen, no visible scroll jump).
    final cached = _messageCache[conversationId];
    if (cached != null && cached.isNotEmpty) {
      _messages = cached;
      notifyListeners(); // render instantly from cache
    } else {
      // No cache yet — show the loading indicator as usual.
      _isLoading = true;
      notifyListeners();
    }

    try {
      await _chatSocketService.syncConversationSubscriptions({
        ..._conversations.map((conversation) => conversation.id),
        conversationId,
      });

      // Fetch fresh messages in the background (silent if cache was available).
      final freshMessages = await _chatService.getMessages(conversationId);

      // Preserve any isSeen=true that arrived via socket BEFORE the API
      // response returned (the API may still return isSeen:false for those).
      final seenById = <String, bool>{};
      for (final m in _messages) {
        if (m.isSeen) seenById[m.id] = true;
      }
      _messages = freshMessages.map((m) {
        if (!m.isSeen && seenById[m.id] == true) {
          return m.copyWith(isSeen: true);
        }
        return m;
      }).toList();
      _messageCache[conversationId] = _messages; // update cache

      await _chatService.markConversationAsSeen(conversationId);
      final activeCall = await _chatService.getActiveCall(conversationId);
      if (activeCall != null &&
          (_activeCall == null || _activeCall!.id == activeCall.id)) {
        _activeCall = activeCall;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshConversation() async {
    final conversationId = _activeConversationId;
    if (conversationId == null) {
      return;
    }

    _messages = await _chatService.getMessages(conversationId);
    _messageCache[conversationId] = _messages; // keep cache in sync
    await _chatService.markConversationAsSeen(conversationId);
    notifyListeners();
  }

  Future<void> sendMessage(String conversationId, String content, {String? replyTo}) async {
    _isSendingMessage = true;
    stopTyping(conversationId);
    notifyListeners();

    try {
      final sentMessage = await _chatService.sendMessage(
        conversationId,
        content,
        replyTo: replyTo,
      );
      _upsertMessage(sentMessage);
      _upsertConversationPreview(
        conversationId,
        sentMessage.content,
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

  Future<void> sendImageMessage(
    String conversationId, {
    required File imageFile,
    String content = '',
    String? replyTo,
  }) async {
    _isSendingMessage = true;
    stopTyping(conversationId);
    notifyListeners();

    try {
      final sentMessage = await _chatService.sendMessage(
        conversationId,
        content,
        imageFile: imageFile,
        replyTo: replyTo,
      );
      _upsertMessage(sentMessage);
      _upsertConversationPreview(
        conversationId,
        _messagePreview(sentMessage),
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

  Future<void> sendVoiceMessage(
    String conversationId, {
    required File audioFile,
    required int durationSeconds,
    String content = '',
    String? replyTo,
  }) async {
    _isSendingMessage = true;
    stopTyping(conversationId);
    notifyListeners();

    try {
      final sentMessage = await _chatService.sendMessage(
        conversationId,
        content,
        audioFile: audioFile,
        audioDurationSeconds: durationSeconds,
        replyTo: replyTo,
      );
      _upsertMessage(sentMessage);
      _upsertConversationPreview(
        conversationId,
        _messagePreview(sentMessage),
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

  Future<void> reactToMessage(
    String conversationId,
    String messageId,
    String? reaction,
  ) async {
    try {
      final updatedMessage = await _chatService.reactToMessage(
        conversationId,
        messageId,
        reaction,
      );
      _upsertMessage(updatedMessage);
      if (_activeConversationId == conversationId) {
        notifyListeners();
      }
    } catch (_) {}
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
        _messagePreview(updatedMessage),
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

  Future<void> startOutgoingCall(
    String conversationId, {
    required String type,
  }) async {
    if (_isCallLoading) {
      return;
    }

    _isCallLoading = true;
    notifyListeners();

    try {
      await _ensureCurrentUserId();
      await _ensureRenderersReady();

      final existingActiveCall = await _chatService.getActiveCall(conversationId);
      if (existingActiveCall != null) {
        _activeCall = existingActiveCall;
        _lastNegotiatedCallId = null;
        _hasRemoteVideo = false;
        _isMicEnabled = true;
        _isCameraEnabled = existingActiveCall.isVideo;

        if (existingActiveCall.status == 'ringing') {
          await _prepareLocalMedia(existingActiveCall);
          await CallSoundService.instance.startRingtone();
          _startRingingTimeout();
        } else {
          await CallSoundService.instance.stopRingtone();
          _cancelRingingTimeout();
          await _prepareLocalMedia(existingActiveCall);
          if (existingActiveCall.initiator.id == _currentUserId) {
            await _startNegotiationAsCaller(existingActiveCall);
          }
        }

        await _openCallScreen();
        return;
      }

      final call = await _chatService.startCall(conversationId, type);
      _activeCall = call;
      _lastNegotiatedCallId = null;
      _hasRemoteVideo = false;
      _isMicEnabled = true;
      _isCameraEnabled = call.isVideo;

      // Prepare media + start ringtone BEFORE opening the screen.
      // _openCallScreen awaits pushNamed which only resolves when the route
      // is POPPED — anything after it runs after the call has already ended.
      await _prepareLocalMedia(call);
      await CallSoundService.instance.startRingtone();
      _startRingingTimeout();

      await _openCallScreen();
    } finally {
      _isCallLoading = false;
      notifyListeners();
    }
  }

  Future<void> acceptIncomingCall() async {
    final call = _activeCall;
    if (call == null) {
      return;
    }

    _cancelRingingTimeout();
    _isCallLoading = true;
    notifyListeners();

    try {
      await _ensureRenderersReady();
      final updatedCall = await _chatService.respondToCall(call.id, 'accepted');
      _activeCall = updatedCall;
      _isMicEnabled = true;
      _isCameraEnabled = updatedCall.isVideo;
      _hasRemoteVideo = false;

      await _callKitService.setCallConnected(updatedCall.id);
      await CallSoundService.instance.stopRingtone();
      await _prepareLocalMedia(updatedCall);
      // Peer connection is created when the caller's offer arrives
      // in _processCallSignal — creating it here too early causes
      // a race condition with mismatched transceivers.
      await _openCallScreen();
    } finally {
      _isCallLoading = false;
      notifyListeners();
    }
  }

  Future<void> rejectIncomingCall() async {
    final call = _activeCall;
    if (call == null) {
      return;
    }

    _isCallLoading = true;
    notifyListeners();

    try {
      await _callKitService.endCall(call.id);
      await CallSoundService.instance.stopRingtone();
      await CallSoundService.instance.playEndCall();
      await _chatService.respondToCall(call.id, 'rejected');
      await _resetCallState();
    } finally {
      _isCallLoading = false;
      notifyListeners();
    }
  }

  Future<void> endCurrentCall({String? forcedStatus}) async {
    final call = _activeCall;
    if (call == null) {
      return;
    }

    final status =
        forcedStatus ??
        (call.status == 'ringing'
            ? (call.initiator.id == _currentUserId ? 'cancelled' : 'missed')
            : 'ended');

    _isCallLoading = true;
    notifyListeners();

    try {
      await CallSoundService.instance.stopRingtone();
      await _callKitService.endCall(call.id);
      await _chatService.endCall(call.id, status);
    } catch (_) {
      // Still tear down local state if the call already ended remotely.
    } finally {
      await CallSoundService.instance.playEndCall();
      await _resetCallState();
      _isCallLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleMicrophone() async {
    _isMicEnabled = !_isMicEnabled;
    await _chatWebRtcService.setMicrophoneEnabled(_isMicEnabled);
    notifyListeners();
  }

  Future<void> toggleCamera() async {
    if (_activeCall == null || !_activeCall!.isVideo) {
      return;
    }

    _isCameraEnabled = !_isCameraEnabled;
    await _chatWebRtcService.setCameraEnabled(_isCameraEnabled);
    notifyListeners();
  }

  Future<void> switchCamera() async {
    if (_activeCall == null || !_activeCall!.isVideo) {
      return;
    }

    await _chatWebRtcService.switchCamera();
  }

  void startTyping(String conversationId) {
    _chatSocketService.startTyping(conversationId);
  }

  void stopTyping(String conversationId) {
    _chatSocketService.stopTyping(conversationId);
  }

  Future<void> _bootstrapIfNeeded({bool forceReconnect = false}) async {
    if (_isBootstrapping) {
      return;
    }

    if (_isSessionReady && !forceReconnect) {
      return;
    }

    _isBootstrapping = true;
    if (forceReconnect) {
      _chatSocketService.disconnect();
    }

    try {
      await _ensureCurrentUserId();
      if (_currentUserId.isEmpty) {
        return;
      }

      await _ensureRenderersReady();
      final iceServers = await _chatService.getRtcIceServers();
      _chatWebRtcService.configureIceServers(iceServers);
      await _chatSocketService.connect();
      _isSessionReady = true;
      try {
        await loadInbox();
      } catch (_) {
        // Keep global call signaling alive even if inbox prefetch fails.
      }
    } finally {
      _isBootstrapping = false;
    }
  }

  Future<void> _ensureCurrentUserId() async {
    if (_currentUserId.isNotEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    // Only update if the stored value is non-empty — prevents wiping
    // _currentUserId back to '' during the brief logout→login window.
    final stored = prefs.getString('userId')?.trim() ?? '';
    if (stored.isNotEmpty) {
      _currentUserId = stored;
    }
  }

  Future<void> _ensureRenderersReady() async {
    if (_renderersReady) {
      return;
    }

    await _chatWebRtcService.initializeRenderers(
      _localRenderer,
      _remoteRenderer,
    );
    _renderersReady = true;
  }

  Future<void> _prepareLocalMedia(ChatCallModel call) async {
    await _chatWebRtcService.openLocalMedia(
      videoEnabled: call.isVideo,
      localRenderer: _localRenderer,
    );
  }

  Future<void> _ensurePeerConnection() async {
    await _chatWebRtcService.createPeerConnection(
      remoteRenderer: _remoteRenderer,
      onIceCandidate: (candidate) {
        final call = _activeCall;
        if (call == null) {
          return;
        }

        _chatSocketService.sendCallSignal(
          callId: call.id,
          type: 'ice-candidate',
          candidate: <String, dynamic>{
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
        );
      },
      onRemoteStream: (hasVideo) {
        _hasRemoteVideo = hasVideo;
        _startCallDurationTimer();
        notifyListeners();
      },
    );
  }

  Future<void> _startNegotiationAsCaller(ChatCallModel call) async {
    if (_lastNegotiatedCallId == call.id) {
      return;
    }

    _lastNegotiatedCallId = call.id;
    await _prepareLocalMedia(call);
    await _ensurePeerConnection();

    final offer = await _chatWebRtcService.createOffer();
    _chatSocketService.sendCallSignal(
      callId: call.id,
      type: 'offer',
      sdp: offer.sdp,
    );
  }

  Future<void> _handleIncomingCall(ChatCallModel call) async {
    await _ensureCurrentUserId();
    if (call.recipient.id != _currentUserId) {
      return;
    }

    // Ignore a duplicate call:incoming that arrives after we already
    // tore down this call (server emits to both userRoom AND
    // conversationRoom so the client can receive two deliveries).
    if (call.id == _lastEndedCallId) {
      debugPrint('[Call] _handleIncomingCall ignored — call ${call.id} already ended locally');
      return;
    }

    if (_activeCall != null && _activeCall!.id != call.id) {
      return;
    }

    debugPrint('[Call] _handleIncomingCall: id=${call.id}');
    _activeCall = call;
    _lastNegotiatedCallId = null;
    notifyListeners();
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      await _callKitService.showIncomingCall(call);
      _startRingingTimeout();
      return;
    }
    await CallSoundService.instance.startRingtone();
    _startRingingTimeout();
    await _showIncomingCallDialog(call);
  }

  Future<void> _handleCallStatus(ChatCallModel call) async {
    await _ensureCurrentUserId();
    // Ignore updates for calls we've already torn down locally.
    if (_activeCall == null || _activeCall!.id != call.id) {
      return;
    }
    if (!_isParticipantInCall(call)) {
      return;
    }

    _activeCall = call;
    _cancelRingingTimeout();
    notifyListeners();

    if (call.status == 'accepted' && call.initiator.id == _currentUserId) {
      await _callKitService.setCallConnected(call.id);
      await CallSoundService.instance.stopRingtone();
      await _startNegotiationAsCaller(call);
      await _openCallScreen();
      notifyListeners();
      return;
    }

    if (call.status == 'rejected') {
      debugPrint('[Call] _handleCallStatus: rejected, tearing down');
      _isCallLoading = true;
      try {
        await _callKitService.endCall(call.id);
        await CallSoundService.instance.stopRingtone();
        await CallSoundService.instance.playEndCall();
        await _resetCallState();
      } finally {
        _isCallLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> _handleCallEnded(ChatCallModel call) async {
    await _ensureCurrentUserId();
    // Ignore if we've already torn down this call locally.
    if (_activeCall == null || _activeCall!.id != call.id) {
      debugPrint('[Call] _handleCallEnded ignored — activeCall=${_activeCall?.id}, incoming=${call.id}');
      return;
    }
    if (!_isParticipantInCall(call)) {
      return;
    }

    debugPrint('[Call] _handleCallEnded: tearing down call ${call.id}');
    // Set _isCallLoading so that the actionCallEnded native event that
    // _callKitService.endCall() triggers does NOT re-enter endCurrentCall.
    _isCallLoading = true;
    try {
      await _callKitService.endCall(call.id);
      await CallSoundService.instance.stopRingtone();
      await CallSoundService.instance.playEndCall();
      await _resetCallState();
    } finally {
      _isCallLoading = false;
      notifyListeners();
    }
  }

  Future<void> _handleCallSignal({
    required String callId,
    required String conversationId,
    required String senderId,
    required String type,
    String? sdp,
    Map<String, dynamic>? candidate,
  }) async {
    // Serialize signal processing to avoid race conditions when multiple
    // signals (offer + ICE candidates) arrive almost simultaneously.
    while (_signalLock != null) {
      await _signalLock!.future;
    }
    _signalLock = Completer<void>();

    try {
      await _processCallSignal(
        callId: callId,
        conversationId: conversationId,
        senderId: senderId,
        type: type,
        sdp: sdp,
        candidate: candidate,
      );
    } finally {
      final lock = _signalLock;
      _signalLock = null;
      lock?.complete();
    }
  }

  Future<void> _processCallSignal({
    required String callId,
    required String conversationId,
    required String senderId,
    required String type,
    String? sdp,
    Map<String, dynamic>? candidate,
  }) async {
    final call = _activeCall;
    if (call == null || call.id != callId) {
      return;
    }

    await _ensureRenderersReady();

    switch (type) {
      case 'offer':
        await _prepareLocalMedia(call);
        await _ensurePeerConnection();
        if (sdp == null || sdp.isEmpty) {
          return;
        }
        await _chatWebRtcService.setRemoteDescription(sdp: sdp, type: 'offer');
        final answer = await _chatWebRtcService.createAnswer();
        _chatSocketService.sendCallSignal(
          callId: callId,
          type: 'answer',
          sdp: answer.sdp,
        );
        await _openCallScreen();
        notifyListeners();
        return;
      case 'answer':
        if (sdp == null || sdp.isEmpty) {
          return;
        }
        await _chatWebRtcService.setRemoteDescription(sdp: sdp, type: 'answer');
        notifyListeners();
        return;
      case 'ice-candidate':
        if (candidate == null) {
          return;
        }
        await _chatWebRtcService.addRemoteCandidate(candidate);
        return;
      default:
        return;
    }
  }

  Future<void> _showIncomingCallDialog(ChatCallModel call) async {
    if (_incomingCallDialogVisible) {
      return;
    }

    final context = navigatorKey.currentContext;
    if (context == null) {
      return;
    }

    _incomingCallDialogVisible = true;
    final caller = call.initiator.username.isNotEmpty
        ? call.initiator.username
        : call.initiator.email;
    final subtitle = call.isVideo ? 'Incoming video call' : 'Incoming audio call';

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Incoming call',
      barrierColor: Colors.black38,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return IncomingCallPopup(
          callerName: caller,
          callerSubtitle: subtitle,
          avatarUrl: call.initiator.avatar,
          onDecline: () async {
            Navigator.of(dialogContext).pop();
            await rejectIncomingCall();
          },
          onAccept: () async {
            Navigator.of(dialogContext).pop();
            await acceptIncomingCall();
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween<double>(
              begin: 0.96,
              end: 1,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
            child: child,
          ),
        );
      },
    );

    _incomingCallDialogVisible = false;
  }

  Future<void> _handleNativeCallAccept(String callId) async {
    final activeCall = _activeCall;
    if (activeCall != null && activeCall.id == callId) {
      await acceptIncomingCall();
      return;
    }

    await _ensureRenderersReady();
    final updatedCall = await _chatService.respondToCall(callId, 'accepted');
    _activeCall = updatedCall;
    _isMicEnabled = true;
    _isCameraEnabled = updatedCall.isVideo;
    _hasRemoteVideo = false;
    await _callKitService.setCallConnected(updatedCall.id);
    await CallSoundService.instance.stopRingtone();
    await _prepareLocalMedia(updatedCall);
    await _openCallScreen();
    notifyListeners();
  }

  Future<void> _handleNativeCallDecline(String callId) async {
    // If we're already tearing down (rejectIncomingCall/endCurrentCall is in
    // progress), this event was triggered by our own _callKitService.endCall
    // call — ignore it to avoid re-entrant teardown.
    if (_isCallLoading) {
      return;
    }

    final activeCall = _activeCall;
    if (activeCall != null && activeCall.id == callId) {
      await rejectIncomingCall();
      return;
    }

    await _chatService.respondToCall(callId, 'rejected');
    await _callKitService.endCall(callId);
  }

  Future<void> _handleNativeCallEnd(String callId) async {
    await CallSoundService.instance.stopRingtone();

    // If endCurrentCall is already running it called _callKitService.endCall
    // which echoes this native event back — don't re-enter it.
    if (_isCallLoading) {
      return;
    }

    final activeCall = _activeCall;
    if (activeCall == null || activeCall.id != callId) {
      return;
    }

    await endCurrentCall();
  }

  Future<void> _handleNativeCallTimeout(String callId) async {
    await _ensureCurrentUserId();
    final activeCall = _activeCall;
    if (activeCall != null && activeCall.id == callId) {
      final status = activeCall.initiator.id == _currentUserId
          ? 'cancelled'
          : 'missed';
      await endCurrentCall(forcedStatus: status);
      return;
    }

    // Without the active call payload we cannot safely infer whether the
    // current user is the caller or recipient, so avoid sending an invalid
    // terminal status that would leave the server call active.
  }

  Future<void> _openCallScreen() async {
    if (_callRouteVisible) {
      return;
    }

    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      return;
    }

    _callRouteVisible = true;
    try {
      await navigator.pushNamed('/chat-call');
    } catch (e, st) {
      debugPrint('[Call] _openCallScreen Error: $e\n$st');
    } finally {
      _callRouteVisible = false;
    }
  }

  Future<void> _resetCallState() async {
    _cancelRingingTimeout();
    _stopCallDurationTimer();
    await CallSoundService.instance.stopRingtone();
    _lastEndedCallId = _activeCall?.id; // remember this call so stale events are ignored
    _lastNegotiatedCallId = null;
    _hasRemoteVideo = false;
    _isMicEnabled = true;
    _isCameraEnabled = true;
    _activeCall = null;
    _renderersReady = false;

    if (_incomingCallDialogVisible) {
      final context = navigatorKey.currentContext;
      if (context != null) {
        Navigator.of(context).pop();
      }
    }

    final pendingLock = _signalLock;
    _signalLock = null;
    if (pendingLock != null && !pendingLock.isCompleted) {
      pendingLock.complete();
    }

    await _chatWebRtcService.close(
      localRenderer: _localRenderer,
      remoteRenderer: _remoteRenderer,
    );
  }

  void _startCallDurationTimer() {
    if (_callDurationTimer != null) {
      return;
    }

    _callDurationSeconds = 0;
    _callDurationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _callDurationSeconds++;
      notifyListeners();
    });
  }

  void _stopCallDurationTimer() {
    _callDurationTimer?.cancel();
    _callDurationTimer = null;
    _callDurationSeconds = 0;
  }

  void _startRingingTimeout() {
    _ringingTimer?.cancel();
    _ringingTimer = Timer(const Duration(seconds: 60), () {
      if (_activeCall != null && _activeCall!.status == 'ringing') {
        final status = _activeCall!.initiator.id == _currentUserId
            ? 'cancelled'
            : 'missed';
        endCurrentCall(forcedStatus: status);
      }
    });
  }

  void _cancelRingingTimeout() {
    _ringingTimer?.cancel();
    _ringingTimer = null;
  }

  bool _isParticipantInCall(ChatCallModel call) {
    if (_currentUserId.isEmpty) {
      return true;
    }

    return call.initiator.id == _currentUserId ||
        call.recipient.id == _currentUserId;
  }

  String _messagePreview(ChatMessageModel message) {
    if (message.content.isNotEmpty) {
      return message.content;
    }
    if (message.imageUrl.isNotEmpty) {
      return 'Photo';
    }
    if (message.audioUrl.isNotEmpty) {
      return 'Voice message';
    }
    return '';
  }

  void _handleIncomingMessage(ChatMessageModel message) {
    _removeTypingUser(message.conversationId, message.sender.id);
    _upsertConversationPreview(
      message.conversationId,
      _messagePreview(message),
      message.createdAt,
    );

    if (_activeConversationId == message.conversationId) {
      _upsertMessage(message);
      _markConversationAsSeen(message.conversationId);
      notifyListeners();
      return;
    }

    notifyListeners();
  }

  void _handleUpdatedMessage(ChatMessageModel message) {
    _upsertMessage(message);
    _upsertConversationPreview(
      message.conversationId,
      _messagePreview(message),
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

  void _handleTypingChanged(
    String conversationId,
    String userId,
    bool isTyping,
  ) {
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
    } else {
      _messages = [..._messages, message]
        ..sort((a, b) {
          final left = a.createdAt?.millisecondsSinceEpoch ?? 0;
          final right = b.createdAt?.millisecondsSinceEpoch ?? 0;
          return left.compareTo(right);
        });
    }
    // Keep cache in sync so reopening shows the latest messages.
    final convId = _activeConversationId;
    if (convId != null) {
      _messageCache[convId] = _messages;
    }
  }

  bool _markMessagesAsSeen(
    String conversationId,
    List<String> messageIds,
    DateTime? seenAt,
  ) {
    if (_activeConversationId != conversationId) {
      return false;
    }

    final targetIds = messageIds.toSet();
    var hasChanges = false;
    final updatedMessages = _messages.map((message) {
      if (message.isSeen || (targetIds.isNotEmpty && !targetIds.contains(message.id))) {
        return message;
      }

      hasChanges = true;
      return message.copyWith(isSeen: true, seenAt: seenAt ?? message.seenAt ?? DateTime.now());
    }).toList();

    if (!hasChanges) {
      return false;
    }

    _messages = updatedMessages;
    // Keep cache in sync so isSeen persists when the conversation is re-opened.
    _messageCache[conversationId] = _messages;
    return true;
  }

  bool _removeMessage(String conversationId, String messageId) {
    if (_activeConversationId != conversationId) {
      return false;
    }

    final previousLength = _messages.length;
    _messages = _messages.where((item) => item.id != messageId).toList();
    final changed = _messages.length != previousLength;
    // Keep cache in sync.
    if (changed) {
      _messageCache[conversationId] = _messages;
    }
    return changed;
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

  bool _isAlreadyHandledFriendRequestError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('invalid id') ||
        message.contains('invalid request') ||
        message.contains('not found') ||
        message.contains('already processed') ||
        message.contains('already accepted') ||
        message.contains('already rejected') ||
        message.contains('already friends');
  }

  @override
  void dispose() {
    _chatSocketService.disconnect();
    CallSoundService.instance.stopRingtone();
    _chatWebRtcService.close(
      localRenderer: _localRenderer,
      remoteRenderer: _remoteRenderer,
    );
    _chatWebRtcService.disposeRenderers(_localRenderer, _remoteRenderer);
    super.dispose();
  }
}
