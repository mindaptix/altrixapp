import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/network/dio_client.dart';
import '../../data/datasources/patient_remote_datasource.dart';
import '../../data/models/medication_model.dart';
import '../../data/models/patient_models.dart';
import '../../data/repositories/patient_repository.dart';
import '../../data/services/chat_socket_service.dart';

final chatSocketServiceProvider = Provider.autoDispose<ChatSocketService>((
  ref,
) {
  final service = ChatSocketService();
  ref.onDispose(() => service.dispose());
  return service;
});

final patientRemoteDataSourceProvider = Provider<PatientRemoteDataSource>((
  ref,
) {
  return PatientRemoteDataSource(ref.watch(dioProvider));
});

final patientRepositoryProvider = Provider<PatientRepository>((ref) {
  return PatientRepository(ref.watch(patientRemoteDataSourceProvider));
});

final patientMessagesProvider = FutureProvider.autoDispose
    .family<({String threadId, List<MessageModel> messages}), String?>((
      ref,
      threadId,
    ) async {
      return ref
          .watch(patientRepositoryProvider)
          .getPatientMessages(threadId: threadId);
    });

final dashboardProvider = FutureProvider<DashboardModel>((ref) async {
  return ref.watch(patientRepositoryProvider).getDashboard();
});

final patientNotificationsProvider = FutureProvider<PatientNotificationPage>((
  ref,
) async {
  ref.watch(authProvider.select((state) => state.user?.id));
  return ref.watch(patientRepositoryProvider).getNotifications();
});

final appointmentsProvider = FutureProvider.autoDispose<List<AppointmentModel>>(
  (ref) async {
    return ref.watch(patientRepositoryProvider).getAppointments();
  },
);

final doctorsProvider = FutureProvider.autoDispose<List<DoctorModel>>((
  ref,
) async {
  return ref.watch(patientRepositoryProvider).getDoctors();
});

final conversationsProvider =
    FutureProvider.autoDispose<List<ConversationModel>>((ref) async {
      return ref.watch(patientRepositoryProvider).getConversations();
    });

class LocalReadConversationsNotifier extends StateNotifier<Set<String>> {
  LocalReadConversationsNotifier(this._prefs)
    : super((_prefs?.getStringList(_key) ?? []).toSet());

  static const _key = 'local_read_conversations';
  final SharedPreferences? _prefs;

  void markAsRead(String conversationId) {
    if (conversationId.isEmpty || state.contains(conversationId)) return;
    final updated = {...state, conversationId};
    state = updated;
    _prefs?.setStringList(_key, updated.toList());
  }

  void update(Set<String> Function(Set<String>) fn) {
    final updated = fn(state);
    state = updated;
    _prefs?.setStringList(_key, updated.toList());
  }

  void markAsUnread(String conversationId) {
    if (!state.contains(conversationId)) return;
    final updated = state.where((id) => id != conversationId).toSet();
    state = updated;
    _prefs?.setStringList(_key, updated.toList());
  }

  void clear() {
    state = {};
    _prefs?.remove(_key);
  }
}

/// Tracks conversation IDs the user has opened.
/// Stored persistently in SharedPreferences so it survives hot restarts and app relaunches.
final localReadConversationsProvider =
    StateNotifierProvider<LocalReadConversationsNotifier, Set<String>>((ref) {
      SharedPreferences? prefs;
      try {
        prefs = ref.watch(sharedPreferencesProvider);
      } catch (_) {
        prefs = null;
      }
      return LocalReadConversationsNotifier(prefs);
    });

final checkInsProvider = FutureProvider.autoDispose<List<CheckInModel>>((
  ref,
) async {
  return ref.watch(patientRepositoryProvider).getCheckIns(limit: 10);
});

final progressProvider = FutureProvider<ProgressModel>((ref) async {
  return ref.watch(patientRepositoryProvider).getProgress();
});

final invitePreviewProvider = FutureProvider.autoDispose
    .family<InvitePreviewModel, String>((ref, token) async {
      return ref.watch(patientRepositoryProvider).previewInvite(token);
    });

final conversationMessagesProvider = FutureProvider.autoDispose
    .family<List<MessageModel>, String>((ref, conversationId) async {
      return ref
          .watch(patientRepositoryProvider)
          .getConversationMessages(conversationId: conversationId);
    });

final doctorAvailabilityProvider = FutureProvider.autoDispose
    .family<List<AvailabilitySlotModel>, String>((ref, doctorId) async {
      return ref
          .watch(patientRepositoryProvider)
          .getDoctorAvailability(doctorId: doctorId);
    });

typedef AppointmentSlotQuery = ({String doctorId, String date});

final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

bool isSlotInFuture(AvailabilitySlotModel slot, DateTime now) {
  final slotDateParts = slot.date.split('-');
  final slotTimeParts = slot.startTime.split(':');
  if (slotDateParts.length == 3 && slotTimeParts.length == 2) {
    final y = int.tryParse(slotDateParts[0]);
    final m = int.tryParse(slotDateParts[1]);
    final d = int.tryParse(slotDateParts[2]);
    final hour = int.tryParse(slotTimeParts[0]);
    final min = int.tryParse(slotTimeParts[1]);
    if (y != null && m != null && d != null && hour != null && min != null) {
      final slotDateTime = DateTime(y, m, d, hour, min);
      return slotDateTime.isAfter(now);
    }
  }
  return true;
}

final appointmentSlotsProvider = FutureProvider.autoDispose
    .family<List<AvailabilitySlotModel>, AppointmentSlotQuery>((
      ref,
      query,
    ) async {
      final slots = await ref
          .watch(patientRepositoryProvider)
          .getDoctorAvailability(
            doctorId: query.doctorId,
            from: query.date,
            days: 1,
          );
      final now = ref.watch(clockProvider)();
      return slots
          .where(
            (slot) =>
                slot.date == query.date &&
                slot.isAvailable &&
                RegExp(r'^\d{2}:\d{2}$').hasMatch(slot.startTime) &&
                RegExp(r'^\d{2}:\d{2}$').hasMatch(slot.endTime) &&
                slot.endTime.compareTo(slot.startTime) > 0 &&
                isSlotInFuture(slot, now),
          )
          .toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
    });

final telehealthSessionProvider = FutureProvider.autoDispose
    .family<TelehealthSessionModel, String>((ref, joinToken) async {
      return ref
          .watch(patientRepositoryProvider)
          .getTelehealthSession(joinToken);
    });

final formsProvider = FutureProvider.autoDispose<List<PatientFormModel>>((
  ref,
) async {
  return ref.watch(patientRepositoryProvider).getForms();
});

final formDetailProvider = FutureProvider.autoDispose
    .family<PatientFormModel, String>((ref, id) async {
      return ref.watch(patientRepositoryProvider).getForm(id);
    });

// ---------------------------------------------------------------------------
// Medications
// ---------------------------------------------------------------------------

/// Async notifier that manages the list of medication schedules and handles
/// optimistic dose-intake logging.
class MedicationsNotifier extends AsyncNotifier<List<MedicationScheduleModel>> {
  @override
  Future<List<MedicationScheduleModel>> build() async {
    return ref.watch(patientRepositoryProvider).getMedications();
  }

  /// Optimistically marks a dose as taken/skipped, then persists to backend.
  /// On error it reverts to the previous state.
  Future<void> logIntake({
    required String scheduleId,
    required String doseTime,
    required MedicationDoseStatus status,
  }) async {
    // Snapshot current state for rollback.
    final previous = state;

    // Optimistic update.
    state = AsyncData(
      (state.valueOrNull ?? []).map((med) {
        if (med.id != scheduleId) return med;
        return med.withUpdatedLog(doseTime, status);
      }).toList(),
    );

    try {
      await ref
          .read(patientRepositoryProvider)
          .logMedicationIntake(
            scheduleId: scheduleId,
            doseTime: doseTime,
            status: status.name, // 'taken' | 'skipped'
          );
      // Refresh from server to get authoritative state.
      state = await AsyncValue.guard(
        () => ref.read(patientRepositoryProvider).getMedications(),
      );
    } catch (e) {
      // Revert optimistic update on error.
      state = previous;
      // Re-throw so UI can show an error message.
      rethrow;
    }
  }
}

final medicationsProvider =
    AsyncNotifierProvider<MedicationsNotifier, List<MedicationScheduleModel>>(
      MedicationsNotifier.new,
    );
