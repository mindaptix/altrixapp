import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../patient/presentation/providers/patient_providers.dart';

typedef NotificationReadRequest = Future<void> Function(String id);

final notificationReadRequestProvider = Provider<NotificationReadRequest>((
  ref,
) {
  final repository = ref.watch(patientRepositoryProvider);
  return repository.markNotificationRead;
});

@immutable
class NotificationReadState {
  const NotificationReadState({
    this.locallyReadIds = const <String>{},
    this.processingIds = const <String>{},
  });

  final Set<String> locallyReadIds;
  final Set<String> processingIds;

  NotificationReadState copyWith({
    Set<String>? locallyReadIds,
    Set<String>? processingIds,
  }) {
    return NotificationReadState(
      locallyReadIds: locallyReadIds ?? this.locallyReadIds,
      processingIds: processingIds ?? this.processingIds,
    );
  }
}

/// Keeps notification taps responsive and prevents duplicate mark-read calls.
///
/// Read state is deliberately kept in memory. The server remains the source of
/// truth after the next provider refresh or app launch.
class NotificationReadController extends Notifier<NotificationReadState> {
  @override
  NotificationReadState build() {
    ref.watch(authProvider.select((value) => value.user?.id));
    return const NotificationReadState();
  }

  bool isLocallyRead(String id) => state.locallyReadIds.contains(id);

  void markAllLocally(Iterable<String> ids) {
    final validIds = ids.where((id) => id.trim().isNotEmpty);
    state = state.copyWith(
      locallyReadIds: {...state.locallyReadIds, ...validIds},
    );
  }

  Future<void> markRead(String id) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty ||
        state.locallyReadIds.contains(normalizedId) ||
        state.processingIds.contains(normalizedId)) {
      return;
    }

    // Optimistically update the interface before starting the request.
    state = state.copyWith(
      locallyReadIds: {...state.locallyReadIds, normalizedId},
      processingIds: {...state.processingIds, normalizedId},
    );

    try {
      await ref.read(notificationReadRequestProvider)(normalizedId);
    } catch (_) {
      // Keep this deliberately sanitized: request details and auth data must
      // never be written to logs. A failed read receipt must not block routing.
      debugPrint(
        '[Notifications] Mark-read request failed; continuing locally.',
      );
    } finally {
      state = state.copyWith(
        processingIds: state.processingIds
            .where((value) => value != normalizedId)
            .toSet(),
      );
    }
  }
}

final notificationReadControllerProvider =
    NotifierProvider<NotificationReadController, NotificationReadState>(
      NotificationReadController.new,
    );
