import 'package:altrix/features/notifications/presentation/providers/notification_activity_provider.dart';
import 'package:altrix/features/patient/data/models/patient_models.dart';
import 'package:altrix/features/patient/presentation/providers/patient_providers.dart';
import 'package:altrix/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/patient_test_overrides.dart';

void main() {
  test('parses unread count aliases and falls back to unread reminders', () {
    expect(DashboardItem.fromJson({'title': 'New alert'}).isUnread, true);
    expect(
      DashboardItem.fromJson({'title': 'Read alert', 'isUnread': false})
          .isUnread,
      false,
    );
    expect(
      DashboardModel.fromJson({
        'data': {'unreadNotificationCount': 4},
      }).unreadNotifications,
      4,
    );
    expect(
      DashboardModel.fromJson({
        'data': {
          'stats': {'unread_notification_count': 3},
        },
      }).unreadNotifications,
      3,
    );
    expect(
      DashboardModel.fromJson({
        'data': {
          'reminders': [
            {'title': 'Appointment', 'isUnread': true},
          ],
        },
      }).unreadNotifications,
      1,
    );
  });

  test('badge reconciles visible alerts and reads in shared state', () async {
    final dashboard = DashboardModel.fromJson({
      'data': {
        'unreadNotifications': 0,
        'notifications': [
          {'title': 'Message', 'isUnread': true},
        ],
        'reminders': [
          {'title': 'Appointment', 'isUnread': true},
        ],
      },
    });
    final container = ProviderContainer(
      overrides: [dashboardProvider.overrideWith((ref) async => dashboard)],
    );
    addTearDown(container.dispose);
    await container.read(dashboardProvider.future);
    expect(container.read(unreadNotificationCountProvider), 2);
    container
        .read(readNotificationKeysProvider.notifier)
        .markRead(dashboard.notifications.first);
    expect(container.read(unreadNotificationCountProvider), 1);
    container.read(readNotificationKeysProvider.notifier).markAllRead([
      ...dashboard.notifications,
      ...dashboard.reminders,
    ]);
    expect(container.read(unreadNotificationCountProvider), 0);
  });

  testWidgets('Home renders the unread number and removes it when read', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final dashboard = DashboardModel.fromJson({
      'data': {
        'notifications': [
          {'title': 'Care team', 'isUnread': true},
        ],
        'reminders': [
          {'title': 'Visit', 'isUnread': true},
        ],
      },
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...patientTestOverrides(),
          dashboardProvider.overrideWith((ref) async => dashboard),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final badge = find.byKey(const ValueKey('home-notification-badge'));
    expect(badge, findsOneWidget);
    expect(
      find.descendant(of: badge, matching: find.text('2')),
      findsOneWidget,
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
    container.read(readNotificationKeysProvider.notifier).markAllRead([
      ...dashboard.notifications,
      ...dashboard.reminders,
    ]);
    await tester.pumpAndSettle();
    expect(badge, findsNothing);
    expect(tester.takeException(), isNull);
  });
}
