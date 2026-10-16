import 'package:flutter_test/flutter_test.dart';

import 'package:altrix/features/patient/data/models/patient_models.dart';

void main() {
  test('AppointmentModel parses joinUrl from appointments API payload', () {
    const payload = {
      'success': true,
      'data': {
        'appointments': [
          {
            'id': 'cmtiedwbm0001wc8cb356rgny',
            'type': 'Telehealth Check-in',
            'date': '2026-09-01',
            'startTime': '10:20',
            'endTime': '11:10',
            'startsAt': '2026-09-01T10:20:00.000Z',
            'endsAt': '2026-09-01T11:10:00.000Z',
            'status': 'confirmed',
            'isVirtual': true,
            'clinicianName': 'Clinic Admin',
            'joinUrl':
                'https://us05web.zoom.us/j/86415304776?pwd=ITzXgRub3xbm1cvJu9mWS8dcTyplLM.1',
          },
        ],
      },
    };

    final appointment = AppointmentModel.fromJson(
      (payload['data'] as Map<String, dynamic>)['appointments'][0]
          as Map<String, dynamic>,
    );

    expect(
      appointment.effectiveJoinUrl,
      'https://us05web.zoom.us/j/86415304776?pwd=ITzXgRub3xbm1cvJu9mWS8dcTyplLM.1',
    );
    expect(appointment.hasJoinLink, isTrue);
    expect(appointment.isVirtual, isTrue);
    expect(appointment.providerName, 'Clinic Admin');
    expect(appointment.timeLabel, '10:20 AM');
    expect(appointment.endTimeLabel, '11:10 AM');
    expect(appointment.duration, '50 min');
  });

  test('AppointmentModel formats startTime 15:49 and endTime 16:39 consistently without UTC distortion', () {
    final appointment = AppointmentModel.fromJson({
      'id': 'appt-123',
      'type': 'Consultation',
      'date': '2026-09-10',
      'startTime': '15:49',
      'endTime': '16:39',
      'startsAt': '2026-09-10T15:49:00.000Z',
      'endsAt': '2026-09-10T16:39:00.000Z',
      'status': 'scheduled',
      'isVirtual': false,
    });

    expect(appointment.timeLabel, '3:49 PM');
    expect(appointment.endTimeLabel, '4:39 PM');
    expect(appointment.duration, '50 min');
  });

  test('AppointmentModel parses patient booking, decline and client join fields', () {
    final appointment = AppointmentModel.fromJson({
      'id': 'appt-declined',
      'type': 'Individual Therapy',
      'date': '2026-10-25',
      'startTime': '10:00',
      'status': 'cancelled',
      'patientBooked': false,
      'declineReason': 'Doctor unavailable. Please select another slot.',
      'isVirtual': true,
      'clientJoinUrl': 'https://altrixs.com/telehealth/join/client-token',
    });

    expect(appointment.patientBooked, isFalse);
    expect(appointment.isDeclinedByDoctor, isTrue);
    expect(
      appointment.declineReason,
      'Doctor unavailable. Please select another slot.',
    );
    expect(
      appointment.effectiveJoinUrl,
      'https://altrixs.com/telehealth/join/client-token',
    );
  });
}
