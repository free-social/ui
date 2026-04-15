import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/navigation/app_navigator.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';
import '../services/chat_socket_service.dart';
import '../services/chat_webrtc_service.dart';

class ChatProvider with ChangeNotifier {
  final ChatService _chatService;
  final ChatSocketService _chatSocketService;
  final ChatWebRtcService _chatWebRtcService;

  ChatProvider({
    ChatService? chatService,
    ChatSocketService? chatSocketService,
    ChatWebRtcService? chatWebRtcService,
  }) : _chatService = chatService ?? ChatService(),
       _chatSocketService = chatSocketService ?? ChatSocketService(),
       _chatWebRtcService = chatWebRtcService ?? ChatWebRtcService() {
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
    _bootstrap();
  }

  bool _isLoading = false;
  bool _isSendingMessage = false;
  bool _isUpdatingMessage = false;
  bool _isCallLoading = false;
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
  Timer? _ringingTimer;
  Completer<void>? _signalLock;
  final Map<String, Set<String>> _typingUserIdsByConversation = {};

  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  List<ChatUser> _searchResults = [];
  List<FriendRequestModel> _receivedRequests = [];
  List<FriendRequestModel> _sentRequests = [];
  List<ChatConversation> _conversations = [];
  List<ChatMessageModel> _messages = [];
  ChatCallModel? _activeCall;

  bool get isLoading => _isLoading;
  bool get isSendingMessage => _isSendingMessage;
  bool get isUpdatingMessage => _isUpdatingMessage;
  bool get isCallLoading => _isCallLoading;
  bool get isMicEnabled => _isMicEnabled;
  bool get isCameraEnabled => _isCameraEnabled;
  bool get hasRemoteVideo => _hasRemoteVideo;
  String get searchQuery => _searchQuery;
  String get currentUserId => _currentUserId;
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
        return 'Connected';
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
      await _chatSocketService.syncConversationSubscriptions({
        ..._conversations.map((conversation) => conversation.id),
        conversationId,
      });
      _messages = await _chatService.getMessages(conversationId);
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
    _isCallLoading = true;
    notifyListeners();

    try {
      await _ensureCurrentUserId();
      await _ensureRenderersReady();

      final call = await _chatService.startCall(conversationId, type);
      _activeCall = call;
      _lastNegotiatedCallId = null;
      _hasRemoteVideo = false;
      _isMicEnabled = true;
      _isCameraEnabled = call.isVideo;

      await _prepareLocalMedia(call);
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

      await _prepareLocalMedia(updatedCall);
      await _ensurePeerConnection();
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
      await _chatService.endCall(call.id, status);
    } catch (_) {
      // Still tear down local state if the call already ended remotely.
    } finally {
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

  Future<void> _bootstrap() async {
    await _ensureCurrentUserId();
    await _ensureRenderersReady();
    final iceServers = await _chatService.getRtcIceServers();
    _chatWebRtcService.configureIceServers(iceServers);
    await _chatSocketService.connect();
    try {
      await loadInbox();
    } catch (_) {
      // Keep global call signaling alive even if inbox prefetch fails.
    }
  }

  Future<void> _ensureCurrentUserId() async {
    if (_currentUserId.isNotEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('userId')?.trim() ?? '';
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

    if (_activeCall != null && _activeCall!.id != call.id) {
      return;
    }

    _activeCall = call;
    _lastNegotiatedCallId = null;
    notifyListeners();
    _startRingingTimeout();
    await _showIncomingCallDialog(call);
  }

  Future<void> _handleCallStatus(ChatCallModel call) async {
    await _ensureCurrentUserId();
    if (!_isParticipantInCall(call)) {
      return;
    }

    _activeCall = call;
    _cancelRingingTimeout();
    notifyListeners();

    if (call.status == 'accepted' && call.initiator.id == _currentUserId) {
      await _startNegotiationAsCaller(call);
      await _openCallScreen();
      notifyListeners();
      return;
    }

    if (call.status == 'rejected') {
      await _resetCallState();
      notifyListeners();
    }
  }

  Future<void> _handleCallEnded(ChatCallModel call) async {
    await _ensureCurrentUserId();
    if (!_isParticipantInCall(call)) {
      return;
    }

    await _resetCallState();
    notifyListeners();
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

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            call.isVideo ? 'Incoming video call' : 'Incoming audio call',
          ),
          content: Text('$caller is calling you.'),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await rejectIncomingCall();
              },
              child: const Text('Decline'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await acceptIncomingCall();
              },
              child: const Text('Answer'),
            ),
          ],
        );
      },
    );

    _incomingCallDialogVisible = false;
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
    } catch (_) {
      // Ignore navigation errors.
    } finally {
      _callRouteVisible = false;
    }
  }

  Future<void> _resetCallState() async {
    _cancelRingingTimeout();
    _lastNegotiatedCallId = null;
    _hasRemoteVideo = false;
    _isMicEnabled = true;
    _isCameraEnabled = true;
    _activeCall = null;

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
      return message.copyWith(isSeen: true, seenAt: seenAt ?? message.seenAt);
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
    _chatWebRtcService.close(
      localRenderer: _localRenderer,
      remoteRenderer: _remoteRenderer,
    );
    _chatWebRtcService.disposeRenderers(_localRenderer, _remoteRenderer);
    super.dispose();
  }
}
