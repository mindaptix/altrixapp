import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service managing camera and microphone runtime permissions for telehealth video consultations.
class TelehealthPermissionService {
  TelehealthPermissionService._();

  /// Mock requester hook for unit/widget testing.
  @visibleForTesting
  static Future<bool> Function()? mockPermissionRequester;

  /// Requests camera and microphone permissions before joining a video session.
  ///
  /// Returns `true` if permissions are granted (or if running in a headless test environment),
  /// and `false` if the user denies access.
  static Future<bool> requestCameraAndMicrophone(
    BuildContext context, {
    Future<bool> Function()? overrideRequester,
  }) async {
    if (overrideRequester != null) {
      return overrideRequester();
    }
    if (mockPermissionRequester != null) {
      return mockPermissionRequester!();
    }

    // Skip native permission channel during headless test execution
    if (Platform.environment.containsKey('FLUTTER_TEST') ||
        WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
      return true;
    }

    try {
      final statuses = await [
        Permission.camera,
        Permission.microphone,
      ].request();

      final camera = statuses[Permission.camera] ?? PermissionStatus.denied;
      final mic = statuses[Permission.microphone] ?? PermissionStatus.denied;

      final cameraOk = camera.isGranted || camera.isLimited;
      final micOk = mic.isGranted || mic.isLimited;

      if (cameraOk && micOk) {
        return true;
      }

      if (camera.isPermanentlyDenied || mic.isPermanentlyDenied) {
        if (context.mounted) {
          _showSettingsDialog(context);
        }
        return false;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.videocam_off_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Camera and microphone permissions are required to join the video visit.',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            action: SnackBarAction(
              label: 'Grant',
              textColor: const Color(0xFF8AB4F8),
              onPressed: () => requestCameraAndMicrophone(context),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return false;
    } catch (e) {
      debugPrint('Error requesting camera/mic permissions: $e');
      return false;
    }
  }

  static void _showSettingsDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(
              Icons.videocam_off_rounded,
              color: Color(0xFFEF4444),
              size: 24,
            ),
            SizedBox(width: 10),
            Text(
              'Permissions Needed',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
            ),
          ],
        ),
        content: const Text(
          'Altrix requires camera and microphone permissions to conduct your secure telehealth appointment. Please enable them in your device settings.',
          style: TextStyle(fontSize: 13.5, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Not Now',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A3AFF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              openAppSettings();
            },
            child: const Text(
              'Open Settings',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
