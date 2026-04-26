import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Lightweight foreground service that keeps the app process alive
/// so FCM data messages are always delivered — even on aggressive OEMs
/// like OPPO, Xiaomi, Vivo, Samsung.
///
/// Battery impact is negligible: no repeat work, just a persistent notification.

// ── Top-level callback (required by the plugin) ──
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(_KeepAliveHandler());
}

class _KeepAliveHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('[FG-SERVICE] Keep-alive started');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // No-op: we only need the process alive, no repeated work needed.
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    debugPrint('[FG-SERVICE] Keep-alive destroyed (timeout=$isTimeout)');
  }

  @override
  void onReceiveData(Object data) {}

  @override
  void onNotificationButtonPressed(String id) {}

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }

  @override
  void onNotificationDismissed() {}
}

/// Helper to request permissions, init, and start the foreground service.
class ForegroundService {
  /// Request battery optimization exemption (critical for OPPO/Xiaomi/etc.)
  static Future<void> requestPermissions() async {
    // Notification permission (Android 13+)
    final notifPerm = await FlutterForegroundTask.checkNotificationPermission();
    if (notifPerm != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    if (Platform.isAndroid) {
      // Battery optimization exemption — THE key fix for OEMs that kill apps
      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
    }
  }

  /// Initialize the foreground task configuration.
  static void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'callguard_bg_service',
        channelName: 'CallGuard Background Service',
        channelDescription: 'Keeps CallGuard ready to receive incoming calls.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        // Very long interval — we don't need repeated work, just keep-alive
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  /// Start the foreground service (or restart if already running).
  static Future<void> start() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.restartService();
    } else {
      await FlutterForegroundTask.startService(
        serviceId: 888,
        notificationTitle: 'CallGuard',
        notificationText: 'Ready to receive calls',
        notificationInitialRoute: '/',
        callback: startCallback,
      );
    }
  }
}
