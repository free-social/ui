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
        lastMessageAt: DateTime.tryParse(
          conversationData['lastMessageAt'] ?? '',
        ),
        updatedAt: DateTime.tryParse(conversationData['updatedAt'] ?? ''),
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
      sender: ChatUser.fromJson(
        (json['sender'] as Map<String, dynamic>?) ?? const {},
      ),
      receiver: ChatUser.fromJson(
        (json['receiver'] as Map<String, dynamic>?) ?? const {},
      ),
      status: json['status'] ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? ''),
    );
  }
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
      lastMessageAt: DateTime.tryParse(json['lastMessageAt'] ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? ''),
    );
  }
}

class ChatMessageModel {
  final String id;
  final String conversationId;
  final ChatUser sender;
  final String content;
  final DateTime? createdAt;

  const ChatMessageModel({
    required this.id,
    required this.conversationId,
    required this.sender,
    required this.content,
    this.createdAt,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    final senderData = (json['sender'] as Map<String, dynamic>?) ?? const {};
    return ChatMessageModel(
      id: json['_id'] ?? '',
      conversationId: json['conversation'] ?? '',
      sender: ChatUser.fromJson(senderData),
      content: json['content'] ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] ?? ''),
    );
  }
}
