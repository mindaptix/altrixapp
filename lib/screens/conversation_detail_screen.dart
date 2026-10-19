import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/auth/presentation/providers/auth_token_provider.dart';
import '../features/patient/data/models/patient_models.dart';
import '../features/patient/data/services/chat_socket_service.dart';
import '../features/patient/presentation/providers/chat_messages_provider.dart';
import '../features/patient/presentation/providers/patient_providers.dart';
import '../features/patient/presentation/providers/presence_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/empty_state_card.dart';

class ConversationDetailScreen extends ConsumerStatefulWidget {
  const ConversationDetailScreen({
    super.key,
    required this.conversationId,
    required this.title,
    this.participantName = '',
    this.avatarUrl = '',
  });

  final String conversationId;
  final String title;
  final String participantName;
  final String avatarUrl;

  @override
  ConsumerState<ConversationDetailScreen> createState() =>
      ConversationDetailScreenState();
}

class ConversationDetailScreenState
    extends ConsumerState<ConversationDetailScreen>
    with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  late final ChatSocketService _socketService;
  StreamSubscription<MessageModel>? _messageSub;
  StreamSubscription<bool>? _typingSub;
  StreamSubscription<String>? _presenceSub;
  StreamSubscription<Map<String, dynamic>>? _sseSub;
  Timer? _livePollTimer;
  Timer? _typingDebounceTimer;

  bool _isLoading = true;
  String? _error;
  bool _isSending = false;
  bool _isDoctorTyping = false;
  late String _threadId;

  // Track if user is near the bottom so we only auto-scroll when appropriate
  bool _userIsNearBottom = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _threadId = widget.conversationId;
    _socketService = ChatSocketService();

    _scrollController.addListener(_onScroll);
    if (_threadId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref
              .read(localReadConversationsProvider.notifier)
              .markAsRead(_threadId);
        }
      });
    }
    _initChat();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sseSub?.cancel();
    _livePollTimer?.cancel();
    _messageSub?.cancel();
    _typingSub?.cancel();
    _presenceSub?.cancel();
    _typingDebounceTimer?.cancel();
    _socketService.dispose();
    _controller.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Reconnect the socket when the app comes back from background —
  /// like WhatsApp/Instagram that reconnect instantly on foreground.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _socketService.reconnectIfNeeded();
      // Also do a quick poll to catch any messages sent while in background
      _pollLiveMessages();
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    // With reverse: true, 0.0 is the bottom (latest messages)
    _userIsNearBottom = pos.pixels < 120;
  }

  void _initChat() async {
    // If we already have messages cached, show them immediately (no loading
    // spinner on re-entry — WhatsApp-like instant history)
    final cached = ref.read(chatMessagesProvider(_threadId));
    if (cached.isNotEmpty) {
      setState(() => _isLoading = false);
      _scrollToBottomImmediate();
    }

    await _fetchInitialMessages();
    _startLiveSync();
    _connectSocket();
  }

  void _startLiveSync() async {
    _sseSub?.cancel();
    _livePollTimer?.cancel();

    if (_threadId.isEmpty) return;

    String? token;
    try {
      token = ref.read(authTokenProvider);
      if (token == null || token.isEmpty) {
        token = await ref.read(authSessionStorageProvider).readToken();
      }
    } catch (_) {
      token = null;
    }

    if (token != null && token.isNotEmpty) {
      try {
        _sseSub = ref
            .read(patientRepositoryProvider)
            .streamLiveMessages(threadId: _threadId, token: token)
            .listen(
              (payload) {
                if (!mounted) return;
                // Any SSE activity means the server (clinician side) is live
                ref
                    .read(clinicianPresenceProvider(_threadId).notifier)
                    .markOnline();
                final messageMap = payload['message'] is Map<String, dynamic>
                    ? payload['message'] as Map<String, dynamic>
                    : (payload['data'] is Map<String, dynamic>
                          ? payload['data'] as Map<String, dynamic>
                          : payload);
                if (messageMap['id'] != null) {
                  final incoming = MessageModel.fromJson(messageMap);
                  _mergeMessages([incoming], isFromRealtime: true);
                }
              },
              onError: (_) {},
              cancelOnError: false,
            );
      } catch (_) {}
    }

    // Fallback poll every 5s in case socket drops (still much faster than 10s)
    _livePollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _threadId.isEmpty) return;
      _pollLiveMessages();
    });
  }

  Future<void> _pollLiveMessages() async {
    try {
      final messages = await ref
          .read(patientRepositoryProvider)
          .getConversationMessages(conversationId: _threadId);
      if (!mounted) return;
      // Poll updates silently — only scroll if user is near bottom
      _mergeMessages(messages, isFromRealtime: false);
    } catch (_) {}
  }

  Future<void> _fetchInitialMessages() async {
    final cached = ref.read(chatMessagesProvider(_threadId));
    if (cached.isEmpty) {
      // Only show loading indicator when there's nothing to show
      if (mounted)
        setState(() {
          _isLoading = true;
          _error = null;
        });
    }

    try {
      final result = await ref
          .read(patientRepositoryProvider)
          .getPatientMessages(
            threadId: _threadId.isNotEmpty ? _threadId : null,
          );
      if (!mounted) return;
      if (result.threadId.isNotEmpty) {
        _threadId = result.threadId;
        ref.read(localReadConversationsProvider.notifier).markAsRead(_threadId);
      }
      ref
          .read(chatMessagesProvider(_threadId).notifier)
          .seedIfEmpty(result.messages);
      if (mounted) {
        setState(() => _isLoading = false);
      }
      _scrollToBottom(force: true);
      _markIncomingAsRead(result.messages);
    } catch (err) {
      try {
        if (_threadId.isNotEmpty) {
          final messages = await ref
              .read(patientRepositoryProvider)
              .getConversationMessages(conversationId: _threadId);
          if (!mounted) return;
          ref
              .read(chatMessagesProvider(_threadId).notifier)
              .seedIfEmpty(messages);
          if (mounted) setState(() => _isLoading = false);
          _scrollToBottom(force: true);
          _markIncomingAsRead(messages);
        } else {
          if (!mounted) return;
          setState(() => _isLoading = false);
        }
      } catch (innerErr) {
        if (!mounted) return;
        // Only show error if we have no cached messages
        final cached2 = ref.read(chatMessagesProvider(_threadId));
        setState(() {
          if (cached2.isEmpty) _error = friendlyErrorMessage(err);
          _isLoading = false;
        });
      }
    }
  }

  void _connectSocket() async {
    final user = ref.read(authProvider).user;
    final patientId =
        user?.id ?? 'patient_${DateTime.now().millisecondsSinceEpoch}';
    final patientName = user?.name ?? 'Patient';

    String? token;
    try {
      token = ref.read(authTokenProvider);
      if (token == null || token.isEmpty) {
        token = await ref.read(authSessionStorageProvider).readToken();
      }
    } catch (_) {
      token = null;
    }

    _socketService.connectSocket(
      patientId: patientId,
      patientName: patientName,
      threadId: _threadId,
      token: token,
    );

    _messageSub?.cancel();
    _messageSub = _socketService.onNewMessage.listen((incoming) {
      if (!mounted) return;
      // Socket message means clinician side is active
      ref.read(clinicianPresenceProvider(_threadId).notifier).markOnline();
      _mergeMessages([incoming], isFromRealtime: true);
    });

    _typingSub?.cancel();
    _typingSub = _socketService.onTypingStatus.listen((isTyping) {
      if (!mounted) return;
      setState(() => _isDoctorTyping = isTyping);
      if (isTyping) {
        // Typing means clinician is online
        ref.read(clinicianPresenceProvider(_threadId).notifier).markOnline();
      }
      if (isTyping && _userIsNearBottom) {
        _scrollToBottom();
      }
    });

    _presenceSub?.cancel();
    _presenceSub = _socketService.onPresenceChange.listen((status) {
      if (!mounted) return;
      final notifier = ref.read(clinicianPresenceProvider(_threadId).notifier);
      if (status == 'online') {
        notifier.markOnline();
      } else {
        notifier.markOffline();
      }
    });
  }

  void _onTextChanged(String text) {
    final user = ref.read(authProvider).user;
    final patientId = user?.id ?? 'patient';
    final patientName = user?.name ?? 'Patient';

    if (text.trim().isNotEmpty) {
      _socketService.sendTypingStart(_threadId, patientId, patientName);
      _typingDebounceTimer?.cancel();
      _typingDebounceTimer = Timer(const Duration(milliseconds: 2000), () {
        _socketService.sendTypingStop(_threadId, patientId, patientName);
      });
    } else {
      _socketService.sendTypingStop(_threadId, patientId, patientName);
    }
  }

  /// Smart merge — delegates to the StateNotifier.
  /// [isFromRealtime] = true means a new message arrived (SSE/socket), so we
  /// should scroll. false = background poll, only scroll if user is at bottom.
  void _mergeMessages(
    List<MessageModel> incoming, {
    required bool isFromRealtime,
  }) {
    final changed = ref
        .read(chatMessagesProvider(_threadId).notifier)
        .merge(incoming);

    if (changed) {
      _markIncomingAsRead(incoming);
      if (isFromRealtime || _userIsNearBottom) {
        _scrollToBottom();
      }
    }
  }

  void _markIncomingAsRead(List<MessageModel> messages) {
    final user = ref.read(authProvider).user;
    final currentUserId = user?.id;
    final currentUserName = user?.name;

    for (final message in messages) {
      if (!message.isFromMe(
        currentUserId: currentUserId,
        currentUserName: currentUserName,
      )) {
        ref
            .read(patientRepositoryProvider)
            .markMessageRead(message.id)
            .catchError((_) {});
      }
    }
  }

  /// Scroll to bottom (latest message) after the current frame renders.
  /// [force] = true scrolls even if user is not near bottom.
  void _scrollToBottom({bool force = false}) {
    if (!force && !_userIsNearBottom) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  /// Jump to bottom (latest message) immediately without animation.
  void _scrollToBottomImmediate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0.0);
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    final user = ref.read(authProvider).user;
    final currentUserId = user?.id ?? 'patient';
    final currentUserName = user?.name ?? 'You';

    _typingDebounceTimer?.cancel();
    _socketService.sendTypingStop(_threadId, currentUserId, currentUserName);

    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final optimistic = MessageModel(
      id: tempId,
      threadId: _threadId,
      body: text,
      sender: 'patient',
      senderName: currentUserName,
      createdAt: DateTime.now().toIso8601String(),
      isRead: true,
      isPending: true,
      raw: {'senderId': currentUserId},
    );

    // Add optimistic message instantly to provider (survives navigation)
    ref
        .read(chatMessagesProvider(_threadId).notifier)
        .addOptimistic(optimistic);
    _controller.clear();
    setState(() => _isSending = true);
    // Always scroll when user sends a message
    _userIsNearBottom = true;
    _scrollToBottom(force: true);

    try {
      MessageModel confirmed;
      try {
        confirmed = await ref
            .read(patientRepositoryProvider)
            .sendMessage(conversationId: _threadId, message: text);
      } catch (_) {
        confirmed = await ref
            .read(patientRepositoryProvider)
            .sendPatientMessage(content: text, threadId: _threadId);
      }

      if (!mounted) return;
      ref
          .read(chatMessagesProvider(_threadId).notifier)
          .confirmMessage(tempId, confirmed);
      setState(() => _isSending = false);

      // Emit via socket so the server can broadcast to the clinician instantly.
      // This is a fire-and-forget signal on top of the REST persistence.
      _socketService.emitMessage(
        threadId: _threadId,
        message: text,
        senderId: currentUserId,
        senderName: currentUserName,
        tempId: tempId,
      );

      // Invalidate conversations list so lastMessage updates immediately
      ref.invalidate(conversationsProvider);
    } catch (err) {
      if (!mounted) return;
      ref.read(chatMessagesProvider(_threadId).notifier).failMessage(tempId);
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyErrorMessage(err)),
          backgroundColor: AppColors.badge,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _participantInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'CT';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : 'C';
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final currentUserId = user?.id;
    final currentUserName = user?.name;
    final displayName = widget.participantName.isNotEmpty
        ? widget.participantName
        : widget.title;
    final initials = _participantInitials(displayName);

    // Watch live messages from the provider — updates trigger rebuild
    final messages = ref.watch(chatMessagesProvider(_threadId));

    // Watch clinician presence — true = online (green dot), false = offline
    final clinicianIsOnline = ref.watch(clinicianPresenceProvider(_threadId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: AppColors.textPrimary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            // Participant Avatar Icon with live presence indicator
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primaryWash,
                        AppColors.primary.withValues(alpha: 0.2),
                      ],
                    ),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: clinicianIsOnline
                          ? const Color(0xFF10B981)
                          : const Color(0xFF94A3B8),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      _LiveDotSmall(
                        color: _isDoctorTyping
                            ? const Color(0xFF6366F1)
                            : (clinicianIsOnline
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF94A3B8)),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          _isDoctorTyping
                              ? 'Doctor is typing...'
                              : (clinicianIsOnline
                                    ? 'Online · End-to-end encrypted'
                                    : 'Offline · End-to-end encrypted'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: _isDoctorTyping
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: _isDoctorTyping
                                ? AppColors.primary
                                : (clinicianIsOnline
                                      ? const Color(0xFF059669)
                                      : AppColors.textTertiary),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // HIPAA Security Note Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.primaryWash.withValues(alpha: 0.6),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield_outlined, size: 14, color: AppColors.primary),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Messages are end-to-end encrypted & HIPAA compliant',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Active Chat Messages List
          Expanded(
            child: _isLoading && messages.isEmpty
                ? const Center(
                    child: InlineLoadingCard(label: 'Loading live messages...'),
                  )
                : _error != null && messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: InlineErrorCard(
                        message: _error!,
                        onRetry: _fetchInitialMessages,
                      ),
                    ),
                  )
                : messages.isEmpty && !_isDoctorTyping
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: EmptyStateCard(
                        title: 'Start a conversation',
                        message: 'Send your care team a secure real-time message below.',
                        icon: Icons.chat_rounded,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                    itemCount: messages.length + (_isDoctorTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      // With reverse: true, index 0 is at the very bottom
                      if (_isDoctorTyping && index == 0) {
                        return _DoctorTypingBubble(
                          doctorName: displayName,
                          doctorInitials: initials,
                        );
                      }
                      // Map reversed index to chronological list (0=oldest, length-1=newest)
                      final msgIndex = _isDoctorTyping
                          ? (messages.length - index)
                          : (messages.length - 1 - index);

                      if (msgIndex < 0 || msgIndex >= messages.length) {
                        return const SizedBox.shrink();
                      }

                      final message = messages[msgIndex];
                      final isMe = message.isFromMe(
                        currentUserId: currentUserId,
                        currentUserName: currentUserName,
                      );
                      final showDate =
                          msgIndex == 0 ||
                          _shouldShowDateDivider(
                            messages[msgIndex - 1],
                            message,
                          );

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (showDate)
                            _DateDivider(dateStr: message.createdAt),
                          _ChatMessageBubble(
                            message: message,
                            isMe: isMe,
                            participantInitials: initials,
                            participantName: displayName,
                          ),
                        ],
                      );
                    },
                  ),
          ),
          // Bottom Message Input Bar — WhatsApp-style
          _InputBar(
            controller: _controller,
            focusNode: _focusNode,
            isSending: _isSending,
            onChanged: (v) {
              _onTextChanged(v);
              setState(() {});
            },
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }

  bool _shouldShowDateDivider(MessageModel prev, MessageModel curr) {
    final prevDt = prev.dateTime;
    final currDt = curr.dateTime;
    if (prevDt == null || currDt == null) return false;
    return prevDt.year != currDt.year ||
        prevDt.month != currDt.month ||
        prevDt.day != currDt.day;
  }
}

class _ChatMessageBubble extends StatelessWidget {
  const _ChatMessageBubble({
    required this.message,
    required this.isMe,
    required this.participantInitials,
    required this.participantName,
  });

  final MessageModel message;
  final bool isMe;
  final String participantInitials;
  final String participantName;

  @override
  Widget build(BuildContext context) {
    final timeStr = message.displayTime;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Clinician avatar (left side only)
          if (!isMe)
            Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.only(right: 8, bottom: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryWash,
                    AppColors.primary.withValues(alpha: 0.2),
                  ],
                ),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Center(
                child: Text(
                  participantInitials,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),

          // Message bubble
          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                // Sender name (clinician only)
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 3),
                    child: Text(
                      message.senderName.isNotEmpty
                          ? message.senderName
                          : participantName,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),

                // Bubble
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: isMe ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: isMe
                          ? const Radius.circular(18)
                          : const Radius.circular(4),
                      bottomRight: isMe
                          ? const Radius.circular(4)
                          : const Radius.circular(18),
                    ),
                    border: isMe ? null : Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: (isMe ? AppColors.primary : AppColors.navy)
                            .withValues(alpha: isMe ? 0.18 : 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    child: Column(
                      crossAxisAlignment: isMe
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          message.body,
                          style: TextStyle(
                            fontSize: 14.5,
                            height: 1.38,
                            color: isMe ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              timeStr.isNotEmpty ? timeStr : '--:--',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: isMe
                                    ? Colors.white.withValues(alpha: 0.72)
                                    : AppColors.textTertiary,
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 4),
                              if (message.isPending)
                                SizedBox(
                                  width: 10,
                                  height: 10,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: Colors.white.withValues(alpha: 0.72),
                                  ),
                                )
                              else if (message.hasError)
                                const Icon(
                                  Icons.error_outline_rounded,
                                  size: 12,
                                  color: Colors.amberAccent,
                                )
                              else
                                Icon(
                                  message.isRead
                                      ? Icons.done_all_rounded
                                      : Icons.done_rounded,
                                  size: 13,
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.dateStr});

  final String dateStr;

  String _formatDate() {
    final dt = DateTime.tryParse(dateStr)?.toLocal();
    if (dt == null) return '';
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'Today';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.year == yesterday.year &&
        dt.month == yesterday.month &&
        dt.day == yesterday.day) {
      return 'Yesterday';
    }
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    final text = _formatDate();
    if (text.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveDotSmall extends StatelessWidget {
  const _LiveDotSmall({this.color = const Color(0xFF10B981)});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _DoctorTypingBubble extends StatefulWidget {
  const _DoctorTypingBubble({
    required this.doctorName,
    required this.doctorInitials,
  });

  final String doctorName;
  final String doctorInitials;

  @override
  State<_DoctorTypingBubble> createState() => _DoctorTypingBubbleState();
}

class _DoctorTypingBubbleState extends State<_DoctorTypingBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 8, bottom: 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryWash,
                  AppColors.primary.withValues(alpha: 0.2),
                ],
              ),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Center(
              child: Text(
                widget.doctorInitials,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(18),
              ),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: AppColors.navy.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                const SizedBox(width: 4),
                _buildDot(0.2),
                const SizedBox(width: 4),
                _buildDot(0.4),
                const SizedBox(width: 8),
                Text(
                  widget.doctorName.isNotEmpty
                      ? '${widget.doctorName.split(' ').first} is typing...'
                      : 'Doctor is typing...',
                  style: const TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(double delay) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        final progress = (_animController.value - delay) % 1.0;
        final opacity = (0.3 + 0.7 * (1.0 - (progress - 0.5).abs() * 2)).clamp(
          0.1,
          1.0,
        );
        return Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: opacity),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}

/// Standalone input bar widget — tracks its own focus state so the parent
/// does not need to rebuild the entire screen for border animation.
class _InputBar extends StatefulWidget {
  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.isSending,
    required this.onChanged,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSending;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() => setState(() {});

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  bool get _hasText => widget.controller.text.trim().isNotEmpty;
  bool get _focused => widget.focusNode.hasFocus;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Text field with rounded border
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(26),
                  // border: Border.all(
                  //   color: _focused
                  //       ? AppColors.primary.withValues(alpha: 0.45)
                  //       : AppColors.border,
                  //   width: _focused ? 1.5 : 1.0,
                  // ),
                  // boxShadow: _focused
                  //     ? [
                  //         BoxShadow(
                  //           color: AppColors.primary.withValues(alpha: 0.07),
                  //           blurRadius: 6,
                  //           spreadRadius: 0,
                  //         ),
                  //       ]
                  //     : null,
                ),
                // padding: const EdgeInsets.symmetric(
                //   horizontal: 16,
                //   vertical: 2,
                // ),
                child: TextField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  maxLines: 5,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(fontSize: 15, height: 1.4),
                  decoration: const InputDecoration(
                    hintText: 'Message...',
                    hintStyle: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 15,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: widget.onChanged,
                  onSubmitted: (_) => widget.onSend(),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Animated send button
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _hasText ? AppColors.primary : AppColors.border,
                shape: BoxShape.circle,
                boxShadow: _hasText
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.32),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: _hasText ? widget.onSend : null,
                  customBorder: const CircleBorder(),
                  child: Center(
                    child: widget.isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
