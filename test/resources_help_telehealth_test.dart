import 'package:dio/dio.dart';
import 'package:altrix/features/telehealth/data/repositories/telehealth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:altrix/features/help/presentation/screens/help_center_screen.dart';
import 'package:altrix/features/patient/data/models/patient_models.dart';
import 'package:altrix/features/patient/presentation/providers/patient_providers.dart';
import 'package:altrix/features/patient/presentation/screens/appointment_editor_screen.dart';
import 'package:altrix/features/resources/presentation/screens/resources_screen.dart';
import 'package:altrix/features/telehealth/presentation/screens/in_app_zoom_meeting_screen.dart';
import 'package:altrix/features/telehealth/presentation/screens/telehealth_room_screen.dart';
import 'package:altrix/widgets/appointment_actions.dart';

void main() {
  testWidgets(
    'HelpCenterScreen renders hero, search, contact options, and FAQs',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const MaterialApp(home: HelpCenterScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Help Center'), findsOneWidget);
      expect(find.text('How can we help you today?'), findsOneWidget);
      expect(find.text('Support Ticket'), findsOneWidget);
      expect(find.text('Call Clinic'), findsOneWidget);
      expect(find.text('Email Us'), findsOneWidget);
      expect(find.text('Frequently Asked Questions'), findsOneWidget);

      // Expand first FAQ
      final firstFaq = find.text(
        'How do I join my virtual telehealth video visit?',
      );
      expect(firstFaq, findsOneWidget);
      await tester.tap(firstFaq);
      await tester.pumpAndSettle();

      expect(find.textContaining('Telehealth Lobby'), findsOneWidget);

      // Open Contact Support modal
      await tester.tap(find.text('Support Ticket'));
      await tester.pumpAndSettle();
      expect(find.text('Contact Clinic Support'), findsOneWidget);
      expect(find.text('Submit Ticket'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'ResourcesScreen renders Health Library, Forms tab, and Crisis Hotlines',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockForms = [
        PatientFormModel.fromJson(const {
          'id': 'form-123',
          'title': 'Telehealth Intake Questionnaire',
          'status': 'pending',
          'dueAt': 'Tomorrow at 5:00 PM',
          'description': 'Mandatory medical disclosure',
        }),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            formsProvider.overrideWith((ref) async => mockForms),
            formDetailProvider('form-123')
                .overrideWith((ref) async => mockForms.first),
          ],
          child: const MaterialApp(home: ResourcesScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Tab 1: Health Library
      expect(find.text('Health Library'), findsOneWidget);
      expect(find.text('CBT Thought Record Worksheet'), findsOneWidget);
      expect(
        find.text('5-4-3-2-1 Sensory Grounding Technique'),
        findsOneWidget,
      );

      // Switch to Tab 2: Forms & Consents
      await tester.tap(find.text('Forms & Consents'));
      await tester.pumpAndSettle();

      expect(find.text('Required Intake & Consents'), findsOneWidget);
      expect(find.text('Telehealth Intake Questionnaire'), findsOneWidget);
      expect(find.text('Open Form'), findsOneWidget);

      // Switch to Tab 3: Crisis Hotlines
      await tester.tap(find.text('Crisis Hotlines'));
      await tester.pumpAndSettle();

      expect(find.text('988 Suicide & Crisis Lifeline'), findsOneWidget);
      expect(find.text('Crisis Text Line'), findsOneWidget);
    },
  );

  testWidgets('Chime waiting room confirms only successful check-in', (
    tester,
  ) async {
    final repo = _TestTelehealthRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [telehealthRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          home: TelehealthRoomScreen(joinToken: 'token'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Telehealth waiting room'), findsOneWidget);
    await tester.tap(find.text("I'm Here / Check In"));
    await tester.pumpAndSettle();
    expect(find.text('Check-in failed. Please try again.'), findsOneWidget);
    expect(find.text('Checked in'), findsNothing);
    repo.failCheckIn = false;
    await tester.tap(find.text("I'm Here / Check In"));
    await tester.pumpAndSettle();
    expect(find.text('Checked in'), findsOneWidget);
  });

  testWidgets(
    'AppointmentEditorScreen displays visit format options for virtual booking',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            doctorsProvider.overrideWith((ref) async => const <DoctorModel>[]),
          ],
          child: const MaterialApp(home: AppointmentEditorScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Virtual Video visit'), findsOneWidget);

      // Tap Virtual Video visit switch
      await tester.tap(find.text('Virtual Video visit'));
      await tester.pumpAndSettle();

      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);
      final switchWidget = tester.widget<Switch>(switchFinder);
      expect(switchWidget.value, isTrue);
    },
  );

  test('AppointmentModel automatically generates Zoom meeting link for virtual visits', () {
    final virtualAppt = AppointmentModel.fromJson(const {
      'id': 'appt-telehealth-987654321',
      'title': 'Telehealth Therapy',
      'isVirtual': true,
      'date': '2026-09-15',
      'startTime': '11:00',
      'endTime': '11:50',
    });

    expect(virtualAppt.isVirtual, isTrue);
    expect(virtualAppt.hasJoinLink, isTrue);
    expect(virtualAppt.effectiveJoinUrl, startsWith('https://zoom.us/j/'));

    // If custom meetingUrl or zoomUrl provided, it preserves the exact meeting
    final customZoomAppt = AppointmentModel.fromJson(const {
      'id': 'appt-custom-1',
      'title': 'Zoom Consultation',
      'isVirtual': true,
      'zoomUrl': 'https://us05web.zoom.us/j/86415304776?pwd=secretPassword123',
    });
    expect(
      customZoomAppt.effectiveJoinUrl,
      'https://us05web.zoom.us/j/86415304776?pwd=secretPassword123',
    );
  });

  test(
    'isSlotInFuture excludes past times for today and keeps future times',
    () {
      final referenceNow = DateTime(2026, 9, 14, 14, 30); // 2:30 PM today

      const pastMorningSlot = AvailabilitySlotModel(
        date: '2026-09-14',
        startTime: '10:00',
        endTime: '10:50',
        raw: {'available': true},
      );
      const pastNoonSlot = AvailabilitySlotModel(
        date: '2026-09-14',
        startTime: '14:00',
        endTime: '14:50',
        raw: {'available': true},
      );
      const futureAfternoonSlot = AvailabilitySlotModel(
        date: '2026-09-14',
        startTime: '15:00',
        endTime: '15:50',
        raw: {'available': true},
      );
      const tomorrowMorningSlot = AvailabilitySlotModel(
        date: '2026-09-15',
        startTime: '09:00',
        endTime: '09:50',
        raw: {'available': true},
      );

      // Past morning and noon slots on today are excluded
      expect(isSlotInFuture(pastMorningSlot, referenceNow), isFalse);
      expect(isSlotInFuture(pastNoonSlot, referenceNow), isFalse);

      // Future afternoon slot on today is included
      expect(isSlotInFuture(futureAfternoonSlot, referenceNow), isTrue);

      // Tomorrow morning slot is included
      expect(isSlotInFuture(tomorrowMorningSlot, referenceNow), isTrue);
    },
  );

  test(
    'InAppZoomMeetingScreen converts standard Zoom URL to Web Client join URL',
    () {
      const standardUrl = 'https://zoom.us/j/84930291029?pwd=testPassword123';
      final webClientUrl = InAppZoomMeetingScreen.toZoomWebClientUrl(
        standardUrl,
      );
      expect(
        webClientUrl,
        'https://app.zoom.us/wc/84930291029/join?pwd=testPassword123',
      );

      // Extracts meeting ID cleanly
      final meetingId = InAppZoomMeetingScreen.extractMeetingId(standardUrl);
      expect(meetingId, '84930291029');
    },
  );

  testWidgets(
    'InAppZoomMeetingScreen renders top bar, controls, and handles end meeting dialog',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final appointment = AppointmentModel.fromJson(const {
        'id': 'appt-zoom-1',
        'title': 'Dr. Marcus Vance',
        'providerName': 'Dr. Marcus Vance',
        'isVirtual': true,
        'zoomUrl': 'https://zoom.us/j/9876543210',
      });

      await tester.pumpWidget(
        MaterialApp(
          home: InAppZoomMeetingScreen(
            meetingUrl: appointment.effectiveJoinUrl,
            appointment: appointment,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header checks
      expect(find.text('ZOOM'), findsOneWidget);
      expect(find.text('Dr. Marcus Vance'), findsWidgets);
      expect(find.textContaining('Meeting ID: 9876543210'), findsOneWidget);
      expect(find.text('Open in App'), findsOneWidget);

      // Call controls check
      expect(find.text('Mute'), findsOneWidget);
      expect(find.text('Stop Video'), findsOneWidget);
      expect(find.text('Speaker'), findsOneWidget);
      expect(find.text('Leave'), findsOneWidget);

      // Tap Mute
      await tester.tap(find.text('Mute'));
      await tester.pumpAndSettle();
      expect(find.text('Unmute'), findsOneWidget);

      // Tap Leave to open dialog
      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();
      expect(find.text('End Zoom Meeting?'), findsOneWidget);
      expect(find.text('Stay in Meeting'), findsOneWidget);
      expect(find.text('Leave Call'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('Stay in Meeting'));
      await tester.pumpAndSettle();
      expect(find.text('End Zoom Meeting?'), findsNothing);
    },
  );

  test('AppointmentModel join window checks enforce 5-minute threshold', () {
    final appt = AppointmentModel.fromJson(const {
      'id': 'appt-test-time',
      'title': 'Therapy Session',
      'date': '2026-09-14',
      'startTime': '15:00',
      'endTime': '15:50',
      'isVirtual': true,
      'joinUrl': 'https://zoom.us/j/1234567890',
    });

    // 10 minutes before (2:50 PM): too early to join
    final tenMinBefore = DateTime(2026, 9, 14, 14, 50);
    expect(appt.isTooEarlyToJoin(tenMinBefore), isTrue);
    expect(appt.canJoinMeeting(tenMinBefore), isFalse);

    // 6 minutes before (2:54 PM): too early to join
    final sixMinBefore = DateTime(2026, 9, 14, 14, 54);
    expect(appt.isTooEarlyToJoin(sixMinBefore), isTrue);
    expect(appt.canJoinMeeting(sixMinBefore), isFalse);

    // Exactly 5 minutes before (2:55 PM): able to join
    final fiveMinBefore = DateTime(2026, 9, 14, 14, 55);
    expect(appt.isTooEarlyToJoin(fiveMinBefore), isFalse);
    expect(appt.canJoinMeeting(fiveMinBefore), isTrue);

    // 2 minutes before (2:58 PM): able to join
    final twoMinBefore = DateTime(2026, 9, 14, 14, 58);
    expect(appt.isTooEarlyToJoin(twoMinBefore), isFalse);
    expect(appt.canJoinMeeting(twoMinBefore), isTrue);

    // During meeting (3:15 PM): able to join
    final duringMeeting = DateTime(2026, 9, 14, 15, 15);
    expect(appt.isTooEarlyToJoin(duringMeeting), isFalse);
    expect(appt.canJoinMeeting(duringMeeting), isTrue);

    // Well after meeting (5:00 PM): concluded
    final wellAfter = DateTime(2026, 9, 14, 17, 0);
    expect(appt.isMeetingConcluded(wellAfter), isTrue);
    expect(appt.canJoinMeeting(wellAfter), isFalse);
  });

  testWidgets(
    'openAppointmentJoin shows snackbar when meeting has more than 5 minutes remaining',
    (tester) async {
      final appt = AppointmentModel.fromJson(const {
        'id': 'appt-test-early',
        'title': 'Therapy Session',
        'date': '2026-09-14',
        'startTime': '15:00',
        'endTime': '15:50',
        'isVirtual': true,
        'joinUrl': 'https://zoom.us/j/1234567890',
      });

      final testNow = DateTime(2026, 9, 14, 14, 30); // 30 minutes before

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () =>
                    openAppointmentJoin(context, appt, currentTime: testNow),
                child: const Text('Join'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Join'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.textContaining(
          "You can't join the meeting yet. You can join starting 5 minutes before",
        ),
        findsOneWidget,
      );
      // Did not navigate to Telehealth Lobby
      expect(find.text('Telehealth waiting room'), findsNothing);
    },
  );

  testWidgets(
    'openAppointmentJoin navigates to Telehealth Lobby when 5 minutes or less remain',
    (tester) async {
      final appt = AppointmentModel.fromJson(const {
        'id': 'appt-test-ontime',
        'title': 'Therapy Session',
        'date': '2026-09-14',
        'startTime': '15:00',
        'endTime': '15:50',
        'isVirtual': true,
        'joinToken': 'token-ontime',
        'joinUrl': 'https://zoom.us/j/1234567890',
      });

      final testNow = DateTime(2026, 9, 14, 14, 57); // 3 minutes before

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            telehealthRepositoryProvider.overrideWithValue(
              _TestTelehealthRepository(),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () =>
                      openAppointmentJoin(context, appt, currentTime: testNow),
                  child: const Text('Join'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Join'));
      await tester.pumpAndSettle();

      // Navigated to Telehealth Lobby
      expect(find.text('Telehealth waiting room'), findsOneWidget);
      expect(
        find.textContaining("You can't join the meeting yet"),
        findsNothing,
      );
    },
  );

  testWidgets(
    'openAppointmentJoin blocks entry when camera/mic permission is denied',
    (tester) async {
      final appt = AppointmentModel.fromJson(const {
        'id': 'appt-test-perm-denied',
        'title': 'Therapy Session',
        'date': '2026-09-14',
        'startTime': '15:00',
        'endTime': '15:50',
        'isVirtual': true,
        'joinToken': 'token-perm-denied',
        'joinUrl': 'https://zoom.us/j/1234567890',
      });

      final testNow = DateTime(2026, 9, 14, 14, 58);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => openAppointmentJoin(
                  context,
                  appt,
                  currentTime: testNow,
                  permissionRequester: () async =>
                      false, // User denies camera/mic
                ),
                child: const Text('Join Zoom Visit'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Join Zoom Visit'));
      await tester.pumpAndSettle();

      // Did not open Telehealth Lobby because permission was not granted
      expect(find.text('Telehealth waiting room'), findsNothing);
    },
  );

  testWidgets(
    'openAppointmentJoin proceeds when camera/mic permission is granted',
    (tester) async {
      final appt = AppointmentModel.fromJson(const {
        'id': 'appt-test-perm-granted',
        'title': 'Therapy Session',
        'date': '2026-09-14',
        'startTime': '15:00',
        'endTime': '15:50',
        'isVirtual': true,
        'joinToken': 'token-perm-granted',
        'joinUrl': 'https://zoom.us/j/1234567890',
      });

      final testNow = DateTime(2026, 9, 14, 14, 58);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            telehealthRepositoryProvider.overrideWithValue(
              _TestTelehealthRepository(),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => openAppointmentJoin(
                    context,
                    appt,
                    currentTime: testNow,
                    permissionRequester: () async =>
                        true, // User grants camera/mic
                  ),
                  child: const Text('Join Zoom Visit'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Join Zoom Visit'));
      await tester.pumpAndSettle();

      // Successfully opened Telehealth Lobby
      expect(find.text('Telehealth waiting room'), findsOneWidget);
    },
  );
}

class _TestTelehealthRepository extends TelehealthRepository {
  _TestTelehealthRepository() : super(Dio());
  bool failCheckIn = true;
  @override
  Future<Map<String, dynamic>> details(String token) async => {
    'clientName': 'Patient',
    'clinicianName': 'Dr. Marcus Vance',
    'chimeReady': true,
  };
  @override
  Future<Map<String, dynamic>> here(String token) async {
    if (failCheckIn) throw Exception('offline');
    return {};
  }
}
