import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/responsive/responsive.dart';
import '../../../../core/responsive/responsive_widgets.dart';
import '../../../../theme/app_colors.dart';
import '../../../../widgets/empty_state_card.dart';
import '../../data/models/patient_models.dart';
import '../providers/patient_providers.dart';

// Matches the patient API's APPOINTMENT_TYPES contract.
const patientAppointmentTypes = [
  'Individual Therapy',
  'Group Therapy',
  'Medication Review',
  'Initial Assessment',
  'Crisis Follow-up',
  'Telehealth Check-in',
  'Psychiatric Evaluation',
  'Medication Management',
  'PRP Session',
  'Telehealth',
  'Initial Evaluation',
];

Future<void> openAppointmentEditor(
  BuildContext context, {
  AppointmentModel? appointment,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final saved = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => AppointmentEditorScreen(appointment: appointment),
    ),
  );
  if (saved == true && messenger.mounted) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          appointment == null
              ? 'Appointment requested. Check your schedule for updates.'
              : 'Reschedule requested. Check your schedule for updates.',
        ),
      ),
    );
  }
}

String _dateValue(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class AppointmentEditorScreen extends ConsumerStatefulWidget {
  const AppointmentEditorScreen({super.key, this.appointment});
  final AppointmentModel? appointment;

  @override
  ConsumerState<AppointmentEditorScreen> createState() =>
      _AppointmentEditorScreenState();
}

class _AppointmentEditorScreenState
    extends ConsumerState<AppointmentEditorScreen> {
  final _note = TextEditingController();
  String? _doctorId;
  String _type = patientAppointmentTypes.first;
  bool _virtual = false;
  late DateTime _date;
  AvailabilitySlotModel? _slot;
  bool _saving = false;
  String? _error;

  bool get _rescheduling => widget.appointment != null;
  bool get _requiresVideo => _type.toLowerCase().contains('telehealth');
  AppointmentSlotQuery? get _query => _doctorId == null || _doctorId!.isEmpty
      ? null
      : (doctorId: _doctorId!, date: _dateValue(_date));

  @override
  void initState() {
    super.initState();
    final now = DateUtils.dateOnly(DateTime.now());
    final appointment = widget.appointment;
    final original = appointment?.sortDateTime;
    _date = original != null && original.isAfter(now)
        ? DateUtils.dateOnly(original)
        : now;
    _doctorId = appointment?.clinicianId;
    if (appointment != null) {
      _type = appointment.title;
      _virtual = appointment.isVirtual;
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final initial = _date.isBefore(today) ? today : _date;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: DateTime(initial.year + 1, 12, 31),
    );
    if (picked != null && mounted) {
      setState(() {
        _date = picked;
        _slot = null;
        _error = null;
      });
    }
  }

  Future<void> _save() async {
    final slot = _slot;
    final query = _query;
    if (_saving || slot == null || query == null) return;
    // A refreshed response may have removed the selected slot.
    final current = ref.read(appointmentSlotsProvider(query)).valueOrNull;
    if (current == null || !current.contains(slot)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repository = ref.read(patientRepositoryProvider);
      if (_rescheduling) {
        await repository.rescheduleAppointment(
          id: widget.appointment!.id,
          date: slot.date,
          startTime: slot.startTime,
          endTime: slot.endTime,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        );
      } else {
        await repository.bookAppointment(
          clinicianId: query.doctorId,
          type: _type,
          date: slot.date,
          startTime: slot.startTime,
          endTime: slot.endTime,
          isVirtual: _virtual || _requiresVideo,
        );
      }
      if (!mounted) return;
      ref.invalidate(appointmentsProvider);
      ref.invalidate(dashboardProvider);
      ref.invalidate(appointmentSlotsProvider);
      ref.invalidate(doctorAvailabilityProvider);
      // Rebuild PopScope before popping after the request finishes.
      setState(() => _saving = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop(true);
      });
    } catch (error) {
      if (!mounted) return;
      final conflict =
          error is ApiException &&
          (error.statusCode == 409 || error.code == 'SLOT_UNAVAILABLE');
      setState(() {
        _saving = false;
        _error = conflict
            ? 'That time is no longer available. Please choose another slot.'
            : error is ApiException
            ? error.message
            : 'Could not save your appointment. Please try again.';
        if (conflict) _slot = null;
      });
      if (conflict) ref.invalidate(appointmentSlotsProvider(query));
    }
  }

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final query = _query;
    final slots = query == null
        ? null
        : ref.watch(appointmentSlotsProvider(query));
    final selectedIsAvailable =
        _slot != null &&
        slots?.isLoading == false &&
        slots?.hasError == false &&
        (slots?.valueOrNull?.contains(_slot) ?? false);
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _rescheduling ? 'Reschedule appointment' : 'Book appointment',
          ),
        ),
        body: SafeArea(
          child: ResponsiveFormContainer(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: responsive.pagePadding.copyWith(
                top: responsive.rz(16),
                bottom: responsive.rz(32),
              ),
              children: [
                Text(
                  _rescheduling
                      ? 'Choose a new time for your visit'
                      : 'Plan your next visit',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Dates and times are shown as provided by your clinic.',
                ),
                const SizedBox(height: 24),
                if (_rescheduling) ...[
                  Text(
                    '${widget.appointment!.title}\n${widget.appointment!.providerName}\nCurrent visit: ${widget.appointment!.displayWhen}',
                  ),
                  const SizedBox(height: 16),
                  if (query == null)
                    const EmptyStateCard(
                      title: 'Contact your care team',
                      message: 'This appointment has no assigned clinician. Please message your clinic to reschedule.',
                    ),
                ] else ...[
                  ref
                      .watch(doctorsProvider)
                      .when(
                        loading: () => const InlineLoadingCard(),
                        error: (error, _) => InlineErrorCard(
                          message: error is ApiException
                              ? error.message
                              : 'Could not load clinicians.',
                          onRetry: () => ref.invalidate(doctorsProvider),
                        ),
                        data: (doctors) => doctors.isEmpty
                            ? const EmptyStateCard(
                                title: 'No clinicians available',
                                message: 'Please contact your clinic to arrange a visit.',
                              )
                            : DropdownButtonFormField<String>(
                                key: ValueKey('doctor-$_doctorId'),
                                initialValue:
                                    doctors.any(
                                      (doctor) => doctor.id == _doctorId,
                                    )
                                    ? _doctorId
                                    : null,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Clinician',
                                ),
                                items: doctors
                                    .map(
                                      (doctor) => DropdownMenuItem(
                                        value: doctor.id,
                                        child: Text(
                                          doctor.name,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: _saving
                                    ? null
                                    : (value) => setState(() {
                                        _doctorId = value;
                                        _slot = null;
                                        _error = null;
                                      }),
                              ),
                      ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    initialValue: _type,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Appointment type',
                    ),
                    items: patientAppointmentTypes
                        .map(
                          (type) =>
                              DropdownMenuItem(value: type, child: Text(type)),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _type = value!),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Virtual Video visit'),
                    subtitle: Text(
                      _requiresVideo
                          ? 'This appointment type automatically generates an in-app Zoom video room.'
                          : (_virtual
                                ? 'A secure Zoom telehealth meeting link will be generated for in-app calling.'
                                : 'Turn off for an in-person visit.'),
                    ),
                    value: _virtual || _requiresVideo,
                    onChanged: _saving || _requiresVideo
                        ? null
                        : (value) => setState(() => _virtual = value),
                  ),
                  if (_virtual || _requiresVideo) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D8CFF).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF2D8CFF)
                              .withValues(alpha: 0.28),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.videocam_rounded,
                            color: Color(0xFF2D8CFF),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'In-App Zoom Video Meeting',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF2D8CFF),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Conducted directly inside the app with camera, mic, and live controls.',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _pickDate,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(
                    MaterialLocalizations.of(context).formatMediumDate(_date),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Available times',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (slots == null && !_rescheduling)
                  const Text('Select a clinician to see available times.'),
                if (slots != null)
                  slots.when(
                    skipLoadingOnRefresh: false,
                    loading: () => const InlineLoadingCard(),
                    error: (error, _) => InlineErrorCard(
                      message: error is ApiException
                          ? error.message
                          : 'Could not load available times.',
                      onRetry: () {
                        setState(() => _slot = null);
                        ref.invalidate(appointmentSlotsProvider(query!));
                      },
                    ),
                    data: (available) => available.isEmpty
                        ? const EmptyStateCard(
                            title: 'No available times',
                            message: 'Choose another date or contact your clinic for help.',
                          )
                        : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: available
                                .map(
                                  (slot) => ChoiceChip(
                                    label: Text(
                                      '${slot.startTime} – ${slot.endTime}',
                                    ),
                                    selected: identical(_slot, slot),
                                    onSelected: _saving
                                        ? null
                                        : (selected) => setState(() {
                                            _slot = selected ? slot : null;
                                            _error = null;
                                          }),
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                if (_rescheduling) ...[
                  const SizedBox(height: 20),
                  TextField(
                    controller: _note,
                    enabled: !_saving,
                    maxLength: 500,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Reason (optional)',
                    ),
                  ),
                ],
                if (selectedIsAvailable) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Selected: ${_slot!.date}, ${_slot!.startTime} – ${_slot!.endTime}',
                  ),
                  Text(
                    _rescheduling
                        ? 'Your clinician and visit type will stay the same.'
                        : '$_type · ${_virtual || _requiresVideo ? "Virtual Video visit (Zoom link generated)" : "In-person visit"}',
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _saving || !selectedIsAvailable ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.event_available_outlined),
                  label: Text(
                    _saving
                        ? 'Saving…'
                        : _rescheduling
                        ? 'Request reschedule'
                        : 'Request appointment',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
