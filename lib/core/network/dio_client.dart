import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/unauthorized_interceptor.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
      sendTimeout: const Duration(seconds: 60),
      contentType: 'application/json',
      responseType: ResponseType.json,
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      final client = HttpClient();
      client.badCertificateCallback = (cert, host, port) => true;
      client.connectionTimeout = const Duration(seconds: 60);
      return client;
    },
  );

  dio.interceptors.addAll([
    createAuthInterceptor(ref),
    createUnauthorizedInterceptor(ref),
    if (kDebugMode)
      LogInterceptor(
        request: true,
        // Authorization headers contain patient credentials and must never be
        // printed, including in debug builds.
        requestHeader: false,
        requestBody: true,
        responseHeader: false,
        responseBody: true,
        error: true,
      ),
  ]);

  return dio;
});
