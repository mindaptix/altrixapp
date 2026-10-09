import 'dart:convert';

import 'package:altrix/core/network/dio_client.dart';
import 'package:altrix/features/chatbot/presentation/widgets/floating_chatbot.dart';
import 'package:altrix/features/patient/data/models/patient_models.dart';
import 'package:altrix/features/patient/presentation/providers/patient_providers.dart';
import 'package:altrix/features/profile/data/account_portal_data.dart';
import 'package:altrix/features/profile/presentation/providers/account_portal_provider.dart';
import 'package:altrix/features/profile/presentation/screens/account_portal_screen.dart';
import 'package:altrix/theme/app_theme.dart';
import 'package:altrix/screens/placeholder_screens.dart' show ProfileScreen;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _account = AccountPortalData(
  primary: InsurancePlan(
    carrier: 'Test Health Plan',
    memberId: 'TEST-123',
    groupNumber: 'GROUP-1',
    copay: '\$20',
    deductible: '\$500',
    status: 'active',
  ),
  billing: BillingSummary(
    balanceDue: 42,
    paymentMethod: 'Insurance on file',
    history: [
      BillingEntry(
        description: 'Therapy visit',
        amount: 20,
        status: 'paid',
        date: '2026-10-01',
      ),
    ],
  ),
);

class _PhotoPicker extends AccountPhotoPicker {
  @override
  Future<SelectedAccountPhoto?> pick() async => SelectedAccountPhoto(
    name: 'test-card.png',
    bytes: base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==',
    ),
  );
}

void main() {
  testWidgets('Me opens each account section without the floating chatbot', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountPortalProvider.overrideWith((ref) async => _account),
          appointmentsProvider.overrideWith((ref) async => []),
          formsProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Overlay.wrap(
            child: const FloatingChatbot(child: ProfileScreen()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final section in AccountSection.values) {
      await tester.scrollUntilVisible(find.text(section.label), 150);
      await tester.pumpAndSettle();
      await tester.tap(find.text(section.label));
      await tester.pumpAndSettle();
      expect(find.byType(AccountPortalScreen), findsOneWidget);
      expect(find.text(section.label), findsOneWidget);
      for (final other in AccountSection.values.where(
        (item) => item != section,
      )) {
        expect(find.text(other.label), findsNothing);
      }
      expect(
        find.byTooltip('Open Altrixs help chat. Drag to move.'),
        findsNothing,
      );
      expect(
        find.text(switch (section) {
          AccountSection.insurance => 'Primary Insurance',
          AccountSection.documents => 'Photo ID',
          AccountSection.billing => 'Current Balance',
        }),
        findsOneWidget,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        find.byTooltip('Open Altrixs help chat. Drag to move.'),
        findsOneWidget,
      );
    }
    expect(tester.takeException(), isNull);
  });
  test(
    'absent financial data remains unknown, while zero balances remain zero',
    () {
      expect(
        AccountPortalData.fromProfile({'name': 'Patient'}).billing.balanceDue,
        isNull,
      );
      final account = AccountPortalData.fromProfile({
        'data': {
          'client': {
            'billing': {'balanceDue': 0},
          },
        },
      });
      expect(account.billing.balanceDue, 0);
      expect(account.primary, isNull);
    },
  );

  test('reads React-shaped and nested profile account sections', () {
    final flat = AccountPortalData.fromProfile({
      'insurance': {
        'primaryCarrier': 'Plan',
        'primaryMemberId': '123',
        'primaryGroup': 'A',
        'primaryCopay': '\$0',
        'secondaryCarrier': 'None',
      },
    });
    expect(flat.primary?.carrier, 'Plan');
    expect(flat.primary?.groupNumber, 'A');
    expect(flat.secondary, isNull);
    final nested = AccountPortalData.fromProfile({
      'client': {
        'insurance': {
          'primary': {'carrier': 'Plan', 'memberId': '123'},
        },
        'documents': [
          {'type': 'id_front', 'name': 'ID', 'status': 'received'},
        ],
        'billing': {
          'history': [
            {'desc': 'Visit', 'amount': 12, 'status': 'pending'},
          ],
        },
      },
    });
    expect(nested.primary?.memberId, '123');
    expect(nested.documents.single.type, 'id_front');
    expect(nested.billing.history.single.status, 'pending');
  });

  Future<void> pumpPortal(
    WidgetTester tester, {
    AccountSection section = AccountSection.insurance,
    AccountPortalData account = _account,
    Dio? dio,
    double width = 390,
  }) async {
    await tester.binding.setSurfaceSize(Size(width, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountPortalProvider.overrideWith((ref) async => account),
          accountPhotoPickerProvider.overrideWithValue(_PhotoPicker()),
          appointmentsProvider.overrideWith((ref) async => []),
          formsProvider.overrideWith(
            (ref) async => [
              const PatientFormModel(
                id: 'consent-1',
                title: 'Consent to Treatment',
                status: 'signed',
                dueAt: '',
                description: 'A consent shared by your clinic.',
                signedAt: '2026-10-01',
                raw: {},
              ),
            ],
          ),
          if (dio != null) dioProvider.overrideWithValue(dio),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: AccountPortalScreen(
            key: ValueKey(section),
            initialSection: section,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'dedicated insurance, document and billing pages work on a phone',
    (tester) async {
      await pumpPortal(tester);
      expect(find.text('Test Health Plan'), findsOneWidget);
      expect(find.text('TEST-123'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Choose photo').first, 200);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose photo').first);
      await tester.pumpAndSettle();
      expect(find.text('Selected for preview • not submitted'), findsOneWidget);
      expect(find.text('test-card.png'), findsOneWidget);
      await pumpPortal(tester, section: AccountSection.documents);
      expect(find.text('Photo ID (Front)'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Consent to Treatment'), 200);
      await tester.pumpAndSettle();
      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Signed: Oct 1, 2026'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await pumpPortal(tester, section: AccountSection.billing);
      expect(find.text('\$42.00'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Therapy visit'), 200);
      await tester.pumpAndSettle();
      expect(find.text('Paid'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('missing balance is not shown as paid and desktop cards fit', (
    tester,
  ) async {
    await pumpPortal(
      tester,
      section: AccountSection.billing,
      account: const AccountPortalData(),
      width: 1000,
    );
    expect(find.text('Not available'), findsOneWidget);
    expect(find.text('\$0.00'), findsNothing);
    expect(find.textContaining('no payment due'), findsNothing);
    await pumpPortal(tester, section: AccountSection.documents, width: 1000);
    expect(find.text('Photo ID (Front)'), findsOneWidget);
    expect(find.text('Photo ID (Back)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'billing contact sends a real request and only acknowledges success',
    (tester) async {
      final dio = Dio();
      var requests = 0;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests++;
            expect(options.path, '/api/patient/conversations');
            expect(options.data['topic'], 'billing');
            expect(options.data['message'], contains('secure payment options'));
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'success': true,
                  'data': {
                    'conversation': {
                      'id': 'billing-thread',
                      'title': 'Billing',
                    },
                  },
                },
              ),
            );
          },
        ),
      );
      await pumpPortal(tester, section: AccountSection.billing, dio: dio);
      await tester.tap(find.text('Request payment options'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Photos and payment details are not attached'),
        findsOneWidget,
      );
      await tester.runAsync(() async {
        await tester.tap(find.text('Send message'));
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await tester.pumpAndSettle();
      expect(requests, 1);
      expect(
        find.text('Your message was sent. Find the conversation in Messages.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed clinic request keeps the draft and does not claim success',
    (tester) async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
              ),
            );
          },
        ),
      );
      await pumpPortal(tester, section: AccountSection.billing, dio: dio);
      await tester.tap(find.text('Request payment options'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Send message'));
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await tester.pumpAndSettle();
      expect(find.text('Message not sent. Please try again.'), findsOneWidget);
      expect(find.textContaining('Your message was sent.'), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
