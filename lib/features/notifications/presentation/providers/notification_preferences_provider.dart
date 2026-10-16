import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/notification_preferences_store.dart';
import '../../domain/notification_preferences.dart';

final notificationPreferencesProvider =
    NotifierProvider<NotificationPreferencesNotifier, NotificationPreferences>(
      NotificationPreferencesNotifier.new,
    );

class NotificationPreferencesNotifier
    extends Notifier<NotificationPreferences> {
  late NotificationPreferencesStore _store;

  @override
  NotificationPreferences build() {
    _store = NotificationPreferencesStore(ref.watch(sharedPreferencesProvider));
    return _store.load();
  }

  Future<void> update(
    NotificationPreferences Function(NotificationPreferences current) update,
  ) async {
    final next = update(state);
    state = next;
    await _store.save(next);
  }
}
