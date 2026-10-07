import 'package:flutter/material.dart';

import '../navigation/app_navigator.dart';
import '../../features/patient/presentation/screens/medications_screen.dart';
import '../../features/telehealth/presentation/screens/telehealth_room_screen.dart';
import '../../screens/conversation_detail_screen.dart';

/// Central router that translates FCM [data] payloads into screen navigations.
///
/// Called from two places:
///  1. [PushNotificationService._handleOpenedMessage] — user tapped the system
///     notification while the app was backgrounded / terminated.
///  2. [InAppNotificationOverlay._onMessage] — user tapped the in-app banner
///     while the app was in the foreground.
///
/// Navigation types are determined by data['type']:
///
/// | type                   | destination                           |
/// |------------------------|---------------------------------------|
/// | medication_reminder    | MedicationsScreen (push route)        |
/// | appointment_reminder   | Schedule tab (index 1)                |
/// | chat_message           | Messages tab (index 2) or conv detail |
/// | telehealth_call        | TelehealthRoomScreen (push route)     |
class NotificationRouter {
  NotificationRouter._();

  /// Optional callback registered by [MainShell] to switch bottom-nav tabs.
  static ValueSetter<int>? _switchTabCallback;
  static VoidCallback? _refreshAppointmentsCallback;

  static void registerTabSwitcher(ValueSetter<int> callback) {
    _switchTabCallback = callback;
  }

  static void unregisterTabSwitcher() {
    _switchTabCallback = null;
  }

  static void registerAppointmentRefresher(VoidCallback callback) {
    _refreshAppointmentsCallback = callback;
  }

  static void unregisterAppointmentRefresher() {
    _refreshAppointmentsCallback = null;
  }

  /// Refresh schedule data as soon as an appointment-related push arrives,
  /// even if the patient does not tap the foreground banner.
  static void handleReceived(Map<String, dynamic> data) {
    final type = (data['type'] as String? ?? '').trim();
    if (type == 'appointment_reminder' || type == 'telehealth_call') {
      _refreshAppointmentsCallback?.call();
    }
  }

  static bool _ready = false;
  static Map<String, dynamic>? _pending;
  static void markReady() {
    _ready = true;
    final pending = _pending;
    _pending = null;
    if (pending != null) handleTap(pending);
  }

  /// Main entry point — handles a push notification [data] map.
  static void handleTap(Map<String, dynamic> data) {
    final type = (data['type'] as String? ?? '').trim();
    final nav = rootNavigatorKey.currentState;
    if (nav == null || !_ready) {
      _pending = Map<String, dynamic>.from(data);
      return;
    }

    handleReceived(data);

    debugPrint('[NotificationRouter] handling type="$type"');

    switch (type) {
      case 'medication_reminder':
        nav.push(
          MaterialPageRoute<void>(
            builder: (_) => const MedicationsScreen(),
            settings: const RouteSettings(name: '/medications'),
          ),
        );

      case 'appointment_reminder':
        // Bring Schedule tab to front (no extra route pushed).
        _switchTabCallback?.call(1);

      case 'chat_message':
        final threadId = (data['threadId'] as String? ?? '').trim();
        if (threadId.isNotEmpty) {
          // Switch to messages tab and push the conversation detail.
          _switchTabCallback?.call(2);
          nav.push(
            MaterialPageRoute<void>(
              builder: (_) => ConversationDetailScreen(
                conversationId: threadId,
                title: 'Messages',
              ),
              settings: RouteSettings(name: '/chat/$threadId'),
            ),
          );
        } else {
          _switchTabCallback?.call(2);
        }

      case 'telehealth_call':
        final joinToken = (data['joinToken'] as String? ?? '').trim();
        if (joinToken.isNotEmpty) {
          nav.push(
            MaterialPageRoute<void>(
              builder: (_) => TelehealthRoomScreen(joinToken: joinToken),
              settings: const RouteSettings(name: '/telehealth/waiting-room'),
            ),
          );
        }

      default:
        debugPrint(
          '[NotificationRouter] Unknown notification type: "$type" — ignoring.',
        );
    }
  }
}
