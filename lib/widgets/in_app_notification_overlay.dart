import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/notification_router.dart';
import '../../features/notifications/presentation/providers/push_notification_provider.dart';
import '../../theme/app_colors.dart';
import '../../features/patient/presentation/providers/patient_providers.dart';

/// Wraps the app body and shows a floating in-app banner when a push
/// notification arrives while the app is in the foreground.
///
/// Usage: wrap MainShell (or any top-level widget) with this.
class InAppNotificationOverlay extends ConsumerStatefulWidget {
  const InAppNotificationOverlay({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<InAppNotificationOverlay> createState() =>
      _InAppNotificationOverlayState();
}

class _InAppNotificationOverlayState
    extends ConsumerState<InAppNotificationOverlay>
    with SingleTickerProviderStateMixin {
  StreamSubscription<RemoteMessage>? _sub;

  late final AnimationController _animCtrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  _NotifData? _current;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _fade = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));

    WidgetsBinding.instance.addPostFrameCallback((_) => _startListening());
  }

  void _startListening() {
    final service = ref.read(pushNotificationServiceProvider);
    _sub = service.onForegroundMessage.listen(_onMessage);
  }

  void _onMessage(RemoteMessage message) {
    NotificationRouter.handleReceived(message.data);
    ref.invalidate(dashboardProvider);
    final title =
        message.notification?.title ??
        message.data['title'] as String? ??
        'New notification';
    final body =
        message.notification?.body ?? message.data['body'] as String? ?? '';

    if (!mounted) return;
    setState(() {
      _current = _NotifData(title: title, body: body, data: message.data);
    });

    _animCtrl.forward(from: 0);
    _dismissTimer?.cancel();
    _dismissTimer = Timer(const Duration(seconds: 5), _dismiss);
  }

  void _dismiss() {
    _animCtrl.reverse().then((_) {
      if (mounted) setState(() => _current = null);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _dismissTimer?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_current != null)
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: _NotificationBanner(
                    data: _current!,
                    onDismiss: _dismiss,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _NotifData {
  const _NotifData({
    required this.title,
    required this.body,
    required this.data,
  });

  final String title;
  final String body;
  final Map<String, dynamic> data;
}

class _NotificationBanner extends StatelessWidget {
  const _NotificationBanner({required this.data, required this.onDismiss});

  final _NotifData data;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.navy,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.28),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: InkWell(
            onTap: () {
              onDismiss();
              NotificationRouter.handleTap(data.data);
            },
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  // Icon badge
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.notifications_rounded,
                        color: AppColors.primarySoft,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Text content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          data.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (data.body.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            data.body,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textOnDarkMuted,
                              height: 1.35,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(width: 6),
                  // Dismiss X
                  GestureDetector(
                    onTap: onDismiss,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: AppColors.textOnDarkMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
