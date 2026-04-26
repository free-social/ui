import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../utils/auth_image_headers.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_radii.dart';
import '../core/theme/app_spacing.dart';
import '../models/chat_models.dart';
import '../providers/chat_provider.dart';
import '../utils/snackbar_helper.dart';
import 'chat_conversation_screen.dart';
import 'ai_chat_screen.dart';
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _searchController = TextEditingController();
  static const double _chatSnackTopOffset = kToolbarHeight;
  static const List<FriendRequestStatusFilter> _requestTabs = [
    FriendRequestStatusFilter.pending,
    FriendRequestStatusFilter.accepted,
    FriendRequestStatusFilter.rejected,
  ];

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
    final scaffoldBg = theme.scaffoldBackgroundColor;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
          : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      child: DefaultTabController(
        length: 4,
        child: Scaffold(
          backgroundColor: scaffoldBg,
          body: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: MediaQuery.of(context).size.height * 0.22,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [theme.colorScheme.primary, AppColors.accent],
                      ),
                    ),
                  ),
                  SafeArea(
                    bottom: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 15), 
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xl,
                            vertical: AppSpacing.sm,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Messages',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              FilledButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const AiChatScreen(),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.auto_awesome, size: 18),
                                label: const Text("Chat AI"),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        TabBar(
                          dividerColor: Colors.transparent,
                          indicatorColor: Colors.white,
                          indicatorWeight: 3,
                          indicatorSize: TabBarIndicatorSize.label,
                          labelColor: Colors.white,
                          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
                          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                          tabs: const [
                            Tab(text: 'Chats'),
                            Tab(text: 'Friends'),
                            Tab(text: 'Find'),
                            Tab(text: 'Requests'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Consumer<ChatProvider>(
                  builder: (context, chatProvider, child) {
                    return TabBarView(
                      children: [
                        _buildChatsTab(context, chatProvider),
                        _buildFriendsTab(context, chatProvider),
                        _buildFindPeopleTab(context, chatProvider),
                        _buildRequestsTab(context, chatProvider),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFriendsTab(BuildContext context, ChatProvider chatProvider) {
    return RefreshIndicator(
      onRefresh: () => chatProvider.loadInbox(forceSearchRefresh: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xl,
          120,
        ),
        children: [
          _buildSectionHeader(
            context,
            'Your friends',
            chatProvider.friends.isEmpty
                ? 'No friends yet'
                : '${chatProvider.friends.length} total',
          ),
          const SizedBox(height: AppSpacing.md),
          if (chatProvider.isLoading && chatProvider.friends.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (chatProvider.friends.isEmpty)
            _buildEmptyState(
              context,
              title: 'No friends found',
            )
          else
            Column(
              children: chatProvider.friends
                  .map(
                    (user) => _buildSearchUserTile(
                      context,
                      chatProvider,
                      user,
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildFindPeopleTab(BuildContext context, ChatProvider chatProvider) {
    return RefreshIndicator(
      onRefresh: () => chatProvider.loadInbox(forceSearchRefresh: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xl,
          120,
        ),
        children: [_buildSearchPanel(context, chatProvider)],
      ),
    );
  }

  Widget _buildRequestsTab(BuildContext context, ChatProvider chatProvider) {
    return RefreshIndicator(
      onRefresh: () => chatProvider.loadInbox(forceSearchRefresh: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xl,
          120,
        ),
        children: [_buildRequestSection(context, chatProvider)],
      ),
    );
  }

  Widget _buildChatsTab(BuildContext context, ChatProvider chatProvider) {
    return RefreshIndicator(
      onRefresh: () => chatProvider.loadInbox(forceSearchRefresh: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xl,
          120,
        ),
        children: [
          _buildSectionHeader(
            context,
            'Conversations',
            chatProvider.conversations.isEmpty
                ? 'Start one by adding a friend'
                : '${chatProvider.conversations.length} active',
          ),
          const SizedBox(height: AppSpacing.md),
          if (chatProvider.isLoading && chatProvider.conversations.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (chatProvider.conversations.isEmpty)
            _buildEmptyState(
              context,
              title: 'No conversations yet',
            )
          else
            ...chatProvider.conversations.map(
              (conversation) => _buildConversationRow(context, conversation),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchPanel(BuildContext context, ChatProvider chatProvider) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.person_search_rounded, color: scheme.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Find people', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 2),
                  Text(
                    'Search to add friends.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _searchController,
          onChanged: chatProvider.searchUsers,
          decoration: InputDecoration(
            hintText: 'Search friends',
            filled: true,
            fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: scheme.onSurfaceVariant,
            ),
            hintStyle: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.md),
              borderSide: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.55),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.md),
              borderSide: BorderSide(color: scheme.primary, width: 1.2),
            ),
          ),
          style: TextStyle(color: scheme.onSurface),
        ),
        if (chatProvider.searchQuery.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          if (chatProvider.isLoading && chatProvider.searchResults.isEmpty)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              ),
            )
          else if (chatProvider.searchResults.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.md,
                horizontal: AppSpacing.sm,
              ),
              child: Text(
                'No users found for "${chatProvider.searchQuery}".',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.72),
                ),
              ),
            )
          else
            Column(
              children: chatProvider.searchResults
                  .map(
                    (user) => _buildSearchUserTile(
                      context,
                      chatProvider,
                      user,
                    ),
                  )
                  .toList(),
            ),
        ],
      ],
    );
  }

  Widget _buildRequestSection(BuildContext context, ChatProvider chatProvider) {
    final receivedRequests = chatProvider.receivedRequests;
    final sentRequests = chatProvider.sentRequests;
    final totalRequests = receivedRequests.length + sentRequests.length;
    final activeFilter = chatProvider.requestStatusFilter;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          context,
          'Requests',
          totalRequests == 0
              ? 'No ${_requestStatusLabel(activeFilter).toLowerCase()} requests'
              : '$totalRequests ${_requestStatusLabel(activeFilter).toLowerCase()}',
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: _requestTabs.map((filter) {
            return ChoiceChip(
              label: Text(_requestStatusLabel(filter)),
              selected: filter == activeFilter,
              onSelected: (selected) async {
                if (!selected) return;
                await chatProvider.setRequestStatusFilter(filter);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.md),
        if (chatProvider.isLoading && totalRequests == 0)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (totalRequests == 0)
          _buildEmptyState(
            context,
            title: 'No ${_requestStatusLabel(activeFilter)} requests',
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (receivedRequests.isNotEmpty) ...[
                _buildSubsectionLabel(context, 'Received'),
                const SizedBox(height: AppSpacing.sm),
                Column(
                  children: receivedRequests.map((request) {
                    if (activeFilter == FriendRequestStatusFilter.pending) {
                      return _buildRequestCard(context, request);
                    }

                    return _buildRequestStatusRow(
                      context,
                      user: request.sender,
                      status: request.status,
                      subtitle: request.sender.email,
                    );
                  }).toList(),
                ),
              ],
              if (receivedRequests.isNotEmpty && sentRequests.isNotEmpty)
                const SizedBox(height: AppSpacing.lg),
              if (sentRequests.isNotEmpty) ...[
                _buildSubsectionLabel(context, 'Sent'),
                const SizedBox(height: AppSpacing.sm),
                Column(
                  children: sentRequests
                      .map((request) => _buildSentRequestRow(context, request))
                      .toList(),
                ),
              ],
            ],
          ),
      ],
    );
  }

  Widget _buildSearchUserTile(
    BuildContext context,
    ChatProvider chatProvider,
    ChatUser user,
  ) {
    final theme = Theme.of(context);
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

    final actionBackground = alreadyAdded
        ? Colors.white.withValues(alpha: 0.16)
        : pendingSent
        ? const Color(0xFFF2C267)
        : pendingReceived
        ? Colors.white
        : Colors.white;

    final actionForeground = alreadyAdded
        ? theme.colorScheme.onSurface
        : pendingSent
        ? const Color(0xFF5C3B00)
        : theme.colorScheme.primary;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 0,
        vertical: AppSpacing.sm,
      ),
          leading: _Avatar(
            avatarUrl: user.avatar,
            size: 44,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            iconColor: theme.colorScheme.onSurfaceVariant,
          ),
          title: Text(
            user.username.isNotEmpty ? user.username : user.email,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            pendingSent ? 'Request pending' : user.email,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.66),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: FilledButton.tonal(
            onPressed: () => _handleRelationshipAction(
              context,
              chatProvider,
              user,
              alreadyAdded: alreadyAdded,
              pendingSent: pendingSent,
              pendingReceived: pendingReceived,
            ),
            style: FilledButton.styleFrom(
              backgroundColor: actionBackground,
              foregroundColor: actionForeground,
              minimumSize: const Size(72, 32),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(actionLabel),
          ),
    );
  }

  Future<void> _handleRelationshipAction(
    BuildContext context,
    ChatProvider chatProvider,
    ChatUser user, {
    required bool alreadyAdded,
    required bool pendingSent,
    required bool pendingReceived,
  }) async {
    if (alreadyAdded) {
      final action = await _showFriendOptionsSheet(context, user);

      if (!context.mounted) return;

      if (action == 'remove') {
        final confirmed = await _showRemoveFriendConfirmSheet(context, user);
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
            builder: (_) => ChatConversationScreen(conversation: conversation),
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
          : chatProvider.findPendingReceivedRequestId(user.id);

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
            builder: (_) => ChatConversationScreen(conversation: conversation),
          ),
        );
      } else {
        showSuccessSnackBar(
          context,
          result.message.isNotEmpty ? result.message : 'Friend request sent',
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
  }

  Widget _buildRequestCard(BuildContext context, FriendRequestModel request) {
    final theme = Theme.of(context);
    final sender = request.sender;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        children: [
          Row(
            children: [
              _Avatar(
                avatarUrl: sender.avatar,
                size: 44,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                iconColor: theme.colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sender.username.isNotEmpty
                          ? sender.username
                          : sender.email,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(sender.email, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Request',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () async {
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
                  child: const Text('Accept'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConversationRow(
    BuildContext context,
    ChatConversation conversation,
  ) {
    final theme = Theme.of(context);
    final friend = conversation.friend;
    final lastMessage = conversation.lastMessage.isNotEmpty
        ? conversation.lastMessage
        : 'Start the conversation';

    return ListTile(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatConversationScreen(conversation: conversation),
          ),
        );
      },
      onLongPress: () => _handleRelationshipAction(
        context,
        context.read<ChatProvider>(),
        friend,
        alreadyAdded: true,
        pendingSent: false,
        pendingReceived: false,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 0,
        vertical: AppSpacing.sm,
      ),
      leading: _Avatar(
        avatarUrl: friend.avatar,
        size: 52,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        iconColor: theme.colorScheme.primary,
      ),
      title: Text(
        friend.username.isNotEmpty ? friend.username : friend.email,
        style: theme.textTheme.titleMedium,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          lastMessage,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium,
        ),
      ),
      trailing: Text(
        _formatTimestamp(conversation.lastMessageAt),
        style: theme.textTheme.bodyMedium,
      ),
    );
  }

  Widget _buildSentRequestRow(
    BuildContext context,
    FriendRequestModel request,
  ) {
    final activeFilter = context.read<ChatProvider>().requestStatusFilter;
    final theme = Theme.of(context);
    final receiver = request.receiver;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 0,
        vertical: AppSpacing.sm,
      ),
      leading: _Avatar(
        avatarUrl: receiver.avatar,
        size: 44,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        iconColor: theme.colorScheme.primary,
      ),
      title: Text(
        receiver.username.isNotEmpty ? receiver.username : receiver.email,
        style: theme.textTheme.titleMedium,
      ),
      subtitle: Text(
        activeFilter == FriendRequestStatusFilter.pending
            ? 'Pending approval'
            : receiver.email,
        style: theme.textTheme.bodyMedium,
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          _requestStatusLabelFromValue(request.status),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildRequestStatusRow(
    BuildContext context, {
    required ChatUser user,
    required String status,
    required String subtitle,
  }) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 0,
        vertical: AppSpacing.sm,
      ),
      leading: _Avatar(
        avatarUrl: user.avatar,
        size: 44,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        iconColor: theme.colorScheme.primary,
      ),
      title: Text(
        user.username.isNotEmpty ? user.username : user.email,
        style: theme.textTheme.titleMedium,
      ),
      subtitle: Text(subtitle, style: theme.textTheme.bodyMedium),
      trailing: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          _requestStatusLabelFromValue(status),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    String subtitle,
  ) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(subtitle, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubsectionLabel(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context, {
    required String title,
  }) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              color: theme.colorScheme.primary,
              size: 30,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(title, style: theme.textTheme.titleLarge),
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

  String _requestStatusLabel(FriendRequestStatusFilter status) {
    switch (status) {
      case FriendRequestStatusFilter.pending:
        return 'Pending';
      case FriendRequestStatusFilter.accepted:
        return 'Accepted';
      case FriendRequestStatusFilter.rejected:
        return 'Rejected';
    }
  }

  String _requestStatusLabelFromValue(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return 'Accepted';
      case 'rejected':
        return 'Rejected';
      case 'pending':
      default:
        return 'Pending';
    }
  }

  Future<String?> _showFriendOptionsSheet(BuildContext context, ChatUser user) {
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Avatar(
                avatarUrl: user.avatar,
                size: 72,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                iconColor: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                user.username.isNotEmpty ? user.username : user.email,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(user.email, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.lg),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                tileColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                leading: Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('Open chat'),
                subtitle: const Text('Continue your conversation'),
                onTap: () => Navigator.pop(context, 'chat'),
              ),
              const SizedBox(height: AppSpacing.sm),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                tileColor: AppColors.danger.withValues(alpha: 0.08),
                leading: const Icon(
                  Icons.person_remove_outlined,
                  color: AppColors.danger,
                ),
                title: const Text('Remove friend'),
                subtitle: const Text('Delete this friend connection'),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _showRespondToRequestSheet(
    BuildContext context,
    ChatUser user,
  ) {
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Avatar(
                avatarUrl: user.avatar,
                size: 72,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                iconColor: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                user.username.isNotEmpty ? user.username : user.email,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Respond to this friend request',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                tileColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                leading: Icon(
                  Icons.check_circle_outline_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('Accept'),
                subtitle: const Text('Add this user to your friends list'),
                onTap: () => Navigator.pop(context, 'accepted'),
              ),
              const SizedBox(height: AppSpacing.sm),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                tileColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                leading: const Icon(Icons.close_rounded),
                title: const Text('Dismiss'),
                subtitle: const Text('Reject this pending request'),
                onTap: () => Navigator.pop(context, 'rejected'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _showRemoveFriendConfirmSheet(
    BuildContext context,
    ChatUser user,
  ) {
    return showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_remove_outlined,
                  color: AppColors.danger,
                  size: 34,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Remove friend?',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'You will remove ${user.username.isNotEmpty ? user.username : user.email} from your friends list and delete your chat history.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.danger,
                      ),
                      child: const Text('Remove'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String avatarUrl;
  final double size;
  final Color backgroundColor;
  final Color iconColor;

  const _Avatar({
    required this.avatarUrl,
    required this.size,
    required this.backgroundColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: backgroundColor,
      backgroundImage: avatarUrl.isNotEmpty ? authImageProvider(avatarUrl) : null,
      child: avatarUrl.isEmpty
          ? Icon(Icons.person_rounded, color: iconColor)
          : null,
    );
  }
}
