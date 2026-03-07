import 'package:permission_handler/permission_handler.dart';

/// Centralized runtime permission handling.
class PermissionService {
  /// Requests microphone permission. Returns true if granted.
  static Future<bool> requestMicrophone() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Requests notification permission (Android 13+). Returns true if granted.
  static Future<bool> requestNotifications() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Checks if microphone is already granted.
  static Future<bool> hasMicrophone() async {
    return await Permission.microphone.isGranted;
  }
}
