import 'dart:async';

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
  static ValueSetter<String>? _markReadCallback;
  static ValueSetter<String>? _telehealthTapCallback;
  static VoidCallback? _refreshNotificationDataCallback;
  static final Set<String> _openConversationIds = <String>{};
  static final Map<String, DateTime> _recentTaps = <String, DateTime>{};
  static Widget Function(NotificationChatTarget target)? _chatScreenBuilder;

  static const Set<String> _chatTypes = {
    'message',
    'chat',
    'chat_message',
    'new_message',
    'care_team_message',
    'clinician_message',
  };

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

  static void registerNotificationReadHandler(ValueSetter<String> callback) {
    _markReadCallback = callback;
  }

  static void unregisterNotificationReadHandler() {
    _markReadCallback = null;
  }

  static void registerTelehealthTapHandler(ValueSetter<String> callback) {
    _telehealthTapCallback = callback;
  }

  static void unregisterTelehealthTapHandler() {
    _telehealthTapCallback = null;
  }

  static void registerNotificationDataRefresher(VoidCallback callback) {
    _refreshNotificationDataCallback = callback;
  }

  static void unregisterNotificationDataRefresher() {
    _refreshNotificationDataCallback = null;
  }

  /// Refresh schedule data as soon as an appointment-related push arrives,
  /// even if the patient does not tap the foreground banner.
  static void handleReceived(Map<String, dynamic> data) {
    final payload = _flattenPayload(data);
    final type = _readString(payload, const ['type']).toLowerCase();
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
    final payload = _flattenPayload(data);
    final type = _readString(payload, const ['type']).toLowerCase();
    final nav = rootNavigatorKey.currentState;
    if (nav == null || !_ready) {
      _pending = payload;
      return;
    }

    final fingerprint = _tapFingerprint(payload);
    final now = DateTime.now();
    _recentTaps.removeWhere(
      (_, timestamp) => now.difference(timestamp) > const Duration(seconds: 2),
    );
    if (_recentTaps.containsKey(fingerprint)) return;
    _recentTaps[fingerprint] = now;

    final notificationId = _readString(payload, const [
      'notificationId',
      'notification_id',
      'id',
      '_id',
    ]);
    if (notificationId.isNotEmpty) {
      try {
        _markReadCallback?.call(notificationId);
      } catch (_) {
        debugPrint('[NotificationRouter] Mark-read callback failed.');
      }
    }

    handleReceived(payload);

    debugPrint('[NotificationRouter] handling type="$type"');

    if (isChatNotification(payload)) {
      _openChatNotification(nav, payload);
      return;
    }

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

      case 'telehealth_call':
        final joinToken = _readString(payload, const ['joinToken']);
        if (joinToken.isNotEmpty) {
          final handler = _telehealthTapCallback;
          if (handler != null) {
            handler(joinToken);
          } else {
            nav.push(
              MaterialPageRoute<void>(
                builder: (_) => TelehealthRoomScreen(joinToken: joinToken),
                settings: const RouteSettings(name: '/telehealth/waiting-room'),
              ),
            );
          }
        }

      default:
        debugPrint(
          '[NotificationRouter] Unknown notification type: "$type" — ignoring.',
        );
    }
  }

  static bool isChatNotification(Map<String, dynamic> data) {
    final payload = _flattenPayload(data);
    final type = _readString(payload, const ['type']).toLowerCase();
    return _chatTypes.contains(type) || conversationIdFrom(payload).isNotEmpty;
  }

  static String conversationIdFrom(Map<String, dynamic> data) {
    return _readString(_flattenPayload(data), const [
      'conversationId',
      'conversation_id',
      'threadId',
      'thread_id',
      'chatId',
      'chat_id',
    ]);
  }

  static void _openChatNotification(
    NavigatorState nav,
    Map<String, dynamic> data,
  ) {
    _switchTabCallback?.call(2);
    final conversationId = conversationIdFrom(data);
    if (conversationId.isEmpty ||
        _openConversationIds.contains(conversationId)) {
      return;
    }

    final participantName = _readString(data, const [
      'participantName',
      'participant_name',
      'senderName',
      'sender_name',
      'clinicianName',
      'clinician_name',
      'doctorName',
      'doctor_name',
    ]);
    final notificationTitle = _readString(data, const ['title', 'subject']);
    final title = notificationTitle.isNotEmpty
        ? notificationTitle
        : participantName.isNotEmpty
        ? participantName
        : 'Messages';
    final avatarUrl = _readString(data, const [
      'avatarUrl',
      'avatar_url',
      'participantAvatarUrl',
      'participant_avatar_url',
      'senderAvatarUrl',
      'sender_avatar_url',
    ]);
    final target = NotificationChatTarget(
      conversationId: conversationId,
      participantName: participantName,
      title: title,
      avatarUrl: avatarUrl,
    );

    _openConversationIds.add(conversationId);
    unawaited(
      nav
          .push<void>(
            MaterialPageRoute<void>(
              builder: (_) =>
                  _chatScreenBuilder?.call(target) ??
                  ConversationDetailScreen(
                    conversationId: target.conversationId,
                    participantName: target.participantName,
                    title: target.title,
                    avatarUrl: target.avatarUrl,
                  ),
              settings: RouteSettings(name: '/chat/$conversationId'),
            ),
          )
          .whenComplete(() {
            _openConversationIds.remove(conversationId);
            _refreshNotificationDataCallback?.call();
          }),
    );
  }

  static Map<String, dynamic> _flattenPayload(Map<String, dynamic> data) {
    final nested = data['data'];
    if (nested is Map) {
      return <String, dynamic>{
        ...data,
        ...nested.map((key, value) => MapEntry(key.toString(), value)),
      };
    }
    return Map<String, dynamic>.from(data);
  }

  static String _readString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return '';
  }

  static String _tapFingerprint(Map<String, dynamic> data) {
    final notificationId = _readString(data, const [
      'notificationId',
      'notification_id',
      'id',
      '_id',
    ]);
    if (notificationId.isNotEmpty) return 'notification:$notificationId';
    final conversationId = conversationIdFrom(data);
    if (conversationId.isNotEmpty) return 'conversation:$conversationId';
    return 'type:${_readString(data, const ['type'])}:${data.hashCode}';
  }

  @visibleForTesting
  static void setChatScreenBuilderForTesting(
    Widget Function(NotificationChatTarget target)? builder,
  ) {
    _chatScreenBuilder = builder;
  }

  @visibleForTesting
  static void resetForTesting() {
    _ready = false;
    _pending = null;
    _switchTabCallback = null;
    _refreshAppointmentsCallback = null;
    _markReadCallback = null;
    _telehealthTapCallback = null;
    _refreshNotificationDataCallback = null;
    _openConversationIds.clear();
    _recentTaps.clear();
    _chatScreenBuilder = null;
  }
}

@immutable
class NotificationChatTarget {
  const NotificationChatTarget({
    required this.conversationId,
    required this.participantName,
    required this.title,
    required this.avatarUrl,
  });

  final String conversationId;
  final String participantName;
  final String title;
  final String avatarUrl;
}
