import 'package:flutter_test/flutter_test.dart';

import 'package:altrix/features/patient/data/models/patient_models.dart';
import 'package:altrix/features/patient/data/utils/appointment_utils.dart';

AppointmentModel appointment({
  required String id,
  required DateTime start,
  required DateTime end,
  String status = 'scheduled',
}) => AppointmentModel(
  id: id,
  title: 'Telehealth',
  providerName: 'Dr. Samira',
  dateLabel: '',
  timeLabel: '',
  endTimeLabel: '',
  visitType: 'Video visit',
  duration: '50 min',
  isVirtual: true,
  status: status,
  joinToken: '',
  joinUrl: 'https://example.com/join',
  location: '',
  note: '',
  sortDateTime: start,
  endDateTime: end,
  raw: const {},
);

void main() {
  test('home next appointment excludes meetings whose end time has passed', () {
    final now = DateTime(2026, 10, 16, 12);
    final ended = appointment(
      id: 'ended',
      start: now.subtract(const Duration(hours: 2)),
      end: now.subtract(const Duration(hours: 1)),
    );
    final future = appointment(
      id: 'future',
      start: now.add(const Duration(hours: 1)),
      end: now.add(const Duration(hours: 2)),
    );

    expect(nextAppointment([ended, future], currentTime: now)?.id, 'future');
  });

  test('home keeps an appointment visible while its meeting is active', () {
    final now = DateTime(2026, 10, 16, 12);
    final active = appointment(
      id: 'active',
      start: now.subtract(const Duration(minutes: 15)),
      end: now.add(const Duration(minutes: 35)),
    );

    expect(nextAppointment([active], currentTime: now)?.id, 'active');
  });

  test('home excludes inactive appointment statuses', () {
    final now = DateTime(2026, 10, 16, 12);
    for (final status in [
      'completed',
      'cancelled',
      'declined',
      'late-cancel',
      'no-show',
    ]) {
      final item = appointment(
        id: status,
        start: now.add(const Duration(hours: 1)),
        end: now.add(const Duration(hours: 2)),
        status: status,
      );
      expect(nextAppointment([item], currentTime: now), isNull);
    }
  });
}
