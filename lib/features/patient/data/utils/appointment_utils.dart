import '../models/patient_models.dart';

const _inactiveStatuses = {
  'cancelled',
  'canceled',
  'completed',
  'declined',
  'late_cancel',
  'late-cancel',
  'no_show',
  'no-show',
};

List<AppointmentModel> sortUpcomingAppointments(
  List<AppointmentModel> appointments, {
  DateTime? currentTime,
}) {
  final now = currentTime ?? DateTime.now();
  final upcoming =
      appointments
          .where(
            (item) =>
                !_inactiveStatuses.contains(item.status.toLowerCase()) &&
                !item.isMeetingConcluded(now),
          )
          .toList()
        ..sort((a, b) {
          final aDate = a.sortDateTime;
          final bDate = b.sortDateTime;
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return aDate.compareTo(bDate);
        });

  return upcoming;
}

AppointmentModel? nextAppointment(
  List<AppointmentModel> appointments, {
  DateTime? currentTime,
}) {
  final sorted = sortUpcomingAppointments(
    appointments,
    currentTime: currentTime,
  );
  if (sorted.isEmpty) return null;
  return sorted.first;
}

List<AppointmentModel> homeUpcomingAppointments(
  List<AppointmentModel> appointments, {
  DateTime? currentTime,
}) {
  final sorted = sortUpcomingAppointments(
    appointments,
    currentTime: currentTime,
  );
  if (sorted.length <= 1) return const [];
  return sorted.skip(1).take(3).toList();
}
