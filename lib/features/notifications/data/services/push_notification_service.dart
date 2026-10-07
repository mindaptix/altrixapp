import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/config/env.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/notifications/notification_router.dart';
import '../../domain/push_notifications.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM background message: ${message.notification?.title}');
}

class PushNotificationService implements PushNotifications {
  PushNotificationService({FirebaseMessaging? messaging})
      // ignore: prefer_initializing_formals
      : _messaging = messaging;

  FirebaseMessaging? _messaging;

  // Lazily created Dio client for token registration.
  // Uses the same base URL as the rest of the app.
  Dio? _dio;
  Dio get _dioInstance {
    _dio ??= Dio(
      BaseOptions(
        baseUrl: Env.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        contentType: 'application/json',
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
    return _dio!;
  }

  // Bearer token to authenticate device-token registration requests.
  // Set this after the user logs in.
  String? _authToken;
  set authToken(String? token) => _authToken = token;

  @override
  void setAuthToken(String token) {
    _authToken = token;
  }

  @override
  Future<void> syncTokenForCurrentUser() async {
    try {
      final token = await _messagingInstance.getToken();
      if (token != null && token.isNotEmpty) {
        await saveDeviceToken(token);
      }
    } catch (e) {
      debugPrint('[FCM] syncTokenForCurrentUser error: $e');
    }
  }

  final _foregroundController = StreamController<RemoteMessage>.broadcast();

  FirebaseMessaging get _messagingInstance =>
      _messaging ??= FirebaseMessaging.instance;

  @override
  Stream<RemoteMessage> get onForegroundMessage =>
      _foregroundController.stream;

  @override
  Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _requestPermission();
    await _configureForegroundPresentation();

    // Fetch token asynchronously so APNs token can register without blocking startup
    unawaited(_fetchTokenWithRetry());

    _messagingInstance.onTokenRefresh.listen((token) {
      debugPrint('====================================================');
      debugPrint('🔥 [FCM] Token refreshed: $token');
      debugPrint('====================================================');
      saveDeviceToken(token);
    });
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);

    // Check if app was launched via a notification.
    // Use unawaited + timeout so this NEVER blocks main() before runApp().
    unawaited(
      _messagingInstance
          .getInitialMessage()
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => null,
          )
          .then((msg) {
        if (msg != null) _handleOpenedMessage(msg);
      }).catchError((_) {}),
    );
  }

  Future<String?> _fetchTokenWithRetry() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // On iOS, wait for Apple's APNs token before requesting FCM token
      String? apnsToken;
      for (int i = 0; i < 12; i++) {
        try {
          apnsToken = await _messagingInstance.getAPNSToken();
          if (apnsToken != null && apnsToken.isNotEmpty) {
            debugPrint('[FCM] APNs token acquired: $apnsToken');
            break;
          }
        } catch (e) {
          debugPrint('[FCM] getAPNSToken attempt ${i + 1} failed: $e');
        }
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    try {
      final token = await _messagingInstance.getToken();
      if (token != null && token.isNotEmpty) {
        await saveDeviceToken(token);
        debugPrint('====================================================');
        debugPrint('🔥 [FCM] Device token: $token');
        debugPrint('====================================================');
        return token;
      }
    } catch (e) {
      debugPrint('[FCM] getToken error: $e');
    }
    return null;
  }

  @override
  Future<void> saveDeviceToken(String token) async {
    if (token.isEmpty) return;
    final auth = _authToken;
    if (auth == null || auth.isEmpty) {
      // No auth token yet — token will be registered on next login
      debugPrint('[FCM] saveDeviceToken: no auth token yet, will retry on login');
      return;
    }
    try {
      await _dioInstance.post(
        ApiEndpoints.patientDeviceToken,
        data: {
          'token': token,
          'platform': Platform.isIOS ? 'ios' : 'android',
        },
        options: Options(
          headers: {'Authorization': 'Bearer $auth'},
        ),
      );
      debugPrint('[FCM] ✅ Device token registered with backend');
    } catch (e) {
      debugPrint('[FCM] saveDeviceToken error (non-critical): $e');
    }
  }

  @override
  Future<void> clearDeviceTokens() async {
    final token = await _messagingInstance.getToken();
    if (token == null || token.isEmpty) return;
    final auth = _authToken;
    if (auth == null || auth.isEmpty) return;
    try {
      await _dioInstance.delete(
        ApiEndpoints.patientDeviceToken,
        data: {'token': token},
        options: Options(
          headers: {'Authorization': 'Bearer $auth'},
        ),
      );
    } catch (e) {
      debugPrint('[FCM] clearDeviceTokens error (non-critical): $e');
    }
  }

  Future<void> _requestPermission() async {
    await _messagingInstance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
  }

  Future<void> _configureForegroundPresentation() async {
    await _messagingInstance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  /// Emits the message to the in-app banner stream.
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[FCM] Foreground: ${message.notification?.title}');
    _foregroundController.add(message);
  }

  void _handleOpenedMessage(RemoteMessage message) {
    debugPrint('[FCM] Opened from notification');
    NotificationRouter.handleTap(message.data);
  }
}
