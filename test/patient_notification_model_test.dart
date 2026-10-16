import 'package:altrix/features/patient/data/models/patient_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses canonical patient notification history response', () {
    final page = PatientNotificationPage.fromJson(const {
      'success': true,
      'data': {
        'notifications': [
          {
            'id': 'notification-1',
            'type': 'appointment_confirmed',
            'title': 'Appointment confirmed',
            'body': 'Dr. Samira accepted your appointment.',
            'data': {'appointmentId': 'appointment-1'},
            'isRead': false,
            'readAt': null,
            'createdAt': '2026-10-16T08:00:00.000Z',
          },
        ],
        'pagination': {'page': 1, 'limit': 20, 'total': 1, 'hasMore': false},
        'unreadCount': 1,
      },
    });

    expect(page.notifications, hasLength(1));
    expect(page.notifications.single.id, 'notification-1');
    expect(page.notifications.single.isRead, isFalse);
    expect(page.notifications.single.data['appointmentId'], 'appointment-1');
    expect(page.unreadCount, 1);
    expect(page.total, 1);
    expect(page.hasMore, isFalse);
  });

  test('parses legacy top-level response aliases', () {
    final page = PatientNotificationPage.fromJson(const {
      'success': true,
      'notifications': [
        {
          'id': 'notification-2',
          'type': 'chat_message',
          'title': 'New message',
          'message': 'Your care team sent a message.',
          'is_read': true,
          'created_at': '2026-10-16T09:00:00.000Z',
        },
      ],
      'page': 1,
      'limit': 10,
      'total': 1,
      'hasMore': false,
      'unread_count': 0,
    });

    expect(page.notifications.single.body, 'Your care team sent a message.');
    expect(page.notifications.single.isRead, isTrue);
    expect(page.unreadCount, 0);
  });
}
