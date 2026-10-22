import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/env.dart';
import '../../../../core/network/api_endpoints.dart';

final telehealthRepositoryProvider = Provider((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );
  ref.onDispose(() => dio.close());
  return TelehealthRepository(dio);
});

class TelehealthRepository {
  TelehealthRepository(this.dio);

  final Dio dio;

  Future<Map<String, dynamic>> details(String token) async {
    try {
      final response = await _request(token);
      if (_containsEndedSession(response)) {
        throw const TelehealthSessionEndedException();
      }
      return response;
    } on TelehealthSessionEndedException {
      rethrow;
    } on DioException catch (error) {
      if (_isEndedResponse(error.response)) {
        throw const TelehealthSessionEndedException();
      }
      if (_isConnectionFailure(error)) {
        throw const TelehealthNetworkException();
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> here(String token) => _request(token, 'here');

  Future<Map<String, dynamic>> join(String token) async {
    try {
      final response = await _request(token, 'join');
      if (_containsEndedSession(response)) {
        throw const TelehealthSessionEndedException();
      }

      final chime = response['chime'];
      if (chime is! Map ||
          chime['meeting'] is! Map ||
          chime['attendee'] is! Map ||
          chime['meeting']['MeetingId'] == null ||
          chime['meeting']['MediaPlacement'] is! Map ||
          chime['attendee']['AttendeeId'] == null ||
          chime['attendee']['JoinToken'] == null) {
        throw const FormatException(
          'The visit is not ready. Please try again.',
        );
      }
      return Map<String, dynamic>.from(chime);
    } on TelehealthSessionEndedException {
      rethrow;
    } on DioException catch (error) {
      if (_isEndedResponse(error.response)) {
        throw const TelehealthSessionEndedException();
      }
      if (_isConnectionFailure(error)) {
        throw const TelehealthNetworkException();
      }
      if (error.response?.statusCode == 409) {
        throw const FormatException(
          'The visit is not ready. Please try again.',
        );
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _request(String token, [String? action]) async {
    if (token.trim().isEmpty) {
      throw const FormatException('Missing visit token.');
    }
    final path = ApiEndpoints.telehealthJoin(Uri.encodeComponent(token.trim()));
    final response = action == null
        ? await dio.get(path)
        : await dio.post(path, data: {'action': action});
    final body = response.data;
    if (body is! Map) throw const FormatException('Invalid visit response.');
    return Map<String, dynamic>.from(body['data'] is Map ? body['data'] : body);
  }

  bool _isEndedResponse(Response<dynamic>? response) {
    if (response?.statusCode == 410) return true;
    return _containsEndedSession(response?.data);
  }

  bool _containsEndedSession(dynamic value, [int depth = 0]) {
    if (value == null || depth > 5) return false;
    if (value is List) {
      return value.any((item) => _containsEndedSession(item, depth + 1));
    }
    if (value is! Map) return false;

    const endedCodes = <String>{
      'SESSION_ENDED',
      'SESSION_EXPIRED',
      'TELEHEALTH_SESSION_ENDED',
      'TELEHEALTH_SESSION_EXPIRED',
    };
    const endedStatuses = <String>{
      'ENDED',
      'EXPIRED',
      'COMPLETED',
      'CANCELLED',
    };

    for (final key in const ['code', 'errorCode', 'error_code', 'statusCode']) {
      final code = value[key]?.toString().trim().toUpperCase();
      if (code != null && endedCodes.contains(code)) return true;
    }
    for (final key in const ['status', 'sessionStatus', 'session_status']) {
      final status = value[key]?.toString().trim().toUpperCase();
      if (status != null && endedStatuses.contains(status)) return true;
    }
    for (final key in const ['message', 'error', 'detail']) {
      final messageValue = value[key];
      if (messageValue is String) {
        final message = messageValue.toLowerCase();
        if (message.contains('session ended') ||
            message.contains('session already ended') ||
            message.contains('session expired') ||
            message.contains('visit was cancelled') ||
            message.contains('invalid or expired link')) {
          return true;
        }
      }
    }

    return value.values.any(
      (nested) => _containsEndedSession(nested, depth + 1),
    );
  }

  bool _isConnectionFailure(DioException error) {
    return switch (error.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => true,
      _ => false,
    };
  }
}

class TelehealthSessionEndedException implements Exception {
  const TelehealthSessionEndedException();

  @override
  String toString() => 'Session ended';
}

class TelehealthNetworkException implements Exception {
  const TelehealthNetworkException();

  @override
  String toString() => 'Please check your internet connection.';
}
