import 'package:altrix/features/auth/domain/entities/user.dart';
import 'package:altrix/features/auth/presentation/providers/auth_provider.dart';
import 'package:altrix/features/patient/data/models/medication_model.dart';
import 'package:altrix/features/patient/data/models/personal_medication.dart';
import 'package:altrix/features/patient/presentation/providers/patient_providers.dart';
import 'package:altrix/features/patient/presentation/screens/medications_screen.dart';
import 'package:altrix/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    user: User(id: 'patient-a', name: 'Patient', email: '', phone: ''),
    isRestoringSession: false,
  );
}

class _Meds extends MedicationsNotifier {
  @override
  Future<List<MedicationScheduleModel>> build() async => [];
}

class _Store extends PersonalMedicationStore {
  final saved = <String, List<PersonalMedication>>{};
  bool fail = false;
  @override
  Future<List<PersonalMedication>> load(String userId) async =>
      saved[userId] ?? [];
  @override
  Future<void> save(String userId, List<PersonalMedication> items) async {
    if (fail) throw StateError('Storage unavailable');
    saved[userId] = items;
  }
}

void main() {
  testWidgets(
    'adherence includes personal schedules and distinguishes skipped doses',
    (tester) async {
      final store = _Store();
      store.saved['patient-a'] = [
        PersonalMedication(
          id: 'daily',
          name: 'Daily tracker entry',
          dosage: 'As directed',
          frequency: 'Twice daily',
          times: ['08:00', '20:00'],
          logDate: PersonalMedication.dayKey(DateTime.now()),
          logs: {'08:00': 'taken', '20:00': 'skipped'},
        ),
      ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(_Auth.new),
            medicationsProvider.overrideWith(_Meds.new),
            personalMedicationStoreProvider.overrideWithValue(store),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const MedicationsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('50% of scheduled doses taken'), findsOneWidget);
      expect(find.text('Logged'), findsOneWidget);
      expect(find.text('All done!'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'daily logs reset on a new day and weekly schedules use the chosen day',
    () {
      const medication = PersonalMedication(
        id: 'test',
        name: 'Test entry',
        dosage: 'As directed',
        frequency: 'Weekly',
        times: ['08:00'],
        weekday: DateTime.friday,
        logDate: '2026-10-9',
        logs: {'08:00': 'taken'},
      );
      expect(medication.schedule(DateTime(2026, 10, 9)).takenCount, 1);
      expect(medication.schedule(DateTime(2026, 10, 10)).doseTimes, isEmpty);
      expect(medication.schedule(DateTime(2026, 10, 16)).takenCount, 0);
      expect(medication.schedule(DateTime(2026, 10, 16)).pendingCount, 1);
      expect(
        PersonalMedication.fromJson(medication.toJson()).weekday,
        DateTime.friday,
      );
    },
  );

  test(
    'persists tracker changes and preserves state on storage failure',
    () async {
      final store = _Store();
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(_Auth.new),
          personalMedicationStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(container.dispose);
      await container.read(personalMedicationsProvider.future);
      final notifier = container.read(personalMedicationsProvider.notifier);
      const medication = PersonalMedication(
        id: 'test',
        name: 'Test entry',
        dosage: 'As directed',
        frequency: 'Once daily',
        times: ['08:00'],
      );
      await notifier.add(medication);
      await notifier.log('test', '08:00', MedicationDoseStatus.skipped);
      expect(store.saved['patient-a']!.single.logs['08:00'], 'skipped');
      expect(store.saved['patient-b'], isNull);
      store.fail = true;
      await expectLater(notifier.remove('test'), throwsStateError);
      expect(
        container.read(personalMedicationsProvider).requireValue.single.id,
        'test',
      );
      store.fail = false;
      await notifier.toggle('test');
      expect(
        container.read(personalMedicationsProvider).requireValue.single.active,
        false,
      );
      await notifier.remove('test');
      expect(store.saved['patient-a'], isEmpty);
    },
  );

  testWidgets(
    'adds an as-needed tracker entry and logs, toggles and removes it',
    (tester) async {
      final store = _Store();
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(_Auth.new),
            medicationsProvider.overrideWith(_Meds.new),
            personalMedicationStoreProvider.overrideWithValue(store),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const MedicationsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Add medication'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'My medication');
      await tester.enterText(find.byType(TextFormField).at(1), 'As directed');
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('As needed').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Save to tracker'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save to tracker'));
      await tester.pumpAndSettle();
      expect(store.saved['patient-a']!.single.name, 'My medication');
      await tester.scrollUntilVisible(
        find.text('Log dose taken'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Log dose taken'));
      await tester.pumpAndSettle();
      expect(find.text('1 dose entry today'), findsOneWidget);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(store.saved['patient-a']!.single.active, false);
      expect(find.text('Inactive tracker entries'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Remove entry'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove entry'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(store.saved['patient-a'], isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
