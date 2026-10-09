import 'package:altrix/features/chatbot/data/chatbot_client.dart';
import 'package:altrix/features/chatbot/presentation/widgets/floating_chatbot.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'chat is hidden on pushed routes and keeps its conversation on return',
    (tester) async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.path, '/api/patient/chatbot');
            expect(options.data['messages'].last['content'], 'Hello');
            handler.resolve(
              Response(
                requestOptions: options,
                data: <String, dynamic>{
                  'data': {'reply': 'How can I help?'},
                },
              ),
            );
          },
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [chatbotDioProvider.overrideWithValue(dio)],
          child: MaterialApp(
            home: Overlay.wrap(
              child: FloatingChatbot(
                child: Builder(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              const Scaffold(body: Text('Second screen')),
                        ),
                      ),
                      child: const Text('Next'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(FloatingActionButton), findsOneWidget);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.runAsync(() async {
        await tester.tap(find.byTooltip('Send message'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      expect(find.text('How can I help?'), findsOneWidget);
      await tester.tap(find.byTooltip('Close chat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Second screen'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
      Navigator.of(tester.element(find.text('Second screen'))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('How can I help?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
