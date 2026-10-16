import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:altrix/features/auth/domain/entities/user.dart';
import 'package:altrix/features/auth/presentation/providers/auth_providers.dart';
import 'package:altrix/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:altrix/features/patient/data/models/patient_models.dart';
import 'package:altrix/features/patient/presentation/providers/patient_providers.dart';
import 'package:altrix/features/profile/data/medical_summary_pdf_service.dart';
import 'package:altrix/features/profile/presentation/screens/privacy_security_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('NotificationsScreen', () {
    testWidgets('renders tabs, filter chips, and preference toggles', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final prefs = await SharedPreferences.getInstance();

      final notifications = PatientNotificationPage.fromJson({
        'success': true,
        'data': {
          'notifications': [
            {
              'id': 'notification-1',
              'type': 'chat_message',
              'title': 'Care Team Note',
              'message': 'Your clinician reviewed your wellness check-in.',
              'createdAt': '2026-10-16T10:00:00.000Z',
              'isRead': false,
            },
            {
              'id': 'notification-2',
              'type': 'appointment_confirmed',
              'title': 'Appointment Confirmed',
              'message': 'Telehealth visit scheduled for tomorrow.',
              'createdAt': '2026-10-15T10:00:00.000Z',
              'isRead': true,
            },
          ],
          'pagination': {'page': 1, 'limit': 20, 'total': 2, 'hasMore': false},
          'unreadCount': 1,
        },
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            patientNotificationsProvider.overrideWith((ref) => notifications),
          ],
          child: const MaterialApp(home: NotificationsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Check title and tabs
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Alerts & Activity'), findsOneWidget);
      expect(find.text('Preferences'), findsOneWidget);

      // Check alerts content
      expect(find.text('Care Team Note'), findsOneWidget);
      expect(find.text('Appointment Confirmed'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Unread'), findsOneWidget);

      // Tap on Preferences tab
      await tester.tap(find.text('Preferences'));
      await tester.pumpAndSettle();

      // Check preferences content
      expect(find.text('Push Notifications'), findsOneWidget);
      expect(find.text('Clinical & Care Alerts'), findsOneWidget);
      expect(find.text('Appointment Reminders'), findsOneWidget);
      expect(find.text('Care Team Messages'), findsOneWidget);
      expect(find.text('Daily Wellness Check-in'), findsOneWidget);
      expect(find.text('Delivery Channels'), findsOneWidget);
      expect(find.text('Quiet Hours'), findsOneWidget);
    });
  });

  group('PrivacySecurityScreen', () {
    testWidgets(
      'renders HIPAA status, auto-lock, and legal links without biometric unlock',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final prefs = await SharedPreferences.getInstance();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
            child: const MaterialApp(home: PrivacySecurityScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Privacy & Security'), findsOneWidget);
        expect(find.text('HIPAA-Ready & Encrypted'), findsOneWidget);
        expect(find.text('256-Bit AES Data Protection'), findsOneWidget);
        // Biometric unlock is deleted as requested
        expect(find.text('Biometric Unlock'), findsNothing);
        expect(find.text('Auto-Lock Timeout'), findsOneWidget);
        expect(find.text('Two-Factor Authentication (2FA)'), findsOneWidget);
        expect(find.text('Care Team Access'), findsOneWidget);
        expect(find.text('Emergency Medical Access'), findsOneWidget);
        expect(find.text('Export Medical Summary'), findsOneWidget);
        expect(find.text('Notice of Privacy Practices'), findsOneWidget);
        expect(find.text('Delete Account & Data'), findsOneWidget);
      },
    );

    test('MedicalSummaryPdfService generates valid PDF bytes', () async {
      const testUser = User(
        id: 'patient-test-123',
        name: 'John Doe',
        email: 'johndoe@example.com',
        phone: '+1 555-0199',
        emergencyContactName: 'Jane Doe',
        emergencyContactPhone: '+1 555-0198',
      );

      final pdfBytes = await MedicalSummaryPdfService.generatePdf(
        user: testUser,
        appointments: [
          AppointmentModel.fromJson(const {
            'id': 'appt-1',
            'title': 'Consultation',
            'providerName': 'Dr. Sarah Connor',
            'date': '2026-09-20',
            'startTime': '10:00',
            'endTime': '10:50',
            'isVirtual': true,
            'status': 'confirmed',
          }),
        ],
        checkIns: [
          CheckInModel.fromJson(const {
            'id': 'chk-1',
            'mood': 4,
            'stress': 2,
            'sleep': 8,
            'notes': 'Feeling energetic and well-rested',
            'createdAt': '2026-09-14',
          }),
        ],
      );

      expect(pdfBytes, isNotEmpty);
      // PDF documents always start with "%PDF-"
      final header = String.fromCharCodes(pdfBytes.take(5));
      expect(header, '%PDF-');
    });

    testWidgets(
      'Export Medical Summary displays Chrome-style download notification with Open action',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final prefs = await SharedPreferences.getInstance();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              appointmentsProvider.overrideWith((ref) async => []),
              checkInsProvider.overrideWith((ref) async => []),
              progressProvider.overrideWith(
                (ref) async => ProgressModel.fromJson(const {}),
              ),
            ],
            child: const MaterialApp(home: PrivacySecurityScreen()),
          ),
        );
        await tester.pumpAndSettle();

        final exportTileFinder = find.text('Export Medical Summary');
        await tester.ensureVisible(exportTileFinder);
        await tester.pumpAndSettle();

        // Tap Export Medical Summary
        await tester.tap(exportTileFinder);
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 500));
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Verify Chrome-style download notification appears
        expect(find.text('File downloaded · Tap to open'), findsOneWidget);
        expect(find.text('Open'), findsOneWidget);

        // Tap Open
        await tester.tap(find.text('Open'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Verify PdfSummaryViewerScreen opened
        expect(find.text('Encrypted Medical Summary'), findsOneWidget);
        expect(find.byTooltip('Share / Save PDF'), findsOneWidget);
        expect(find.byTooltip('Print Summary'), findsOneWidget);
      },
    );
  });
}
