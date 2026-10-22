import 'package:altrix/core/navigation/app_navigator.dart';
import 'package:altrix/core/notifications/notification_router.dart';
import 'package:altrix/features/notifications/presentation/providers/notification_read_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(NotificationRouter.resetForTesting);

  Future<void> mountRouter(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: rootNavigatorKey,
        home: const Scaffold(body: Text('Home')),
      ),
    );
    NotificationRouter.markReady();
  }

  testWidgets('conversationId opens the conversation detail destination', (
    tester,
  ) async {
    NotificationChatTarget? target;
    NotificationRouter.setChatScreenBuilderForTesting((value) {
      target = value;
      return const Scaffold(body: Text('Conversation detail'));
    });
    await mountRouter(tester);

    NotificationRouter.handleTap(const {
      'type': 'message',
      'conversationId': 'conversation-1',
      'participantName': 'Dr Rivera',
      'title': 'New care-team message',
      'avatarUrl': 'https://example.test/avatar.png',
    });
    await tester.pumpAndSettle();

    expect(find.text('Conversation detail'), findsOneWidget);
    expect(target?.conversationId, 'conversation-1');
    expect(target?.participantName, 'Dr Rivera');
    expect(target?.title, 'New care-team message');
    expect(target?.avatarUrl, 'https://example.test/avatar.png');
  });

  testWidgets('thread_id opens the conversation detail destination', (
    tester,
  ) async {
    NotificationChatTarget? target;
    NotificationRouter.setChatScreenBuilderForTesting((value) {
      target = value;
      return const Scaffold(body: Text('Thread detail'));
    });
    await mountRouter(tester);

    NotificationRouter.handleTap(const {
      'type': 'new_message',
      'thread_id': 'thread-42',
    });
    await tester.pumpAndSettle();

    expect(find.text('Thread detail'), findsOneWidget);
    expect(target?.conversationId, 'thread-42');
  });

  testWidgets('message without a thread opens the Messages tab', (
    tester,
  ) async {
    int? selectedTab;
    await mountRouter(tester);
    NotificationRouter.registerTabSwitcher((value) => selectedTab = value);

    NotificationRouter.handleTap(const {
      'notificationId': 'notification-without-thread',
      'type': 'care_team_message',
    });
    await tester.pump();

    expect(selectedTab, 2);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('a mark-read failure does not block chat navigation', (
    tester,
  ) async {
    NotificationRouter.setChatScreenBuilderForTesting(
      (_) => const Scaffold(body: Text('Opened after failure')),
    );
    NotificationRouter.registerNotificationReadHandler((_) {
      throw StateError('simulated 500');
    });
    await mountRouter(tester);

    NotificationRouter.handleTap(const {
      'notificationId': 'notification-500',
      'type': 'clinician_message',
      'chat_id': 'chat-500',
    });
    await tester.pumpAndSettle();

    expect(find.text('Opened after failure'), findsOneWidget);
  });

  testWidgets('repeated taps create only one conversation route', (
    tester,
  ) async {
    var builds = 0;
    NotificationRouter.setChatScreenBuilderForTesting((_) {
      builds += 1;
      return const Scaffold(body: Text('Single route'));
    });
    await mountRouter(tester);

    const payload = {
      'notificationId': 'same-notification',
      'type': 'chat',
      'conversation_id': 'same-conversation',
    };
    NotificationRouter.handleTap(payload);
    NotificationRouter.handleTap(payload);
    await tester.pumpAndSettle();

    expect(builds, 1);
    expect(find.text('Single route'), findsOneWidget);
  });

  testWidgets('non-message notifications keep existing tab behavior', (
    tester,
  ) async {
    int? selectedTab;
    await mountRouter(tester);
    NotificationRouter.registerTabSwitcher((value) => selectedTab = value);

    NotificationRouter.handleTap(const {
      'notificationId': 'appointment-1',
      'type': 'appointment_reminder',
    });
    await tester.pump();

    expect(selectedTab, 1);
  });

  testWidgets('telehealth notification delegates before pushing a route', (
    tester,
  ) async {
    String? handledToken;
    await mountRouter(tester);
    NotificationRouter.registerTelehealthTapHandler(
      (value) => handledToken = value,
    );

    NotificationRouter.handleTap(const {
      'notificationId': 'telehealth-ended',
      'type': 'telehealth_call',
      'joinToken': 'ended-join-token',
    });
    await tester.pump();

    expect(handledToken, 'ended-join-token');
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Telehealth waiting room'), findsNothing);
  });

  test(
    'failed mark-read request is attempted once across repeated taps',
    () async {
      var requests = 0;
      final container = ProviderContainer(
        overrides: [
          notificationReadRequestProvider.overrideWithValue((_) async {
            requests += 1;
            throw StateError('simulated 500');
          }),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(
        notificationReadControllerProvider.notifier,
      );

      await Future.wait([
        controller.markRead('notification-1'),
        controller.markRead('notification-1'),
      ]);
      await controller.markRead('notification-1');

      expect(requests, 1);
      expect(
        container
            .read(notificationReadControllerProvider)
            .locallyReadIds
            .contains('notification-1'),
        isTrue,
      );
      expect(
        container.read(notificationReadControllerProvider).processingIds,
        isEmpty,
      );
    },
  );
}
