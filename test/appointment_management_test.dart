import 'dart:async';

import 'package:altrix/features/patient/data/datasources/patient_remote_datasource.dart';
import 'package:altrix/features/patient/data/models/patient_models.dart';
import 'package:altrix/features/patient/data/repositories/patient_repository.dart';
import 'package:altrix/features/patient/presentation/providers/patient_providers.dart';
import 'package:altrix/screens/schedule_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class AppointmentApi {
  final requests = <RequestOptions>[];
  final appointments = <Map<String, dynamic>>[];
  int conflicts = 0;
  bool failSlots = false;
  bool emptySlots = false;
  bool failCancel = false;
  Completer<void>? pendingSave;
  int listReads = 0;
  late final repository = PatientRepository(
    PatientRemoteDataSource(
      Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (request, handler) async {
              requests.add(request);
              final path = request.path;
              Map<String, dynamic> data = {};
              if (path.endsWith('/doctors')) {
                data = {
                  'doctors': [
                    {
                      'id': 'doctor-1',
                      'name': 'Dr. Taylor',
                      'role': 'THERAPIST',
                    },
                    {
                      'id': 'doctor-2',
                      'name': 'Dr. Rivera',
                      'role': 'PSYCHIATRIST',
                    },
                  ],
                };
              } else if (path.endsWith('/availability')) {
                if (failSlots) {
                  handler.resolve(
                    Response(
                      requestOptions: request,
                      data: {
                        'success': false,
                        'error': {
                          'code': 'UNAVAILABLE',
                          'message': 'Availability temporarily unavailable',
                        },
                      },
                    ),
                  );
                  return;
                }
                final date = request.queryParameters['from'];
                data = {
                  'slots': emptySlots
                      ? []
                      : [
                          {
                            'date': date,
                            'startTime': '09:00',
                            'endTime': '09:50',
                            'available': false,
                          },
                          {
                            'date': date,
                            'startTime': '10:00',
                            'endTime': '10:50',
                            'available': true,
                          },
                          {
                            'date': date,
                            'startTime': '11:00',
                            'endTime': '11:50',
                          },
                          {
                            'date': date,
                            'startTime': '12:00',
                            'endTime': '12:50',
                            'available': true,
                          },
                        ],
                };
              } else if (request.method == 'GET' &&
                  path.endsWith('/appointments')) {
                listReads++;
                data = {'appointments': List.of(appointments)};
              } else if (path.endsWith('/cancel')) {
                if (failCancel) {
                  handler.resolve(
                    Response(
                      requestOptions: request,
                      data: {
                        'success': false,
                        'error': {
                          'code': 'INVALID_STATE',
                          'message': 'This appointment cannot be cancelled',
                        },
                      },
                    ),
                  );
                  return;
                }
                final cancelled = {
                  ...appointments.single,
                  'status': 'cancelled',
                };
                appointments.clear();
                data = {'appointment': cancelled};
              } else if (request.method == 'POST' ||
                  path.endsWith('/reschedule')) {
                if (pendingSave != null) await pendingSave!.future;
                if (conflicts > 0) {
                  conflicts--;
                  handler.resolve(
                    Response(
                      requestOptions: request,
                      data: {
                        'success': false,
                        'error': {
                          'code': 'SLOT_UNAVAILABLE',
                          'message': 'Slot conflict',
                        },
                      },
                    ),
                  );
                  return;
                }
                final input = request.data as Map<String, dynamic>;
                final saved = {
                  ...?appointments.firstOrNull,
                  ...input,
                  'id': 'appointment-1',
                  'clinicianName': 'Dr. Taylor',
                  'status': path.endsWith('/reschedule')
                      ? 'reschedule_requested'
                      : 'pending',
                };
                appointments
                  ..clear()
                  ..add(saved);
                data = {'appointment': saved};
              }
              handler.resolve(
                Response(
                  requestOptions: request,
                  statusCode: 200,
                  data: {'success': true, 'data': data},
                ),
              );
            },
          ),
        ),
    ),
  );

  void seed({String status = 'confirmed', bool clinician = true}) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    appointments.add({
      'id': 'appointment-1',
      'type': 'Individual Therapy',
      'clinicianId': clinician ? 'doctor-1' : null,
      'clinicianName': 'Dr. Taylor',
      'date': tomorrow.toIso8601String().split('T').first,
      'startTime': '14:00',
      'endTime': '14:50',
      'status': status,
      'isVirtual': false,
    });
  }
}

Future<void> mount(
  WidgetTester tester,
  AppointmentApi api, {
  Size size = const Size(390, 844),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        patientRepositoryProvider.overrideWithValue(api.repository),
        clockProvider.overrideWithValue(
          () => DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
            8,
            0,
          ),
        ),
      ],
      child: const MaterialApp(home: ScheduleScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text) async {
  if (find.text(text).evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      find.text(text),
      200,
      scrollable: find.byType(Scrollable).last,
    );
  }
  final finder = find.text(text).last;
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> startBooking(WidgetTester tester) async {
  await tapText(tester, 'Book appointment');
  await tester.tap(find.byType(DropdownButtonFormField<String>).first);
  await tester.pumpAndSettle();
  await tapText(tester, 'Dr. Taylor');
}

void main() {
  test('management excludes past, completed and cancelled appointments', () {
    final api = AppointmentApi()..seed();
    expect(
      AppointmentModel.fromJson(api.appointments.single).canManage,
      isTrue,
    );
    for (final status in ['completed', 'cancelled', 'no_show', 'in_session']) {
      expect(
        AppointmentModel.fromJson({
          ...api.appointments.single,
          'status': status,
        }).canManage,
        isFalse,
      );
    }
    expect(
      AppointmentModel.fromJson({
        ...api.appointments.single,
        'startsAt': DateTime.now()
            .subtract(const Duration(hours: 1))
            .toIso8601String(),
      }).canManage,
      isFalse,
    );
  });

  testWidgets('doctor-declined appointment shows reason and rebook action', (
    tester,
  ) async {
    final api = AppointmentApi()..seed(status: 'cancelled');
    api.appointments[0]['patientBooked'] = false;
    api.appointments[0]['declineReason'] =
        'Doctor unavailable. Please select another slot.';

    await mount(tester, api);

    await tester.scrollUntilVisible(
      find.text('Declined by Doctor'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Declined by Doctor'), findsOneWidget);
    expect(
      find.text('Doctor unavailable. Please select another slot.'),
      findsOneWidget,
    );
    expect(find.text('Rebook Slot'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ended virtual appointment does not show Join visit', (
    tester,
  ) async {
    final api = AppointmentApi()..seed();
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    api.appointments[0]
      ..['date'] = yesterday.toIso8601String().split('T').first
      ..['startTime'] = '10:00'
      ..['endTime'] = '10:50'
      ..['isVirtual'] = true
      ..['joinUrl'] = 'https://example.com/ended-meeting';

    await mount(tester, api);

    expect(find.text('Join visit'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'booking uses available slots and refreshes schedule after saving',
    (tester) async {
      final api = AppointmentApi();
      await mount(tester, api);
      await startBooking(tester);
      expect(find.text('09:00 – 09:50'), findsNothing);
      expect(find.text('11:00 – 11:50'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Request appointment'),
            )
            .onPressed,
        isNull,
      );
      await tapText(tester, '10:00 – 10:50');
      await tapText(tester, 'Request appointment');
      final request = api.requests.singleWhere((r) => r.method == 'POST');
      expect(request.path, '/api/patient/appointments');
      expect(request.data, {
        'clinicianId': 'doctor-1',
        'type': 'Individual Therapy',
        'date': api.requests
            .firstWhere((r) => r.path.endsWith('/availability'))
            .queryParameters['from'],
        'startTime': '10:00',
        'endTime': '10:50',
        'isVirtual': false,
      });
      expect(api.listReads, 2);
      expect(
        find.text('Appointment requested. Check your schedule for updates.'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('Individual Therapy'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Individual Therapy'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'changing clinician clears slot and requests that clinician availability',
    (tester) async {
      final api = AppointmentApi();
      await mount(tester, api);
      await startBooking(tester);
      await tapText(tester, '10:00 – 10:50');
      await tester.ensureVisible(
        find.byType(DropdownButtonFormField<String>).first,
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tapText(tester, 'Dr. Rivera');
      expect(
        api.requests.last.path,
        '/api/patient/doctors/doctor-2/availability',
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Request appointment'),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets('conflict preserves form and reloads slots before retry', (
    tester,
  ) async {
    final api = AppointmentApi()..conflicts = 1;
    await mount(tester, api);
    await startBooking(tester);
    await tapText(tester, '10:00 – 10:50');
    await tapText(tester, 'Request appointment');
    expect(
      find.text(
        'That time is no longer available. Please choose another slot.',
      ),
      findsOneWidget,
    );
    expect(
      api.requests.where((r) => r.path.endsWith('/availability')).length,
      2,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Request appointment'),
          )
          .onPressed,
      isNull,
    );
    await tapText(tester, '12:00 – 12:50');
    await tapText(tester, 'Request appointment');
    expect(api.appointments.single['startTime'], '12:00');
  });

  testWidgets(
    'rescheduling keeps clinician and type and submits optional reason',
    (tester) async {
      final api = AppointmentApi()..seed();
      await mount(tester, api);
      await tapText(tester, 'Reschedule');
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      await tapText(tester, '12:00 – 12:50');
      await tester.enterText(find.byType(TextField), 'Work conflict');
      await tapText(tester, 'Request reschedule');
      final request = api.requests.singleWhere(
        (r) => r.path.endsWith('/reschedule'),
      );
      expect(request.method, 'POST');
      expect(
        request.path,
        '/api/patient/appointments/appointment-1/reschedule',
      );
      expect(request.data['note'], 'Work conflict');
      expect(request.data['startTime'], '12:00');
      expect((request.data as Map).containsKey('clinicianId'), isFalse);
      expect((request.data as Map).containsKey('type'), isFalse);
      expect(api.listReads, 2);
    },
  );

  testWidgets(
    'cancellation requires confirmation and retains visit on failure',
    (tester) async {
      final api = AppointmentApi()..seed();
      await mount(tester, api);
      await tapText(tester, 'Cancel appointment');
      await tapText(tester, 'Keep appointment');
      expect(api.requests.where((r) => r.path.endsWith('/cancel')), isEmpty);
      api.failCancel = true;
      await tapText(tester, 'Cancel appointment');
      await tapText(tester, 'Confirm cancellation');
      expect(find.text('This appointment cannot be cancelled'), findsOneWidget);
      expect(api.appointments, hasLength(1));
      api.failCancel = false;
      await tapText(tester, 'Confirm cancellation');
      expect(api.appointments, isEmpty);
      expect(find.text('No appointments yet'), findsOneWidget);
      expect(find.text('Appointment cancelled.'), findsOneWidget);
      expect(api.listReads, 2);
    },
  );

  testWidgets(
    'missing clinician offers care team contact instead of guessing a provider',
    (tester) async {
      final api = AppointmentApi()..seed(clinician: false);
      await mount(tester, api);
      await tapText(tester, 'Reschedule');
      expect(find.text('Contact your care team'), findsOneWidget);
      expect(
        api.requests.where((r) => r.path.endsWith('/availability')),
        isEmpty,
      );
      await tester.scrollUntilVisible(
        find.text('Request reschedule'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Request reschedule'),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets('availability error can be retried on a narrow screen', (
    tester,
  ) async {
    final api = AppointmentApi()..failSlots = true;
    await mount(tester, api, size: const Size(320, 700));
    await startBooking(tester);
    await tester.scrollUntilVisible(
      find.text('Availability temporarily unavailable'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Availability temporarily unavailable'), findsOneWidget);
    api.failSlots = false;
    await tapText(tester, 'Try again');
    expect(find.text('10:00 – 10:50'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('date change clears selection and uses the selected date', (
    tester,
  ) async {
    final api = AppointmentApi();
    await mount(tester, api);
    await startBooking(tester);
    await tapText(tester, '10:00 – 10:50');
    final picker = find.widgetWithIcon(
      OutlinedButton,
      Icons.calendar_month_outlined,
    );
    await tester.ensureVisible(picker);
    await tester.pumpAndSettle();
    await tester.tap(picker);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    await tapText(tester, '15');
    await tapText(tester, 'OK');
    final now = DateTime.now();
    final nextMonth = DateTime(now.year, now.month + 1, 15);
    final expected = nextMonth.toIso8601String().split('T').first;
    final request = api.requests.lastWhere(
      (r) => r.path.endsWith('/availability'),
    );
    expect(request.queryParameters, {'from': expected, 'days': 1});
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Request appointment'),
          )
          .onPressed,
      isNull,
    );
    await tapText(tester, '12:00 – 12:50');
    final videoSwitch = find.byType(SwitchListTile);
    await tester.ensureVisible(videoSwitch);
    await tester.pumpAndSettle();
    await tester.tap(videoSwitch);
    await tester.pumpAndSettle();
    await tapText(tester, 'Request appointment');
    final saved = api.requests.singleWhere((r) => r.method == 'POST').data;
    expect(saved['date'], expected);
    expect(saved['isVirtual'], isTrue);
  });

  testWidgets('empty availability has guidance and prevents submission', (
    tester,
  ) async {
    final api = AppointmentApi()..emptySlots = true;
    await mount(tester, api);
    await startBooking(tester);
    expect(find.text('No available times'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Request appointment'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('submission is disabled while a request is in flight', (
    tester,
  ) async {
    final api = AppointmentApi()..pendingSave = Completer<void>();
    await mount(tester, api);
    await startBooking(tester);
    await tapText(tester, '10:00 – 10:50');
    final submit = find.widgetWithText(FilledButton, 'Request appointment');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Saving…'))
          .onPressed,
      isNull,
    );
    expect(api.requests.where((r) => r.method == 'POST'), hasLength(1));
    api.pendingSave!.complete();
    await tester.pumpAndSettle();
    expect(api.appointments, hasLength(1));
  });
}
