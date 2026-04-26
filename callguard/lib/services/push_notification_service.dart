import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:uuid/uuid.dart';

/// Background handler — runs in a separate isolate when app is killed/background.
/// Must be a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("[BG] Handling background FCM message: ${message.messageId}");

  if (message.data['type'] == 'incoming_call') {
    final callerId = message.data['from'] ?? 'Unknown';
    final callId = const Uuid().v4();

    final params = CallKitParams(
      id: callId,
      nameCaller: 'CallGuard User',
      handle: callerId,
      appName: 'CallGuard',
      type: 0, // Audio call
      textAccept: 'Accept',
      textDecline: 'Decline',
      duration: 45000,
      extra: <String, dynamic>{
        'callerId': callerId,
        'offer': message.data['offer'] ?? '',
      },
      missedCallNotification: const NotificationParams(
        showNotification: true,
        isShowCallback: true,
        subtitle: 'Missed call',
        callbackText: 'Call back',
      ),
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#0A0A2E',
        actionColor: '#6C63FF',
        textColor: '#ffffff',
        incomingCallNotificationChannelName: 'Incoming Call',
        missedCallNotificationChannelName: 'Missed Call',
        isShowCallID: true,
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(params);
    debugPrint("[BG] Showed callkit incoming for caller: $callerId");
  }
}

class PushNotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('User granted push permission: ${settings.authorizationStatus}');

    // Request notification permission for Android 13+
    await FlutterCallkitIncoming.requestNotificationPermission({
      "rationaleMessagePermission":
          "Notification permission is required to receive incoming calls.",
      "postNotificationMessageRequired":
          "Please allow notification permission from settings to receive calls.",
    });

    // Foreground FCM messages — show callkit incoming when a call arrives
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a FCM message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      if (message.data['type'] == 'incoming_call') {
        _showCallkitIncoming(message.data);
      }
    });
  }

  /// Show callkit incoming from FCM data payload.
  Future<void> _showCallkitIncoming(Map<String, dynamic> data) async {
    final callerId = data['from'] ?? 'Unknown';
    final callId = const Uuid().v4();

    final params = CallKitParams(
      id: callId,
      nameCaller: 'CallGuard User',
      handle: callerId,
      appName: 'CallGuard',
      type: 0,
      textAccept: 'Accept',
      textDecline: 'Decline',
      duration: 45000,
      extra: <String, dynamic>{
        'callerId': callerId,
        'offer': data['offer'] ?? '',
      },
      missedCallNotification: const NotificationParams(
        showNotification: true,
        isShowCallback: true,
        subtitle: 'Missed call',
        callbackText: 'Call back',
      ),
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#0A0A2E',
        actionColor: '#6C63FF',
        textColor: '#ffffff',
        incomingCallNotificationChannelName: 'Incoming Call',
        missedCallNotificationChannelName: 'Missed Call',
        isShowCallID: true,
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  Future<String?> getToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      debugPrint("FCM Token: $token");
      return token;
    } catch (e) {
      debugPrint("Failed to get FCM token: $e");
      return null;
    }
  }

  void onTokenRefresh(Function(String) callback) {
    _firebaseMessaging.onTokenRefresh.listen(callback);
  }
}
