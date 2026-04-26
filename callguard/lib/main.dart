import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'app.dart';
import 'services/foreground_service.dart';

/// Global navigator key for navigating from outside widget tree (e.g. callkit events)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Initialize communication port for foreground task
  FlutterForegroundTask.initCommunicationPort();

  // Listen for callkit events globally (accept, decline, timeout, etc.)
  FlutterCallkitIncoming.onEvent.listen((CallEvent? event) {
    if (event == null) return;
    switch (event.event) {
      case Event.actionCallAccept:
        debugPrint('[CALLKIT] Call accepted: ${event.body}');
        break;
      case Event.actionCallDecline:
        debugPrint('[CALLKIT] Call declined: ${event.body}');
        break;
      case Event.actionCallTimeout:
        debugPrint('[CALLKIT] Call timeout: ${event.body}');
        break;
      case Event.actionCallEnded:
        debugPrint('[CALLKIT] Call ended: ${event.body}');
        break;
      default:
        debugPrint('[CALLKIT] Event: ${event.event}');
        break;
    }
  });

  runApp(const CallGuardApp());
}
