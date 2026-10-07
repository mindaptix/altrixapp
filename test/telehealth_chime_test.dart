import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:altrix/features/telehealth/data/repositories/telehealth_repository.dart';
import 'package:altrix/core/network/interceptors/auth_interceptor.dart';

class Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  Object body = {'clientName': 'Patient', 'chimeReady': false};
  int status = 200;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Adapter adapter;
  late TelehealthRepository repo;
  setUp(() {
    adapter = Adapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.httpClientAdapter = adapter;
    repo = TelehealthRepository(dio);
  });
  test(
    'public details and check-in use encoded token and exact action',
    () async {
      await repo.details('abc/def');
      await repo.here('abc/def');
      expect(adapter.requests.first.method, 'GET');
      expect(adapter.requests.first.path, '/api/telehealth/join/abc%2Fdef');
      expect(
        adapter.requests.first.headers.containsKey('Authorization'),
        false,
      );
      expect(adapter.requests.last.data, {'action': 'here'});
    },
  );
  test('join unwraps credentials and rejects incomplete response', () async {
    await expectLater(repo.join('token'), throwsFormatException);
    adapter.body = {
      'data': {
        'chime': {
          'meeting': {'MeetingId': 'meeting', 'MediaPlacement': {}},
          'attendee': {'AttendeeId': 'patient', 'JoinToken': 'secret'},
        },
      },
    };
    final chime = await repo.join('token');
    expect(chime['attendee']['AttendeeId'], 'patient');
    expect(adapter.requests.last.data, {'action': 'join'});
  });
  test('failed check-in propagates failure', () async {
    adapter.status = 500;
    await expectLater(repo.here('token'), throwsA(isA<DioException>()));
  });
  test(
    'shared auth interceptor does not attach patient bearer to public join',
    () async {
      repo.dio.interceptors.add(AuthInterceptor(() => 'patient-bearer'));
      await repo.details('token');
      expect(
        adapter.requests.single.headers.containsKey('Authorization'),
        false,
      );
    },
  );
}
