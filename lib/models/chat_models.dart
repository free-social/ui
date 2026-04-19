class ChatUser {
  final String id;
  final String username;
  final String email;
  final String avatar;
  final String relationshipStatus;
  final String conversationId;
  final String requestId;

  const ChatUser({
    required this.id,
    required this.username,
    required this.email,
    required this.avatar,
    required this.relationshipStatus,
    required this.conversationId,
    required this.requestId,
  });

  factory ChatUser.fromJson(Map<String, dynamic> json) {
    return ChatUser(
      id: json['id'] ?? json['_id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      avatar: json['avatar'] ?? '',
      relationshipStatus: json['relationshipStatus'] ?? 'none',
      conversationId: json['conversationId'] ?? '',
      requestId: json['requestId'] ?? '',
    );
  }

  ChatUser copyWith({
    String? id,
    String? username,
    String? email,
    String? avatar,
    String? relationshipStatus,
    String? conversationId,
    String? requestId,
  }) {
    return ChatUser(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      avatar: avatar ?? this.avatar,
      relationshipStatus: relationshipStatus ?? this.relationshipStatus,
      conversationId: conversationId ?? this.conversationId,
      requestId: requestId ?? this.requestId,
    );
  }
}

enum FriendRequestStatusFilter { pending, accepted, rejected }

extension FriendRequestStatusFilterX on FriendRequestStatusFilter {
  String get apiValue {
    switch (this) {
      case FriendRequestStatusFilter.pending:
        return 'pending';
      case FriendRequestStatusFilter.accepted:
        return 'accepted';
      case FriendRequestStatusFilter.rejected:
        return 'rejected';
    }
  }
}

DateTime? _parseLocalDateTime(dynamic value) {
  if (value == null) return null;
  final parsed = DateTime.tryParse(value.toString());
  return parsed?.toLocal();
}

bool _parseBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = value?.toString().trim().toLowerCase() ?? '';
  return normalized == 'true' || normalized == '1' || normalized == 'yes';
}

class FriendRequestActionResult {
  final String message;
  final ChatConversation? conversation;
  final String requestId;
  final String requestStatus;
  final String relationshipStatus;
  final String conversationId;

  const FriendRequestActionResult({
    required this.message,
    this.conversation,
    this.requestId = '',
    this.requestStatus = '',
    this.relationshipStatus = 'none',
    this.conversationId = '',
  });

  factory FriendRequestActionResult.fromJson(Map<String, dynamic> json) {
    final conversationData = json['conversation'];
    ChatConversation? conversation;

    if (conversationData is Map<String, dynamic>) {
      ChatUser friend = const ChatUser(
        id: '',
        username: '',
        email: '',
        avatar: '',
        relationshipStatus: 'friend',
        conversationId: '',
        requestId: '',
      );

      final participants = conversationData['participants'];
      if (participants is List) {
        final friendParticipant = participants
            .cast<dynamic>()
            .map((item) {
              return ChatUser.fromJson(item as Map<String, dynamic>);
            })
            .firstWhere(
              (participant) => participant.id.isNotEmpty,
              orElse: () => friend,
            );
        friend = friendParticipant;
      }

      conversation = ChatConversation(
        id: conversationData['_id'] ?? '',
        friend: friend,
        lastMessage: conversationData['lastMessage'] ?? '',
        lastMessageAt: _parseLocalDateTime(conversationData['lastMessageAt']),
        updatedAt: _parseLocalDateTime(conversationData['updatedAt']),
      );
    }

    return FriendRequestActionResult(
      message: json['message'] ?? '',
      conversation: conversation,
      requestId: (json['request'] as Map<String, dynamic>?)?['_id'] ?? '',
      requestStatus:
          (json['request'] as Map<String, dynamic>?)?['status'] ?? '',
      relationshipStatus:
          (json['relationship']
              as Map<String, dynamic>?)?['relationshipStatus'] ??
          'none',
      conversationId:
          (json['relationship'] as Map<String, dynamic>?)?['conversationId'] ??
          '',
    );
  }
}

class FriendRequestModel {
  final String id;
  final ChatUser sender;
  final ChatUser receiver;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const FriendRequestModel({
    required this.id,
    required this.sender,
    required this.receiver,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory FriendRequestModel.fromJson(Map<String, dynamic> json) {
    return FriendRequestModel(
      id: json['_id'] ?? '',
      sender: _parseFriendRequestUser(json['sender']),
      receiver: _parseFriendRequestUser(json['receiver']),
      status: json['status'] ?? '',
      createdAt: _parseLocalDateTime(json['createdAt']),
      updatedAt: _parseLocalDateTime(json['updatedAt']),
    );
  }
}

ChatUser _parseFriendRequestUser(dynamic value) {
  if (value is Map<String, dynamic>) {
    return ChatUser.fromJson(value);
  }

  if (value is Map) {
    return ChatUser.fromJson(Map<String, dynamic>.from(value));
  }

  if (value is String) {
    return ChatUser(
      id: value,
      username: '',
      email: '',
      avatar: '',
      relationshipStatus: 'none',
      conversationId: '',
      requestId: '',
    );
  }

  return const ChatUser(
    id: '',
    username: '',
    email: '',
    avatar: '',
    relationshipStatus: 'none',
    conversationId: '',
    requestId: '',
  );
}

class ChatConversation {
  final String id;
  final ChatUser friend;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final DateTime? updatedAt;

  const ChatConversation({
    required this.id,
    required this.friend,
    required this.lastMessage,
    this.lastMessageAt,
    this.updatedAt,
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      id: json['conversationId'] ?? json['_id'] ?? '',
      friend: ChatUser.fromJson(
        (json['friend'] as Map<String, dynamic>?) ?? const {},
      ),
      lastMessage: json['lastMessage'] ?? '',
      lastMessageAt: _parseLocalDateTime(json['lastMessageAt']),
      updatedAt: _parseLocalDateTime(json['updatedAt']),
    );
  }
}

class ChatMessageModel {
  final String id;
  final String conversationId;
  final ChatUser sender;
  final String content;
  final String imageUrl;
  final String audioUrl;
  final int? audioDurationSeconds;
  final bool isSeen;
  final DateTime? seenAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? editedAt;
  final ChatMessageModel? replyTo;
  final String? reaction;

  const ChatMessageModel({
    required this.id,
    required this.conversationId,
    required this.sender,
    required this.content,
    required this.imageUrl,
    required this.audioUrl,
    this.audioDurationSeconds,
    required this.isSeen,
    this.seenAt,
    this.createdAt,
    this.updatedAt,
    this.editedAt,
    this.replyTo,
    this.reaction,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    final senderData = (json['sender'] as Map<String, dynamic>?) ?? const {};
    final receiptData =
        (json['receipt'] as Map<String, dynamic>?) ??
        (json['readReceipt'] as Map<String, dynamic>?) ??
        (json['status'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final seenAt =
        _parseLocalDateTime(json['seenAt']) ??
        _parseLocalDateTime(json['readAt']) ??
        _parseLocalDateTime(receiptData['seenAt']) ??
        _parseLocalDateTime(receiptData['readAt']);

    return ChatMessageModel(
      id: json['_id'] ?? '',
      conversationId: json['conversation'] ?? '',
      sender: ChatUser.fromJson(senderData),
      content: json['content'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      audioUrl: json['audioUrl'] ?? '',
      audioDurationSeconds: json['audioDurationSeconds'] is num
          ? (json['audioDurationSeconds'] as num).toInt()
          : int.tryParse('${json['audioDurationSeconds'] ?? ''}'),
      isSeen:
          _parseBool(json['isSeen']) ||
          _parseBool(json['seen']) ||
          _parseBool(json['isRead']) ||
          _parseBool(json['read']) ||
          _parseBool(receiptData['isSeen']) ||
          _parseBool(receiptData['seen']) ||
          _parseBool(receiptData['isRead']) ||
          _parseBool(receiptData['read']) ||
          seenAt != null,
      seenAt: seenAt,
      createdAt: _parseLocalDateTime(json['createdAt']),
      updatedAt: _parseLocalDateTime(json['updatedAt']),
      editedAt: _parseLocalDateTime(json['editedAt']),
      replyTo: json['replyTo'] is Map<String, dynamic>
          ? ChatMessageModel.fromJson(json['replyTo'])
          : null,
      reaction: json['reaction']?.toString(),
    );
  }

  ChatMessageModel copyWith({
    String? id,
    String? conversationId,
    ChatUser? sender,
    String? content,
    String? imageUrl,
    String? audioUrl,
    int? audioDurationSeconds,
    bool? isSeen,
    DateTime? seenAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? editedAt,
    ChatMessageModel? replyTo,
    String? reaction,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      sender: sender ?? this.sender,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      audioDurationSeconds: audioDurationSeconds ?? this.audioDurationSeconds,
      isSeen: isSeen ?? this.isSeen,
      seenAt: seenAt ?? this.seenAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      editedAt: editedAt ?? this.editedAt,
      replyTo: replyTo ?? this.replyTo,
      reaction: reaction ?? this.reaction,
    );
  }
}

class ChatCallParticipant {
  final String id;
  final String username;
  final String email;
  final String avatar;

  const ChatCallParticipant({
    required this.id,
    required this.username,
    required this.email,
    required this.avatar,
  });

  factory ChatCallParticipant.fromJson(Map<String, dynamic> json) {
    return ChatCallParticipant(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      avatar: (json['avatar'] ?? '').toString(),
    );
  }
}

class ChatCallModel {
  final String id;
  final String conversationId;
  final ChatCallParticipant initiator;
  final ChatCallParticipant recipient;
  final String type;
  final String status;
  final ChatCallParticipant? endedBy;
  final int? durationSeconds;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ChatCallModel({
    required this.id,
    required this.conversationId,
    required this.initiator,
    required this.recipient,
    required this.type,
    required this.status,
    this.endedBy,
    this.durationSeconds,
    this.startedAt,
    this.endedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory ChatCallModel.fromJson(Map<String, dynamic> json) {
    return ChatCallModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      conversationId: (json['conversationId'] ?? json['conversation'] ?? '')
          .toString(),
      initiator: ChatCallParticipant.fromJson(
        (json['initiator'] as Map<String, dynamic>?) ??
            const <String, dynamic>{},
      ),
      recipient: ChatCallParticipant.fromJson(
        (json['recipient'] as Map<String, dynamic>?) ??
            const <String, dynamic>{},
      ),
      type: (json['type'] ?? 'video').toString(),
      status: (json['status'] ?? 'ringing').toString(),
      endedBy: json['endedBy'] is Map<String, dynamic>
          ? ChatCallParticipant.fromJson(
              json['endedBy'] as Map<String, dynamic>,
            )
          : null,
      durationSeconds: json['durationSeconds'] is num
          ? (json['durationSeconds'] as num).toInt()
          : int.tryParse('${json['durationSeconds'] ?? ''}'),
      startedAt: _parseLocalDateTime(json['startedAt']),
      endedAt: _parseLocalDateTime(json['endedAt']),
      createdAt: _parseLocalDateTime(json['createdAt']),
      updatedAt: _parseLocalDateTime(json['updatedAt']),
    );
  }

  bool get isVideo => type == 'video';
  bool get isAccepted => status == 'accepted';
  bool get isRinging => status == 'ringing';

  ChatCallModel copyWith({
    String? id,
    String? conversationId,
    ChatCallParticipant? initiator,
    ChatCallParticipant? recipient,
    String? type,
    String? status,
    ChatCallParticipant? endedBy,
    int? durationSeconds,
    DateTime? startedAt,
    DateTime? endedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChatCallModel(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      initiator: initiator ?? this.initiator,
      recipient: recipient ?? this.recipient,
      type: type ?? this.type,
      status: status ?? this.status,
      endedBy: endedBy ?? this.endedBy,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
