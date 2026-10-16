import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../data/models/patient_models.dart';
import '../providers/patient_providers.dart';
import '../screens/appointment_editor_screen.dart';

class AppointmentManagementActions extends StatelessWidget {
  const AppointmentManagementActions({super.key, required this.appointment});
  final AppointmentModel appointment;

  @override
  Widget build(BuildContext context) {
    if (!appointment.canManage) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 12,
        children: [
          OutlinedButton.icon(
            onPressed: () =>
                openAppointmentEditor(context, appointment: appointment),
            icon: const Icon(Icons.edit_calendar_outlined, size: 18),
            label: const Text('Reschedule'),
          ),
          TextButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final cancelled = await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (_) =>
                    _CancelAppointmentDialog(appointment: appointment),
              );
              if (cancelled == true && messenger.mounted) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Appointment cancelled.')),
                );
              }
            },
            child: const Text('Cancel appointment'),
          ),
        ],
      ),
    );
  }
}

class _CancelAppointmentDialog extends ConsumerStatefulWidget {
  const _CancelAppointmentDialog({required this.appointment});
  final AppointmentModel appointment;
  @override
  ConsumerState<_CancelAppointmentDialog> createState() =>
      _CancelAppointmentDialogState();
}

class _CancelAppointmentDialogState
    extends ConsumerState<_CancelAppointmentDialog> {
  final _reasonController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _cancel() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(patientRepositoryProvider)
          .cancelAppointment(
            widget.appointment.id,
            reason: _reasonController.text,
          );
      if (!mounted) return;
      ref.invalidate(appointmentsProvider);
      ref.invalidate(dashboardProvider);
      ref.invalidate(appointmentSlotsProvider);
      ref.invalidate(doctorAvailabilityProvider);
      setState(() => _saving = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop(true);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error is ApiException
            ? error.message
            : 'Could not cancel this visit. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: const Text('Cancel this appointment?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.appointment.title}\n${widget.appointment.providerName}\n${widget.appointment.displayWhen}',
            ),
            const SizedBox(height: 12),
            const Text(
              'This will remove the visit from your upcoming schedule.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reasonController,
              enabled: !_saving,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'Tell your care team why you need to cancel',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Keep appointment'),
        ),
        FilledButton(
          onPressed: _saving ? null : _cancel,
          child: Text(_saving ? 'Cancelling…' : 'Confirm cancellation'),
        ),
      ],
    ),
  );
}
