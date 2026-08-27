import 'dart:async';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

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

  /// Play classic telephony ringback — "trrr... trrr..." pattern.
  /// Rings for 2s, silent for 3s, repeats. This is what real phone
  /// networks do for the caller while the other side is ringing.
  void playRingback() {
    if (_isPlaying) return;
    _isPlaying = true;
    _startRingCycle();
  }

  void _startRingCycle() {
    // Play the ring tone
    _player.play(
      android: AndroidSounds.ringtone,
      ios: IosSounds.electronic,
      looping: false,
      volume: 0.6,
    );

    // Stop after 2 seconds, then wait 3 seconds before next ring
    _ringbackTimer = Timer(const Duration(seconds: 2), () {
      _player.stop();
      if (_isPlaying) {
        _ringbackTimer = Timer(const Duration(seconds: 3), () {
          if (_isPlaying) _startRingCycle();
        });
      }
    });
  }

  /// Stop all audio.
  void stop() {
    _ringbackTimer?.cancel();
    _ringbackTimer = null;
    _player.stop();
    _isPlaying = false;
  }
}
