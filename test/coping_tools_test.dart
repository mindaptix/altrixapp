import 'package:altrix/features/coping/presentation/coping_tools_screen.dart';
import 'package:flutter/material.dart';
import 'package:altrix/features/coping/data/breathing_audio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('feeling suggestions adapt and compact large text stays usable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: const CopingToolsScreen(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(ChoiceChip, 'Low mood'),
      200,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Low mood'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('For when you feel low mood'),
      300,
    );
    expect(find.text('For when you feel low mood'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Behavioral Activation'), 200);
    expect(find.text('Behavioral Activation'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filters tools and keeps worksheet draft on reopening', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CopingToolsScreen()));
    await tester.scrollUntilVisible(
      find.widgetWithText(ChoiceChip, 'CBT'),
      350,
    );
    await tester.tap(find.widgetWithText(ChoiceChip, 'CBT'));
    await tester.pumpAndSettle();
    expect(find.text('Thought Record'), findsOneWidget);
    expect(find.text('TIPP Skills'), findsNothing);
    await tester.ensureVisible(find.text('Thought Record'));
    await tester.pump();
    await tester.tap(find.text('Thought Record'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'A difficult day');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Thought Record'));
    await tester.pump();
    await tester.tap(find.text('Thought Record'));
    await tester.pumpAndSettle();
    expect(find.text('A difficult day'), findsOneWidget);
  });

  testWidgets('breathing advances phases and pauses when leaving', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final audio = _FakeAudio();
    await tester.pumpWidget(
      MaterialApp(home: CopingToolsScreen(audioFactory: () => audio)),
    );
    await tester.scrollUntilVisible(
      find.widgetWithText(ChoiceChip, 'Mindfulness'),
      350,
    );
    await tester.tap(find.widgetWithText(ChoiceChip, 'Mindfulness'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('4-7-8 Breathing'));
    await tester.pump();
    await tester.tap(find.text('4-7-8 Breathing'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Start Breathing'));
    await tester.pump();
    await tester.tap(find.text('Start Breathing'));
    expect(audio.phases.last, 'Breathe In:4:4');
    await tester.pump(const Duration(seconds: 4));
    expect(audio.phases.last, 'Hold:7:7');
    expect(find.text('Hold'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    await tester.pump(const Duration(seconds: 7));
    expect(audio.phases.last, 'Breathe Out:8:8');
    await tester.ensureVisible(find.text('Pause'));
    await tester.pump();
    await tester.tap(find.text('Pause'));
    expect(audio.stops, greaterThan(0));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('8'), findsOneWidget);
    await tester.ensureVisible(find.byType(Switch));
    await tester.pump();
    await tester.tap(find.byType(Switch));
    await tester.pump();
    final calls = audio.phases.length;
    await tester.ensureVisible(find.text('Start Breathing'));
    await tester.pump();
    await tester.tap(find.text('Start Breathing'));
    await tester.pump(const Duration(seconds: 1));
    expect(audio.phases.length, calls);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(audio.disposed, isTrue);
    expect(tester.takeException(), isNull);
  });
}

class _FakeAudio extends BreathingAudio {
  final phases = <String>[];
  int stops = 0;
  bool disposed = false;
  @override
  Future<void> play(String phase, int duration, int remaining) async {
    phases.add('$phase:$duration:$remaining');
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}
