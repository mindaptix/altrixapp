import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../patient/data/models/patient_models.dart';
import '../../../patient/presentation/providers/patient_providers.dart';

String notificationItemKey(DashboardItem item) =>
    '${item.title}|${item.body}|${item.time}';

final readNotificationKeysProvider =
    NotifierProvider<ReadNotificationKeys, Set<String>>(
      ReadNotificationKeys.new,
    );

class ReadNotificationKeys extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    ref.watch(authProvider.select((state) => state.user?.id));
    return {};
  }

  void markRead(DashboardItem item) {
    state = {...state, notificationItemKey(item)};
  }

  void markAllRead(List<DashboardItem> items) {
    state = {...state, ...items.map(notificationItemKey)};
  }
}

final unreadNotificationCountProvider = Provider<int>((ref) {
  final dashboard = ref.watch(dashboardProvider).valueOrNull;
  if (dashboard == null) return 0;
  final read = ref.watch(readNotificationKeysProvider);
  final unique = {
    for (final item in [...dashboard.notifications, ...dashboard.reminders])
      notificationItemKey(item): item,
  };
  final unread = unique.values.where((item) => item.isUnread).toList();
  final baseline = math.max(dashboard.unreadNotifications, unread.length);
  final locallyRead = unread
      .where((item) => read.contains(notificationItemKey(item)))
      .length;
  return math.max(0, baseline - locallyRead);
});
