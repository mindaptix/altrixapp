import 'package:altrix/features/coping/presentation/cognitive_distortions_screen.dart';
import 'package:altrix/features/coping/presentation/coping_tools_screen.dart';
import 'package:altrix/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('reveals a perspective and filters only the noticed patterns', (
    tester,
  ) async {
    final checked = <int>{};
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: CognitiveDistortionsScreen(checked: checked, draft: {}),
      ),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('reframe-0')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reframe-0')));
    await tester.pumpAndSettle();
    expect(
      find.text('What would the middle ground look like?'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('notice-0')),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('notice-0')));
    await tester.pumpAndSettle();
    expect(checked, {0});
    await tester.scrollUntilVisible(
      find.text('Noticed today · 1'),
      -250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Noticed today · 1'));
    await tester.pumpAndSettle();
    expect(find.text('All-or-Nothing Thinking'), findsOneWidget);
    expect(find.text('Catastrophizing'), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('notice-0')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('notice-0')));
    await tester.pumpAndSettle();
    expect(checked, isEmpty);
    expect(find.text('Nothing marked yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reflection edits are retained and compact large text remains usable',
    (tester) async {
      final draft = <String, String>{};
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: CognitiveDistortionsScreen(checked: {0}, draft: draft),
        ),
      );
      await tester.scrollUntilVisible(
        find.text('Noticed today · 1'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Noticed today · 1'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('personal-thought')),
        350,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('personal-thought')),
        'One mistake means I failed.',
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('personal-reframe')),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('personal-reframe')),
        'One mistake is one part of my effort.',
      );
      expect(draft['distortion_thought'], 'One mistake means I failed.');
      expect(
        draft['distortion_reframe'],
        'One mistake is one part of my effort.',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'toolkit opens the redesign and retains noticed patterns on return',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light(), home: const CopingToolsScreen()),
      );
      await tester.scrollUntilVisible(
        find.widgetWithText(ChoiceChip, 'CBT'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'CBT'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Cognitive Distortions'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cognitive Distortions'));
      await tester.pumpAndSettle();
      expect(find.byType(CognitiveDistortionsScreen), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('notice-0')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('notice-0')));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cognitive Distortions'));
      await tester.pumpAndSettle();
      expect(find.text('Noticed today · 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
