import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../features/auth/presentation/screens/sign_in_screen.dart';
import '../../navigation/app_navigator.dart';
import '../api_endpoints.dart';

class UnauthorizedInterceptor extends Interceptor {
  UnauthorizedInterceptor(this._ref);

  final Ref _ref;

  bool _isPublicPath(String path) {
    return path.contains(ApiEndpoints.patientLogin) ||
        path.contains(ApiEndpoints.patientLogout) ||
        path.contains(ApiEndpoints.patientInviteAccept) ||
        path.contains(ApiEndpoints.patientInvitePreview) ||
        path.contains(ApiEndpoints.patientForgotPassword) ||
        path.contains(ApiEndpoints.patientResetPassword) ||
        path.contains('/api/telehealth/');
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401 &&
        err.requestOptions.extra['skipUnauthorizedLogout'] != true &&
        !_isPublicPath(err.requestOptions.path)) {
      unawaited(
        _ref.read(authProvider.notifier).signOut().then((_) {
          rootNavigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const SignInScreen()),
            (_) => false,
          );
        }),
      );
    }
    handler.next(err);
  }
}

Interceptor createUnauthorizedInterceptor(Ref ref) {
  return UnauthorizedInterceptor(ref);
}
