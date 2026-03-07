/// App-wide constants and configuration.
class AppConfig {
  AppConfig._();

  /// Render-hosted signaling server
  static const String serverUrl = 'https://callguard-server-pw4i.onrender.com';

  /// Ring timeout in seconds before showing "No Answer"
  static const int ringTimeoutSeconds = 45;

  /// Ringback beep interval in seconds
  static const int ringbackIntervalSeconds = 3;

  /// User ID length
  static const int idLength = 6;

  /// Fallback ICE configuration (STUN only, used if server fetch fails)
  static const Map<String, dynamic> fallbackIceConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ],
  };
}
