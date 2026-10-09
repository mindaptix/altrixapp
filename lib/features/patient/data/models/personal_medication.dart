import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import 'medication_model.dart';

class PersonalMedication {
  const PersonalMedication({
    required this.id,
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.times,
    this.instructions = '',
    this.color = 0xFF6B63F0,
    this.active = true,
    this.weekday = 1,
    this.logDate = '',
    this.logs = const {},
  });
  final String id, name, dosage, frequency, instructions, logDate;
  final List<String> times;
  final int color, weekday;
  final bool active;
  final Map<String, String> logs;

  static String dayKey(DateTime now) => '${now.year}-${now.month}-${now.day}';
  bool get asNeeded => frequency == 'As needed';
  MedicationScheduleModel schedule(DateTime now) => MedicationScheduleModel(
    id: id,
    medicationName: name,
    dosage: dosage,
    instructions: instructions,
    doseTimes: asNeeded || (frequency == 'Weekly' && weekday != now.weekday)
        ? []
        : times,
    startDate: '',
    endDate: '',
    isActive: active,
    todayLogs: logDate == dayKey(now)
        ? logs.entries
              .map(
                (entry) => MedicationDoseLog(
                  doseTime: entry.key,
                  status: entry.value == 'taken'
                      ? MedicationDoseStatus.taken
                      : MedicationDoseStatus.skipped,
                ),
              )
              .toList()
        : [],
  );
  PersonalMedication copyWith({
    bool? active,
    String? logDate,
    Map<String, String>? logs,
  }) => PersonalMedication(
    id: id,
    name: name,
    dosage: dosage,
    frequency: frequency,
    times: times,
    instructions: instructions,
    color: color,
    active: active ?? this.active,
    weekday: weekday,
    logDate: logDate ?? this.logDate,
    logs: logs ?? this.logs,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'dosage': dosage,
    'frequency': frequency,
    'times': times,
    'instructions': instructions,
    'color': color,
    'active': active,
    'weekday': weekday,
    'logDate': logDate,
    'logs': logs,
  };
  factory PersonalMedication.fromJson(Map<String, dynamic> json) =>
      PersonalMedication(
        id: json['id'] as String,
        name: json['name'] as String,
        dosage: json['dosage'] as String,
        frequency: json['frequency'] as String,
        times: List<String>.from(json['times'] as List),
        instructions: json['instructions'] as String? ?? '',
        color: json['color'] as int? ?? 0xFF6B63F0,
        active: json['active'] as bool? ?? true,
        weekday: json['weekday'] as int? ?? 1,
        logDate: json['logDate'] as String? ?? '',
        logs: Map<String, String>.from(json['logs'] as Map? ?? {}),
      );
}

class PersonalMedicationStore {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  Future<List<PersonalMedication>> load(String userId) async {
    final raw = await _storage.read(key: 'personal_medications_$userId');
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map(
          (item) => PersonalMedication.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<void> save(String userId, List<PersonalMedication> items) =>
      _storage.write(
        key: 'personal_medications_$userId',
        value: jsonEncode(items.map((item) => item.toJson()).toList()),
      );
}

final personalMedicationStoreProvider = Provider<PersonalMedicationStore>(
  (ref) => PersonalMedicationStore(),
);
final personalMedicationsProvider =
    AsyncNotifierProvider<
      PersonalMedicationsNotifier,
      List<PersonalMedication>
    >(PersonalMedicationsNotifier.new);

class PersonalMedicationsNotifier
    extends AsyncNotifier<List<PersonalMedication>> {
  @override
  Future<List<PersonalMedication>> build() {
    final userId = ref.watch(authProvider.select((state) => state.user?.id));
    if (userId == null || userId.isEmpty) return Future.value([]);
    return ref.watch(personalMedicationStoreProvider).load(userId);
  }

  bool _saving = false;
  Future<void> _update(
    List<PersonalMedication> Function(List<PersonalMedication>) update,
  ) async {
    if (_saving) throw StateError('An update is already in progress.');
    final userId = ref.read(authProvider).user?.id;
    if (userId == null || userId.isEmpty) {
      throw StateError('Please sign in before saving medications.');
    }
    if (!state.hasValue) {
      throw StateError('Medication tracker is still loading.');
    }
    _saving = true;
    try {
      final next = update(state.requireValue);
      await ref.read(personalMedicationStoreProvider).save(userId, next);
      if (ref.read(authProvider).user?.id == userId) state = AsyncData(next);
    } finally {
      _saving = false;
    }
  }

  Future<void> add(PersonalMedication item) =>
      _update((items) => [item, ...items]);
  Future<void> toggle(String id) => _update(
    (items) => items
        .map(
          (item) => item.id == id ? item.copyWith(active: !item.active) : item,
        )
        .toList(),
  );
  Future<void> remove(String id) =>
      _update((items) => items.where((item) => item.id != id).toList());
  Future<void> log(
    String id,
    String time,
    MedicationDoseStatus status, {
    DateTime? now,
  }) => _update((items) {
    final today = PersonalMedication.dayKey(now ?? DateTime.now());
    return items
        .map(
          (item) => item.id == id
              ? item.copyWith(
                  logDate: today,
                  logs: {
                    ...(item.logDate == today ? item.logs : <String, String>{}),
                    time: status.name,
                  },
                )
              : item,
        )
        .toList();
  });
}
