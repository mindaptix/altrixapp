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
  Future<Map<String, dynamic>> details(String token) => _request(token);
  Future<Map<String, dynamic>> here(String token) => _request(token, 'here');
  Future<Map<String, dynamic>> join(String token) async {
    final response = await _request(token, 'join');
    final chime = response['chime'];
    if (chime is! Map ||
        chime['meeting'] is! Map ||
        chime['attendee'] is! Map ||
        chime['meeting']['MeetingId'] == null ||
        chime['meeting']['MediaPlacement'] is! Map ||
        chime['attendee']['AttendeeId'] == null ||
        chime['attendee']['JoinToken'] == null) {
      throw const FormatException('The visit is not ready. Please try again.');
    }
    return Map<String, dynamic>.from(chime);
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
}
