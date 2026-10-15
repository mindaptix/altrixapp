import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:altrix/features/auth/domain/entities/user.dart';
import 'package:altrix/features/auth/presentation/providers/auth_provider.dart';
import 'package:altrix/features/patient/data/models/patient_models.dart';
import 'package:altrix/features/patient/data/repositories/patient_repository.dart';
import 'package:altrix/features/patient/presentation/providers/patient_providers.dart';
import 'package:altrix/screens/conversation_detail_screen.dart';
import 'package:altrix/screens/messages_screen.dart';

void main() {
  group('Message & Conversation Models', () {
    test('ConversationModel parses participant name, avatar and generates initials', () {
      final conversation = ConversationModel.fromJson({
        'id': 'conv-1',
        'title': 'Clinic Care Team',
        'preview': 'Your lab results are ready.',
        'lastMessageAt': '2026-09-10T10:30:00Z',
        'unreadCount': 2,
        'topic': 'Medical',
        'participant': {'name': 'Dr. Sarah Jenkins', 'role': 'Psychiatrist'},
      });

      expect(conversation.effectiveName, 'Dr. Sarah Jenkins');
      expect(conversation.initials, 'DJ');
      expect(conversation.unreadCount, 2);
    });

    test(
      'MessageModel isFromMe correctly distinguishes patient vs clinician',
      () {
        final myMessage = MessageModel.fromJson({
          'id': 'msg-1',
          'body': 'Hello Dr. Jenkins',
          'sender': 'patient',
          'createdAt': '2026-09-10T10:30:00Z',
        });

        final docMessage = MessageModel.fromJson({
          'id': 'msg-2',
          'body': 'Hello Vishal, how are you feeling today?',
          'sender': 'clinician',
          'senderName': 'Dr. Sarah Jenkins',
          'createdAt': '2026-09-10T10:31:00Z',
        });

        expect(
          myMessage.isFromMe(
            currentUserId: 'user-1',
            currentUserName: 'Vishal',
          ),
          isTrue,
        );
        expect(
          docMessage.isFromMe(
            currentUserId: 'user-1',
            currentUserName: 'Vishal',
          ),
          isFalse,
        );
        expect(docMessage.senderName, 'Dr. Sarah Jenkins');
      },
    );
  });

  group('MessagesScreen Widget UI', () {
    testWidgets('MessagesScreen displays user name and profile icon', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final testUser = const User(
        id: 'cmtid3p9a0001qfwmb0suk5i9',
        name: 'Vishal Sharma',
        email: 'vishal@mindaptix.com',
        phone: '7677876767675',
      );

      final fakeConversation = ConversationModel.fromJson({
        'id': 'conv-1',
        'title': 'Dr. Sarah Jenkins',
        'preview': 'Let me know if you have questions.',
        'lastMessageAt': '2026-09-10T12:00:00Z',
        'unreadCount': 1,
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _FakeAuthNotifier(testUser)),
            conversationsProvider.overrideWith(
              (ref) async => [fakeConversation],
            ),
          ],
          child: const MaterialApp(home: MessagesScreen()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify User Name is shown in the top header
      expect(find.text('Vishal Sharma'), findsOneWidget);
      // Verify User Profile Avatar with Initials "VS" is shown
      expect(find.text('VS'), findsOneWidget);
      // Verify Live indicator is shown
      expect(find.text('Live Secure Chat'), findsOneWidget);
      // Verify conversation tile for Dr. Sarah Jenkins is displayed
      expect(find.text('Dr. Sarah Jenkins'), findsOneWidget);
      expect(find.text('Conversations'), findsOneWidget);
      expect(find.text('Unread'), findsOneWidget);
    });

    testWidgets('MessagesScreen shows zero conversation counts in one row', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const testUser = User(
        id: 'patient-empty',
        name: 'Vishal Sharma',
        email: 'vishal@example.com',
        phone: '1234567890',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _FakeAuthNotifier(testUser)),
            conversationsProvider.overrideWith((ref) async => []),
          ],
          child: const MaterialApp(home: MessagesScreen()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('0'), findsNWidgets(2));
      expect(find.text('Conversations'), findsOneWidget);
      expect(find.text('Unread'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'ConversationDetailScreen renders participant profile, online status, and live chat message bubble',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final testUser = const User(
          id: 'user-1',
          name: 'Vishal',
          email: 'vishal@mindaptix.com',
          phone: '1234567890',
        );

        final fakeRepo = _FakePatientChatRepo([
          MessageModel.fromJson({
            'id': 'msg-1',
            'threadId': 'conv-1',
            'body': 'Welcome Vishal! How can I assist you?',
            'sender': 'clinician',
            'senderName': 'Dr. Sarah Jenkins',
            'createdAt': '2026-09-10T09:00:00Z',
            'isRead': true,
          }),
        ]);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith(() => _FakeAuthNotifier(testUser)),
              patientRepositoryProvider.overrideWithValue(fakeRepo),
            ],
            child: const MaterialApp(
              home: ConversationDetailScreen(
                conversationId: 'conv-1',
                title: 'Dr. Sarah Jenkins',
                participantName: 'Dr. Sarah Jenkins',
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Verify participant name and avatar initial in AppBar
        expect(find.text('Dr. Sarah Jenkins'), findsWidgets);
        expect(find.text('DJ'), findsWidgets);
        expect(find.textContaining('End-to-end encrypted'), findsOneWidget);

        // Verify chat message is rendered in the active message bubble
        expect(
          find.text('Welcome Vishal! How can I assist you?'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'ConversationDetailScreen renders empty state when no messages exist',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final testUser = const User(
          id: 'user-1',
          name: 'Vishal',
          email: 'vishal@mindaptix.com',
          phone: '1234567890',
        );

        final fakeRepo = _FakePatientChatRepo([]);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith(() => _FakeAuthNotifier(testUser)),
              patientRepositoryProvider.overrideWithValue(fakeRepo),
            ],
            child: const MaterialApp(
              home: ConversationDetailScreen(
                conversationId: 'conv-empty',
                title: 'Dr. Sarah Jenkins',
                participantName: 'Dr. Sarah Jenkins',
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Start a conversation'), findsOneWidget);
        expect(
          find.text('Send your care team a secure real-time message below.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'ConversationDetailScreen sends a message and optimistically updates UI',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final testUser = const User(
          id: 'user-1',
          name: 'Vishal',
          email: 'vishal@mindaptix.com',
          phone: '1234567890',
        );

        final fakeRepo = _FakePatientChatRepo([]);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith(() => _FakeAuthNotifier(testUser)),
              patientRepositoryProvider.overrideWithValue(fakeRepo),
            ],
            child: const MaterialApp(
              home: ConversationDetailScreen(
                conversationId: 'conv-send-test',
                title: 'Dr. Sarah Jenkins',
                participantName: 'Dr. Sarah Jenkins',
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Enter text in message field
        final textField = find.byType(TextField);
        expect(textField, findsOneWidget);
        await tester.enterText(textField, 'Doctor, can I take the medicine after dinner?');
        await tester.pump();

        // Tap the send button (IconButton/Material with send icon)
        final sendButton = find.byIcon(Icons.send_rounded);
        expect(sendButton, findsOneWidget);
        await tester.tap(sendButton);
        await tester.pump();

        // Verify optimistic message is displayed and textfield is cleared
        expect(
          find.text('Doctor, can I take the medicine after dinner?'),
          findsOneWidget,
        );
        expect(fakeRepo.messages.length, 1);
        expect(fakeRepo.messages.first.body, 'Doctor, can I take the medicine after dinner?');
      },
    );
  });
}

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this._user);
  final User _user;

  @override
  AuthState build() => AuthState(user: _user, isRestoringSession: false);
}

class _FakePatientChatRepo implements PatientRepository {
  _FakePatientChatRepo(this.messages);

  final List<MessageModel> messages;

  @override
  Future<List<MessageModel>> getConversationMessages({
    required String conversationId,
    int page = 1,
    int limit = 20,
  }) async {
    return List.of(messages);
  }

  @override
  Future<MessageModel> sendMessage({
    required String conversationId,
    required String message,
  }) async {
    final newMsg = MessageModel(
      id: 'server-sent-${DateTime.now().millisecondsSinceEpoch}',
      body: message,
      sender: 'patient',
      senderName: 'Vishal',
      createdAt: DateTime.now().toIso8601String(),
      isRead: true,
      raw: const {},
    );
    messages.add(newMsg);
    return newMsg;
  }

  @override
  Future<void> markMessageRead(String messageId) async {}

  @override
  Stream<Map<String, dynamic>> streamLiveMessages({
    required String threadId,
    required String token,
  }) => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
