import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/chat_models.dart';
import '../providers/chat_provider.dart';
import '../utils/snackbar_helper.dart';
import 'chat_conversation_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Color kPrimaryColor = const Color(0xFF00BFA5);
  final Color kNeutralActionColor = const Color(0xFF64748B);
  static const double _chatSnackTopOffset = kToolbarHeight;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().loadInbox();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey[400]! : Colors.grey[700]!;
    final headerAccent = isDark
        ? const Color(0xFF11332F)
        : const Color(0xFFE7F8F4);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        title: Text(
          'Chats',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Consumer<ChatProvider>(
        builder: (context, chatProvider, child) {
          return RefreshIndicator(
            color: kPrimaryColor,
            onRefresh: () => chatProvider.loadInbox(forceSearchRefresh: true),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _buildSearchCard(
                  context,
                  chatProvider,
                  textColor,
                  subTextColor,
                  headerAccent,
                ),
                const SizedBox(height: 22),
                if (chatProvider.receivedRequests.isNotEmpty) ...[
                  _buildSectionTitle('Friend Requests', textColor),
                  const SizedBox(height: 10),
                  ...chatProvider.receivedRequests.map(
                    (request) => _buildRequestCard(
                      context,
                      request,
                      textColor,
                      subTextColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                _buildSectionTitle('Conversations', textColor),
                const SizedBox(height: 10),
                if (chatProvider.isLoading &&
                    chatProvider.conversations.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (chatProvider.conversations.isEmpty)
                  _buildEmptyState(
                    context,
                    title: 'No conversations yet',
                    subtitle:
                        'Search for a user and send a friend request to start chatting.',
                  )
                else
                  ...chatProvider.conversations.map(
                    (conversation) => _buildConversationCard(
                      context,
                      conversation,
                      textColor,
                      subTextColor,
                    ),
                  ),
                if (chatProvider.sentRequests.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildSectionTitle('Pending Sent Requests', textColor),
                  const SizedBox(height: 10),
                  ...chatProvider.sentRequests.map(
                    (request) => _buildSentRequestCard(
                      context,
                      request,
                      textColor,
                      subTextColor,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchCard(
    BuildContext context,
    ChatProvider chatProvider,
    Color textColor,
    Color subTextColor,
    Color headerAccent,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: headerAccent,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Find friends',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF08312A),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Search by username or email',
            style: TextStyle(
              color: isDark ? Colors.white70 : const Color(0xFF2E5A55),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            onChanged: (value) =>
                context.read<ChatProvider>().searchUsers(value),
            decoration: InputDecoration(
              hintText: 'Search users',
              prefixIcon: Icon(Icons.search, color: kPrimaryColor),
              filled: true,
              fillColor: Theme.of(context).cardColor,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (chatProvider.searchQuery.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            if (chatProvider.searchResults.isEmpty && !chatProvider.isLoading)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'No users found',
                  style: TextStyle(color: subTextColor),
                ),
              )
            else
              ...chatProvider.searchResults.map(
                (user) => _buildSearchUserTile(
                  context,
                  chatProvider,
                  user,
                  textColor,
                  subTextColor,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchUserTile(
    BuildContext context,
    ChatProvider chatProvider,
    ChatUser user,
    Color textColor,
    Color subTextColor,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final relationshipStatus = user.relationshipStatus;
    final alreadyAdded =
        relationshipStatus == 'friend' || chatProvider.isFriend(user.id);
    final pendingSent =
        relationshipStatus == 'sent' ||
        chatProvider.hasPendingSentRequest(user.id);
    final pendingReceived =
        relationshipStatus == 'received' ||
        chatProvider.hasPendingReceivedRequest(user.id);
    final actionLabel = alreadyAdded
        ? 'Friend'
        : pendingSent
        ? 'Pending'
        : pendingReceived
        ? 'Respond'
        : 'Add';
    final actionColor = alreadyAdded
        ? (isDark ? const Color(0xFF1E3A36) : const Color(0xFFDDF5EF))
        : pendingSent
        ? (isDark ? const Color(0xFF4A3612) : const Color(0xFFFFF3D6))
        : pendingReceived
        ? (isDark
              ? const Color(0xFF11332F)
              : const Color.fromARGB(255, 95, 132, 123))
        : kPrimaryColor;
    final actionTextColor = alreadyAdded
        ? kPrimaryColor
        : pendingSent
        ? const Color(0xFFB7791F)
        : Colors.white;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      visualDensity: const VisualDensity(vertical: -2),
      leading: _buildProfileAvatar(
        avatarUrl: user.avatar,
        radius: 22,
        cardColor: cardColor,
      ),
      title: Text(
        user.username.isNotEmpty ? user.username : user.email,
        style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        pendingSent ? 'Request pending' : user.email,
        style: TextStyle(color: subTextColor),
      ),
      trailing: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          if (alreadyAdded) {
            final action = await _showFriendOptionsSheet(context, user);

            if (!context.mounted) return;

            if (action == 'remove') {
              final confirmed = await _showRemoveFriendConfirmSheet(
                context,
                user,
              );
              if (!context.mounted || confirmed != true) {
                return;
              }
              try {
                await chatProvider.removeFriend(user.id);
                if (!context.mounted) return;
                showInfoSnackBar(
                  context,
                  'Friend removed successfully',
                  topOffset: _chatSnackTopOffset,
                );
              } catch (e) {
                if (!context.mounted) return;
                showErrorSnackBar(
                  context,
                  e.toString().replaceFirst('Exception: ', ''),
                  topOffset: _chatSnackTopOffset,
                );
              }
              return;
            }

            if (action != 'chat') {
              return;
            }

            final conversation =
                chatProvider.findConversationByUserId(user.id) ??
                (user.conversationId.isNotEmpty
                    ? ChatConversation(
                        id: user.conversationId,
                        friend: user,
                        lastMessage: '',
                        lastMessageAt: null,
                        updatedAt: null,
                      )
                    : null);
            if (conversation != null && context.mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ChatConversationScreen(conversation: conversation),
                ),
              );
            }
            return;
          }

          if (pendingSent) {
            if (!context.mounted) return;
            showInfoSnackBar(
              context,
              'Friend request already sent',
              topOffset: _chatSnackTopOffset,
            );
            return;
          }

          if (pendingReceived) {
            final requestId = user.requestId.isNotEmpty
                ? user.requestId
                : _findReceivedRequestId(chatProvider, user.id);

            if (requestId.isEmpty) {
              await chatProvider.refreshRelationshipState();
              if (!context.mounted) return;
              showErrorSnackBar(
                context,
                'Pending request not found. Refresh and try again.',
                topOffset: _chatSnackTopOffset,
              );
              return;
            }

            final action = await _showRespondToRequestSheet(context, user);
            if (!context.mounted || action == null) return;

            try {
              if (action == 'accepted') {
                await chatProvider.acceptFriendRequest(requestId);
                if (!context.mounted) return;
                showSuccessSnackBar(
                  context,
                  'Friend request accepted',
                  topOffset: _chatSnackTopOffset,
                );
              } else if (action == 'rejected') {
                await chatProvider.rejectFriendRequest(requestId);
                if (!context.mounted) return;
                showInfoSnackBar(
                  context,
                  'Friend request dismissed',
                  topOffset: _chatSnackTopOffset,
                );
              }
            } catch (e) {
              if (!context.mounted) return;
              showErrorSnackBar(
                context,
                e.toString().replaceFirst('Exception: ', ''),
                topOffset: _chatSnackTopOffset,
              );
            }
            return;
          }

          try {
            chatProvider.markUserRelationship(
              user.id,
              relationshipStatus: 'sent',
              conversationId: user.conversationId,
              requestId: user.requestId,
            );

            final result = await chatProvider.sendFriendRequest(user.id);
            chatProvider.markUserRelationship(
              user.id,
              relationshipStatus: result.relationshipStatus,
              conversationId: result.conversationId.isNotEmpty
                  ? result.conversationId
                  : (result.conversation?.id ?? user.conversationId),
              requestId: result.requestId.isNotEmpty
                  ? result.requestId
                  : user.requestId,
            );
            if (!context.mounted) return;
            if (result.conversation != null) {
              final conversation = ChatConversation(
                id: result.conversation!.id,
                friend: user,
                lastMessage: result.conversation!.lastMessage,
                lastMessageAt: result.conversation!.lastMessageAt,
                updatedAt: result.conversation!.updatedAt,
              );
              showSuccessSnackBar(
                context,
                result.message.isNotEmpty
                    ? result.message
                    : 'Friend added successfully',
                topOffset: _chatSnackTopOffset,
              );
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ChatConversationScreen(conversation: conversation),
                ),
              );
            } else {
              showSuccessSnackBar(
                context,
                result.message.isNotEmpty
                    ? result.message
                    : 'Friend request sent',
                topOffset: _chatSnackTopOffset,
              );
            }
          } catch (e) {
            chatProvider.markUserRelationship(
              user.id,
              relationshipStatus: user.relationshipStatus,
              conversationId: user.conversationId,
              requestId: user.requestId,
            );
            await chatProvider.refreshRelationshipState();
            if (!context.mounted) return;
            showErrorSnackBar(
              context,
              e.toString().replaceFirst('Exception: ', ''),
              topOffset: _chatSnackTopOffset,
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: actionColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            actionLabel,
            style: TextStyle(
              color: actionTextColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestCard(
    BuildContext context,
    FriendRequestModel request,
    Color textColor,
    Color subTextColor,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final sender = request.sender;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildProfileAvatar(
                avatarUrl: sender.avatar,
                radius: 20,
                cardColor: cardColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sender.username.isNotEmpty
                          ? sender.username
                          : sender.email,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      sender.email,
                      style: TextStyle(color: subTextColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF242424)
                      : const Color(0xFFF2F4F7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Request',
                  style: TextStyle(
                    color: subTextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  label: 'Later',
                  backgroundColor: isDark
                      ? const Color(0xFF242424)
                      : const Color(0xFFF2F4F7),
                  textColor: kNeutralActionColor,
                  onTap: () async {
                    try {
                      await context.read<ChatProvider>().rejectFriendRequest(
                        request.id,
                      );
                      if (!context.mounted) return;
                      showInfoSnackBar(
                        context,
                        'Friend request dismissed',
                        topOffset: _chatSnackTopOffset,
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      showErrorSnackBar(
                        context,
                        e.toString().replaceFirst('Exception: ', ''),
                        topOffset: _chatSnackTopOffset,
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  label: 'Accept',
                  backgroundColor: kPrimaryColor,
                  textColor: Colors.white,
                  onTap: () async {
                    try {
                      await context.read<ChatProvider>().acceptFriendRequest(
                        request.id,
                      );
                      if (!context.mounted) return;
                      showSuccessSnackBar(
                        context,
                        'Friend request accepted',
                        topOffset: _chatSnackTopOffset,
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      showErrorSnackBar(
                        context,
                        e.toString().replaceFirst('Exception: ', ''),
                        topOffset: _chatSnackTopOffset,
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConversationCard(
    BuildContext context,
    ChatConversation conversation,
    Color textColor,
    Color subTextColor,
  ) {
    final cardColor = Theme.of(context).cardColor;
    final friend = conversation.friend;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ChatConversationScreen(conversation: conversation),
            ),
          );
        },
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        leading: _buildProfileAvatar(
          avatarUrl: friend.avatar,
          radius: 24,
          cardColor: cardColor,
        ),
        title: Text(
          friend.username.isNotEmpty ? friend.username : friend.email,
          style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          conversation.lastMessage.isNotEmpty
              ? conversation.lastMessage
              : 'Start the conversation',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: subTextColor),
        ),
        trailing: Text(
          _formatTimestamp(conversation.lastMessageAt),
          style: TextStyle(color: subTextColor, fontSize: 11),
        ),
      ),
    );
  }

  Widget _buildSentRequestCard(
    BuildContext context,
    FriendRequestModel request,
    Color textColor,
    Color subTextColor,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final receiver = request.receiver;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: _buildProfileAvatar(
          avatarUrl: receiver.avatar,
          radius: 21,
          cardColor: cardColor,
        ),
        title: Text(
          receiver.username.isNotEmpty ? receiver.username : receiver.email,
          style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Pending approval',
          style: TextStyle(color: subTextColor),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF242424) : const Color(0xFFF2F4F7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Pending',
            style: TextStyle(
              color: subTextColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Text(
      title,
      style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildEmptyState(
    BuildContext context, {
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(Icons.chat_bubble_outline, size: 40, color: kPrimaryColor),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime? value) {
    if (value == null) return '';
    final now = DateTime.now();
    if (now.difference(value).inDays == 0) {
      return DateFormat('HH:mm').format(value);
    }
    return DateFormat('dd MMM').format(value);
  }

  Widget _buildActionButton({
    required String label,
    required Color backgroundColor,
    required Color textColor,
    required Future<void> Function() onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async => onTap(),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildProfileAvatar({
    required String avatarUrl,
    required double radius,
    required Color cardColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: cardColor, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFFF5F7FA),
        child: ClipOval(
          child: avatarUrl.isNotEmpty
              ? Image.network(
                  avatarUrl,
                  width: radius * 2,
                  height: radius * 2,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(Icons.person, size: 24, color: Colors.grey),
                    );
                  },
                )
              : const Center(
                  child: Icon(Icons.person, size: 24, color: Colors.grey),
                ),
        ),
      ),
    );
  }

  Future<String?> _showFriendOptionsSheet(BuildContext context, ChatUser user) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey[400]! : Colors.grey[700]!;

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 18),
              _buildProfileAvatar(
                avatarUrl: user.avatar,
                radius: 32,
                cardColor: theme.cardColor,
              ),
              const SizedBox(height: 14),
              Text(
                user.username.isNotEmpty ? user.username : user.email,
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user.email,
                style: TextStyle(color: subTextColor, fontSize: 13),
              ),
              const SizedBox(height: 18),
              _buildSheetAction(
                context: sheetContext,
                label: 'Open Chat',
                subtitle: 'Continue your conversation',
                backgroundColor: isDark
                    ? const Color(0xFF11332F)
                    : const Color(0xFFE7F8F4),
                icon: Icons.chat_bubble_outline,
                iconColor: kPrimaryColor,
                textColor: textColor,
                onTap: () => Navigator.pop(sheetContext, 'chat'),
              ),
              const SizedBox(height: 12),
              _buildSheetAction(
                context: sheetContext,
                label: 'Remove Friend',
                subtitle: 'Delete this friend connection',
                backgroundColor: isDark
                    ? const Color(0xFF2A1717)
                    : const Color(0xFFFFEBEB),
                icon: Icons.person_remove_outlined,
                iconColor: const Color(0xFFE05555),
                textColor: textColor,
                onTap: () => Navigator.pop(sheetContext, 'remove'),
              ),
            ],
          ),
        );
      },
    );
  }

  String _findReceivedRequestId(ChatProvider chatProvider, String userId) {
    for (final request in chatProvider.receivedRequests) {
      if (request.sender.id == userId) {
        return request.id;
      }
    }
    return '';
  }

  Future<String?> _showRespondToRequestSheet(
    BuildContext context,
    ChatUser user,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey[400]! : Colors.grey[700]!;

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 18),
              _buildProfileAvatar(
                avatarUrl: user.avatar,
                radius: 32,
                cardColor: theme.cardColor,
              ),
              const SizedBox(height: 14),
              Text(
                user.username.isNotEmpty ? user.username : user.email,
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Respond to this friend request',
                style: TextStyle(color: subTextColor, fontSize: 13),
              ),
              const SizedBox(height: 18),
              _buildSheetAction(
                context: sheetContext,
                label: 'Accept',
                subtitle: 'Add this user to your friends list',
                backgroundColor: isDark
                    ? const Color(0xFF11332F)
                    : const Color(0xFFE7F8F4),
                icon: Icons.check_circle_outline,
                iconColor: kPrimaryColor,
                textColor: textColor,
                onTap: () => Navigator.pop(sheetContext, 'accepted'),
              ),
              const SizedBox(height: 12),
              _buildSheetAction(
                context: sheetContext,
                label: 'Dismiss',
                subtitle: 'Reject this pending request',
                backgroundColor: isDark
                    ? const Color(0xFF242424)
                    : const Color(0xFFF2F4F7),
                icon: Icons.close,
                iconColor: kNeutralActionColor,
                textColor: textColor,
                onTap: () => Navigator.pop(sheetContext, 'rejected'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<bool?> _showRemoveFriendConfirmSheet(
    BuildContext context,
    ChatUser user,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey[400]! : Colors.grey[700]!;

    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2A1717)
                      : const Color(0xFFFFEBEB),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_remove_outlined,
                  color: Color(0xFFE05555),
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Remove friend?',
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You will remove ${user.username.isNotEmpty ? user.username : user.email} from your friends list and delete your chat history.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: subTextColor,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      label: 'Cancel',
                      backgroundColor: isDark
                          ? const Color(0xFF242424)
                          : const Color(0xFFF2F4F7),
                      textColor: kNeutralActionColor,
                      onTap: () async => Navigator.pop(sheetContext, false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionButton(
                      label: 'Remove',
                      backgroundColor: const Color(0xFFE05555),
                      textColor: Colors.white,
                      onTap: () async => Navigator.pop(sheetContext, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSheetAction({
    required BuildContext context,
    required String label,
    required String subtitle,
    required Color backgroundColor,
    required IconData icon,
    required Color iconColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    final subTextColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[400]!
        : Colors.grey[700]!;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.75),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: subTextColor, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: subTextColor),
          ],
        ),
      ),
    );
  }
}
