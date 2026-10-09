import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/responsive/responsive.dart';
import '../core/responsive/responsive_widgets.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/patient/data/models/patient_models.dart';
import '../features/patient/presentation/providers/patient_providers.dart';
import '../theme/app_colors.dart';
import '../widgets/empty_state_card.dart';
import 'conversation_detail_screen.dart';

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'U';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : 'U';
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final user = ref.watch(authProvider).user;
    final userName = user?.name.trim() ?? '';
    final conversationsAsync = ref.watch(conversationsProvider);
    final localReadIds = ref.watch(localReadConversationsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ResponsiveCenter(
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(conversationsProvider),
            child: ListView(
              padding: responsive.pagePadding.copyWith(
                top: responsive.rz(12),
                bottom: responsive.rz(32),
              ),
              children: [
                // Top Header with User Name & Profile Icon
                _UserHeader(
                  userName: userName,
                  initials: _initials(userName),
                  avatarUrl: user?.avatarUrl ?? '',
                ),
                SizedBox(height: responsive.rz(18)),

                conversationsAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: InlineLoadingCard(
                        label: 'Connecting to live messages...',
                      ),
                    ),
                  ),
                  error: (error, _) => InlineErrorCard(
                    message: friendlyErrorMessage(error),
                    onRetry: () => ref.invalidate(conversationsProvider),
                  ),
                  data: (conversations) {
                    // Apply local-read override: zero unread for conversations
                    // the user has opened this session (optimistic clear).
                    final effectiveConversations = conversations.map((c) {
                      if (localReadIds.contains(c.id)) {
                        return ConversationModel(
                          id: c.id,
                          title: c.title,
                          preview: c.preview,
                          lastMessageAt: c.lastMessageAt,
                          unreadCount: 0,
                          topic: c.topic,
                          avatarUrl: c.avatarUrl,
                          participantName: c.participantName,
                          participantRole: c.participantRole,
                          raw: c.raw,
                        );
                      }
                      return c;
                    }).toList();
                    final unreadCount = effectiveConversations.fold<int>(
                      0,
                      (sum, c) => sum + c.unreadCount,
                    );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _MessagesStatsRow(
                          totalThreads: conversations.length,
                          unreadTotal: unreadCount,
                        ),
                        SizedBox(height: responsive.rz(22)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Recent conversations',
                                style: responsiveTextStyle(
                                  context,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF10B981)
                                      .withValues(alpha: 0.25),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _LiveStatusDot(),
                                  SizedBox(width: 5),
                                  Text(
                                    'Realtime',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF059669),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: responsive.rz(14)),
                        if (conversations.isNotEmpty) ...[
                          for (final conversation in effectiveConversations)
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: responsive.rz(10),
                              ),
                              child: ConversationTile(
                                conversation: conversation,
                                // We don't have real clinician presence on the list
                                // screen — only show dot inside the chat.
                                isOnline: false,
                                onTap: () => _openThread(context, conversation),
                              ),
                            ),
                        ] else ...[
                          const EmptyStateCard(
                            title: 'No chats',
                            message: 'No chats available. When your care team or clinician sends you a message, it will appear here.',
                            icon: Icons.chat_bubble_outline_rounded,
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openThread(BuildContext context, ConversationModel conversation) {
    // Mark as locally-read immediately (zeroes badge before API refresh)
    ref
        .read(localReadConversationsProvider.notifier)
        .update((s) => {...s, conversation.id});
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => ConversationDetailScreen(
              conversationId: conversation.id,
              title: conversation.effectiveName,
              participantName: conversation.effectiveName,
            ),
          ),
        )
        // Refresh the conversations list when the user comes back so
        // the unread badge reflects real server state.
        .then((_) => ref.invalidate(conversationsProvider));
  }
}

class _UserHeader extends StatelessWidget {
  const _UserHeader({
    required this.userName,
    required this.initials,
    this.avatarUrl = '',
  });

  final String userName;
  final String initials;
  final String avatarUrl;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final displayName = userName.isNotEmpty ? userName : 'Patient';

    return Container(
      padding: EdgeInsets.all(responsive.rz(16)),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(responsive.rz(20)),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Profile Avatar Icon with online indicator
          _HeaderProfileAvatar(initials: initials, avatarUrl: avatarUrl),
          SizedBox(width: responsive.rz(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Flexible(
                      child: Text(
                        'Live Secure Chat',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: responsiveTextStyle(
                    context,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Encrypted HIPAA communication',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryWash,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.15),
              ),
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              size: 16,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderProfileAvatar extends StatelessWidget {
  const _HeaderProfileAvatar({required this.initials, this.avatarUrl = ''});

  final String initials;
  final String avatarUrl;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final size = responsive.rz(48);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF9B93F8), AppColors.primary],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.28),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipOval(
            child: avatarUrl.isNotEmpty
                ? Image.network(
                    avatarUrl,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Center(
                      child: Text(
                        initials,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: responsive.rz(16),
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      initials,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: responsive.rz(16),
                      ),
                    ),
                  ),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: responsive.rz(14),
            height: responsive.rz(14),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _MessagesStatsRow extends StatelessWidget {
  const _MessagesStatsRow({
    required this.totalThreads,
    required this.unreadTotal,
  });

  final int totalThreads;
  final int unreadTotal;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: '$totalThreads conversations',
            icon: Icons.forum_rounded,
            highlight: false,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: unreadTotal > 0 ? '$unreadTotal unread' : 'All caught up',
            icon: unreadTotal > 0
                ? Icons.mark_email_unread_rounded
                : Icons.done_all_rounded,
            highlight: unreadTotal > 0,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.icon,
    required this.highlight,
  });

  final String label;
  final IconData icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: highlight ? AppColors.primaryWash : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight
              ? AppColors.primary.withValues(alpha: 0.28)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: highlight ? AppColors.primary : AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: highlight ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ConversationTile extends StatelessWidget {
  const ConversationTile({
    super.key,
    required this.conversation,
    required this.onTap,
    this.isOnline = false,
  });

  final ConversationModel conversation;
  final VoidCallback onTap;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final hasUnread = conversation.unreadCount > 0;
    final timeStr = conversation.displayTime;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: hasUnread
                  ? AppColors.primary.withValues(alpha: 0.35)
                  : AppColors.border,
              width: hasUnread ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              // Care Team / Clinician Profile Avatar Icon
              _ParticipantAvatar(
                conversation: conversation,
                isOnline: isOnline,
              ),
              const SizedBox(width: 14),
              // Message details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            conversation.effectiveName,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: hasUnread
                                  ? FontWeight.w800
                                  : FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (timeStr.isNotEmpty)
                          Text(
                            timeStr,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: hasUnread
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: hasUnread
                                  ? AppColors.primary
                                  : AppColors.textTertiary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.preview.isNotEmpty
                                ? conversation.preview
                                : 'Tap to start conversation',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: hasUnread
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: hasUnread
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                        if (hasUnread) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${conversation.unreadCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParticipantAvatar extends StatelessWidget {
  const _ParticipantAvatar({required this.conversation, this.isOnline = false});

  final ConversationModel conversation;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primaryWash,
                AppColors.primary.withValues(alpha: 0.15),
              ],
            ),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.25),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              conversation.initials,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
        ),
        // WhatsApp-style presence dot: only shown when online
        if (isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 2.5),
              ),
            ),
          ),
      ],
    );
  }
}

class _LiveStatusDot extends StatelessWidget {
  const _LiveStatusDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        color: Color(0xFF10B981),
        shape: BoxShape.circle,
      ),
    );
  }
}
