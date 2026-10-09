import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';

/// The optional development proxy holds the provider key outside the app.
/// Production uses the authenticated patient backend.
final chatbotDioProvider = Provider<Dio>((ref) {
  const proxyUrl = String.fromEnvironment('CHATBOT_BASE_URL');
  if (proxyUrl.isEmpty) return ref.watch(dioProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: proxyUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 45),
      contentType: 'application/json',
    ),
  );
  ref.onDispose(() => dio.close(force: true));
  return dio;
});
