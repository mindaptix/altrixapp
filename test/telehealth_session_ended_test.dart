import 'package:altrix/features/telehealth/data/repositories/telehealth_repository.dart';
import 'package:altrix/features/telehealth/presentation/screens/telehealth_waiting_room_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpWaitingRoom(
    WidgetTester tester,
    TelehealthRepository repository,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [telehealthRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          home: TelehealthWaitingRoomScreen(
            joinToken: 'join-token',
            videoCallBuilder: (_, _) =>
                const Scaffold(body: Text('Video call active')),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> tapJoin(WidgetTester tester) async {
    await tester.tap(find.text('Join Video Call Now'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('active session navigates to the video call', (tester) async {
    await pumpWaitingRoom(
      tester,
      _FakeTelehealthRepository(
        joinResult: const {
          'meeting': {'MeetingId': 'meeting', 'MediaPlacement': {}},
          'attendee': {'AttendeeId': 'patient', 'JoinToken': 'secret'},
        },
      ),
    );

    await tapJoin(tester);
    await tester.pumpAndSettle();

    expect(find.text('Video call active'), findsOneWidget);
  });

  testWidgets('ended session shows the ended-session SnackBar', (tester) async {
    await pumpWaitingRoom(
      tester,
      _FakeTelehealthRepository(
        joinError: const TelehealthSessionEndedException(),
      ),
    );

    await tapJoin(tester);

    expect(
      find.text('Session ended. You can no longer join this call.'),
      findsOneWidget,
    );
    expect(find.text('Video call active'), findsNothing);
  });

  testWidgets('ended GET opened from notification shows telehealth SnackBar', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          telehealthRepositoryProvider.overrideWithValue(
            _FakeTelehealthRepository(
              detailsError: const TelehealthSessionEndedException(),
            ),
          ),
        ],
        child: const MaterialApp(
          home: TelehealthWaitingRoomScreen(joinToken: 'ended-token'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Telehealth video has ended.'), findsWidgets);
    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.behavior, SnackBarBehavior.floating);
    expect(snackBar.duration, const Duration(seconds: 3));
  });

  testWidgets('expired session shows the ended-session SnackBar', (
    tester,
  ) async {
    await pumpWaitingRoom(
      tester,
      _FakeTelehealthRepository(
        joinError: const TelehealthSessionEndedException(),
      ),
    );

    await tapJoin(tester);

    expect(
      find.text('Session ended. You can no longer join this call.'),
      findsOneWidget,
    );
  });

  testWidgets('invalid Chime response shows visit-not-ready message', (
    tester,
  ) async {
    await pumpWaitingRoom(
      tester,
      _FakeTelehealthRepository(
        joinError: const FormatException(
          'The visit is not ready. Please try again.',
        ),
      ),
    );

    await tapJoin(tester);

    expect(
      find.text('The visit is not ready. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('network failure shows internet connection message', (
    tester,
  ) async {
    await pumpWaitingRoom(
      tester,
      _FakeTelehealthRepository(joinError: const TelehealthNetworkException()),
    );

    await tapJoin(tester);

    expect(find.text('Please check your internet connection.'), findsOneWidget);
    expect(
      find.text('Session ended. You can no longer join this call.'),
      findsNothing,
    );
  });

  testWidgets('HTTP 500 shows generic join error', (tester) async {
    await pumpWaitingRoom(
      tester,
      _FakeTelehealthRepository(
        joinError: DioException(
          requestOptions: RequestOptions(path: '/api/telehealth/join/token'),
          response: Response<void>(
            requestOptions: RequestOptions(path: '/api/telehealth/join/token'),
            statusCode: 500,
          ),
          type: DioExceptionType.badResponse,
        ),
      ),
    );

    await tapJoin(tester);

    expect(
      find.text('Unable to join the call. Please try again.'),
      findsOneWidget,
    );
    expect(
      find.text('Session ended. You can no longer join this call.'),
      findsNothing,
    );
  });
}

class _FakeTelehealthRepository extends TelehealthRepository {
  _FakeTelehealthRepository({
    this.joinResult,
    this.joinError,
    this.detailsError,
  }) : super(Dio());

  final Map<String, dynamic>? joinResult;
  final Object? joinError;
  final Object? detailsError;

  @override
  Future<Map<String, dynamic>> details(String token) async {
    final error = detailsError;
    if (error != null) throw error;
    return const {
      'clientName': 'Patient',
      'clinicianName': 'Dr Rivera',
      'chimeReady': true,
    };
  }

  @override
  Future<Map<String, dynamic>> join(String token) async {
    final error = joinError;
    if (error != null) throw error;
    return joinResult!;
  }
}
