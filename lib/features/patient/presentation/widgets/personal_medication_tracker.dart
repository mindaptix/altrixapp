import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme/app_colors.dart';
import '../../data/models/medication_model.dart';
import '../../data/models/personal_medication.dart';

Future<void> showAddPersonalMedicationSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _AddMedicationSheet(),
    );

class PersonalMedicationTracker extends ConsumerStatefulWidget {
  const PersonalMedicationTracker({super.key});
  @override
  ConsumerState<PersonalMedicationTracker> createState() =>
      _PersonalMedicationTrackerState();
}

class _PersonalMedicationTrackerState
    extends ConsumerState<PersonalMedicationTracker> {
  final _busy = <String>{};
  Future<void> _update(String id, Future<void> Function() action) async {
    if (_busy.contains(id)) return;
    setState(() => _busy.add(id));
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save your tracker update. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _remove(PersonalMedication medication) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove tracker entry?'),
        content: Text(
          'Remove ${medication.name} from your personal tracker? Your clinic prescription will not change.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _update(
        medication.id,
        () => ref
            .read(personalMedicationsProvider.notifier)
            .remove(medication.id),
      );
    }
  }

  Widget _card(PersonalMedication medication) {
    final color = Color(medication.color);
    final schedule = medication.schedule(DateTime.now());
    final busy = _busy.contains(medication.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: medication.active
              ? color.withValues(alpha: .25)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  medication.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Switch(
                value: medication.active,
                onChanged: busy
                    ? null
                    : (_) => _update(
                        medication.id,
                        () => ref
                            .read(personalMedicationsProvider.notifier)
                            .toggle(medication.id),
                      ),
                activeTrackColor: color,
              ),
            ],
          ),
          Text(
            '${medication.dosage} · ${medication.frequency}',
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
          if (medication.times.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '${medication.frequency == 'Weekly' ? '${_weekdays[medication.weekday - 1]} · ' : ''}${medication.times.join(', ')}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
          if (medication.instructions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                medication.instructions,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          if (medication.active) ...[
            const SizedBox(height: 12),
            if (medication.asNeeded) ...[
              if (medication.logDate ==
                  PersonalMedication.dayKey(DateTime.now()))
                Text(
                  '${medication.logs.length} dose ${medication.logs.length == 1 ? 'entry' : 'entries'} today',
                  style: const TextStyle(fontSize: 12),
                ),
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () {
                        final now = DateTime.now();
                        final time =
                            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${now.microsecond}';
                        _update(
                          medication.id,
                          () => ref
                              .read(personalMedicationsProvider.notifier)
                              .log(
                                medication.id,
                                time,
                                MedicationDoseStatus.taken,
                              ),
                        );
                      },
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Log dose taken'),
              ),
            ] else if (schedule.doseTimes.isEmpty)
              const Text(
                'No scheduled doses today.',
                style: TextStyle(color: AppColors.textSecondary),
              )
            else
              for (final time in schedule.doseTimes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Chip(
                        avatar: const Icon(Icons.schedule, size: 16),
                        label: Text(time),
                      ),
                      if (schedule.statusFor(time) ==
                          MedicationDoseStatus.pending) ...[
                        FilledButton(
                          onPressed: busy
                              ? null
                              : () => _update(
                                  medication.id,
                                  () => ref
                                      .read(
                                        personalMedicationsProvider.notifier,
                                      )
                                      .log(
                                        medication.id,
                                        time,
                                        MedicationDoseStatus.taken,
                                      ),
                                ),
                          style: FilledButton.styleFrom(backgroundColor: color),
                          child: const Text('Log dose'),
                        ),
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => _update(
                                  medication.id,
                                  () => ref
                                      .read(
                                        personalMedicationsProvider.notifier,
                                      )
                                      .log(
                                        medication.id,
                                        time,
                                        MedicationDoseStatus.skipped,
                                      ),
                                ),
                          child: const Text('Skip'),
                        ),
                      ] else
                        Text(
                          schedule.statusFor(time) == MedicationDoseStatus.taken
                              ? 'Taken today'
                              : 'Skipped today',
                          style: TextStyle(
                            color:
                                schedule.statusFor(time) ==
                                    MedicationDoseStatus.taken
                                ? const Color(0xFF059669)
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
          ],
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text(medication.name),
                    content: Text(
                      '${medication.dosage}\n${medication.frequency}\n${medication.times.join(', ')}\n\n${medication.instructions}\n\nPersonal tracker entry saved on this device.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
                icon: const Icon(Icons.info_outline, size: 17),
                label: const Text('Details'),
              ),
              TextButton.icon(
                onPressed: busy ? null : () => _remove(medication),
                icon: const Icon(Icons.delete_outline, size: 17),
                label: const Text('Remove entry'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 20),
      // const Text(
      //   'Personal medication tracker',
      //   style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
      // ),
      // const SizedBox(height: 6),
      // const Text(
      //   'Entries you add are saved on this device. Tracker switches do not change your prescribed treatment.',
      //   style: TextStyle(
      //     color: AppColors.textSecondary,
      //     fontSize: 13,
      //     height: 1.5,
      //   ),
      // ),
      const SizedBox(height: 12),
      // OutlinedButton.icon(
      //   onPressed: () => showAddPersonalMedicationSheet(context),
      //   icon: const Icon(Icons.add),
      //   label: const Text('Add medication'),
      // ),
      // const SizedBox(height: 14),
      ref
          .watch(personalMedicationsProvider)
          .when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => Column(
              children: [
                const Text('Could not load your personal tracker.'),
                TextButton(
                  onPressed: () => ref.invalidate(personalMedicationsProvider),
                  child: const Text('Retry tracker'),
                ),
              ],
            ),
            data: (items) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'No personal entries yet. Add medications you already take to keep a daily record.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                for (final item in items.where((item) => item.active))
                  _card(item),
                if (items.any((item) => !item.active))
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Inactive tracker entries',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                for (final item in items.where((item) => !item.active))
                  _card(item),
              ],
            ),
          ),
    ],
  );
}

const _frequencies = [
  'Once daily',
  'Twice daily',
  'Three times daily',
  'As needed',
  'Weekly',
];
const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const _colors = [
  0xFF6B63F0,
  0xFF059669,
  0xFFE8673A,
  0xFFBE185D,
  0xFF0277BD,
  0xFFA17C35,
];

class _AddMedicationSheet extends ConsumerStatefulWidget {
  const _AddMedicationSheet();
  @override
  ConsumerState<_AddMedicationSheet> createState() =>
      _AddMedicationSheetState();
}

class _AddMedicationSheetState extends ConsumerState<_AddMedicationSheet> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _dosage = TextEditingController(),
      _instructions = TextEditingController();
  String _frequency = 'Once daily';
  int _color = _colors.first, _weekday = DateTime.now().weekday;
  final _times = <TimeOfDay>[];
  bool _saving = false;
  String? _error;
  int get _requiredTimes => switch (_frequency) {
    'As needed' => 0,
    'Twice daily' => 2,
    'Three times daily' => 3,
    _ => 1,
  };
  @override
  void dispose() {
    _name.dispose();
    _dosage.dispose();
    _instructions.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_times.length != _requiredTimes) {
      setState(
        () => _error =
            'Choose $_requiredTimes dose time${_requiredTimes == 1 ? '' : 's'} for this schedule.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final times =
          _times
              .map(
                (time) =>
                    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
              )
              .toList()
            ..sort();
      await ref
          .read(personalMedicationsProvider.notifier)
          .add(
            PersonalMedication(
              id: 'personal-${DateTime.now().microsecondsSinceEpoch}',
              name: _name.text.trim(),
              dosage: _dosage.text.trim(),
              frequency: _frequency,
              times: times,
              instructions: _instructions.text.trim(),
              color: _color,
              weekday: _weekday,
            ),
          );
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Medication added to your personal tracker.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save this entry. Check that you are signed in and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      24,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Add medication',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter the medication and schedule you already follow. This creates a personal tracker entry, not a prescription.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _name,
              enabled: !_saving,
              maxLength: 100,
              decoration: const InputDecoration(labelText: 'Medication name'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a medication name'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _dosage,
              enabled: !_saving,
              maxLength: 100,
              decoration: const InputDecoration(labelText: 'Dosage'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter the dosage you already take'
                  : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _frequency,
              decoration: const InputDecoration(labelText: 'Frequency'),
              items: _frequencies
                  .map(
                    (item) => DropdownMenuItem(value: item, child: Text(item)),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (value) => setState(() {
                      _frequency = value!;
                      _times.clear();
                      _error = null;
                    }),
            ),
            if (_frequency == 'Weekly') ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _weekday,
                decoration: const InputDecoration(labelText: 'Day of the week'),
                items: [
                  for (var i = 0; i < 7; i++)
                    DropdownMenuItem(value: i + 1, child: Text(_weekdays[i])),
                ],
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _weekday = value!),
              ),
            ],
            if (_requiredTimes > 0) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final time in _times)
                    InputChip(
                      label: Text(time.format(context)),
                      onDeleted: _saving
                          ? null
                          : () => setState(() => _times.remove(time)),
                    ),
                  if (_times.length < _requiredTimes)
                    ActionChip(
                      label: const Text('Choose dose time'),
                      avatar: const Icon(Icons.schedule, size: 16),
                      onPressed: _saving
                          ? null
                          : () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.now(),
                              );
                              if (time != null &&
                                  mounted &&
                                  !_times.contains(time)) {
                                setState(() => _times.add(time));
                              }
                            },
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _instructions,
              enabled: !_saving,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Instructions (optional)',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var i = 0; i < _colors.length; i++)
                  Semantics(
                    label: 'Color ${i + 1}',
                    selected: _color == _colors[i],
                    button: true,
                    child: InkWell(
                      onTap: _saving
                          ? null
                          : () => setState(() => _color = _colors[i]),
                      borderRadius: BorderRadius.circular(30),
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: Color(_colors[i]),
                        child: _color == _colors[i]
                            ? const Icon(Icons.check, color: Colors.white)
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.badge),
                ),
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save to tracker'),
            ),
          ],
        ),
      ),
    ),
  );
}
