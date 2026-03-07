import 'dart:async';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import '../config/constants.dart';

/// Manages all call-related audio feedback.
class RingtoneService {
  static final RingtoneService _instance = RingtoneService._();
  factory RingtoneService() => _instance;
  RingtoneService._();

  final _player = FlutterRingtonePlayer();
  Timer? _ringbackTimer;
  bool _isPlaying = false;

  /// Play the device's ringtone (incoming calls).
  void playRingtone() {
    if (_isPlaying) return;
    _isPlaying = true;
    _player.play(
      android: AndroidSounds.ringtone,
      ios: IosSounds.electronic,
      looping: true,
      volume: 1.0,
    );
  }

  /// Play short notification beeps at intervals (outgoing "ringback").
  void playRingback() {
    if (_isPlaying) return;
    _isPlaying = true;
    _playBeep();
    _ringbackTimer = Timer.periodic(
      Duration(seconds: AppConfig.ringbackIntervalSeconds),
      (_) => _playBeep(),
    );
  }

  void _playBeep() {
    _player.play(
      android: AndroidSounds.notification,
      ios: IosSounds.glass,
      looping: false,
      volume: 0.3,
    );
  }

  /// Stop all audio.
  void stop() {
    _ringbackTimer?.cancel();
    _ringbackTimer = null;
    _player.stop();
    _isPlaying = false;
  }
}
