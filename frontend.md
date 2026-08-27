# CallGuard Frontend Architecture (Detailed Analysis)

This document provides an exhaustive, code-aware architectural breakdown of the CallGuard mobile application, detailing the exact data flow, execution paths, widget lifecycles, and the local AI integration.

## 1. Project Architecture & Dependency Layer

**Location:** `d:\VoIP calls\callguard`
The Flutter frontend follows a structured, service-oriented architecture.

**Key Dependencies (`pubspec.yaml`):**
- **Connectivity:** `flutter_webrtc` (P2P audio), `socket_io_client` (Node.js signaling), `http` (REST calls).
- **Native OS Hooks:** `flutter_callkit_incoming` (Native iOS/Android calling UI), `flutter_foreground_task` (Background wake locks), `permission_handler`.
- **AI / ML Pipeline:** `tflite_flutter` (Local neural network execution), `whisper_flutter_new` (C++ whisper.cpp binding for STT), `speech_to_text` (Live transcription).
- **Persistence:** `sqflite` (Local SQLite database), `shared_preferences` (ID storage).
- **Audio:** `flutter_ringtone_player` (Incoming ringtones and ringback generation).

---

## 2. App Entry & Background Integration (`main.dart`)
**File Path:** `lib/main.dart`

### A. Initialization
**Purpose:** Ensure native bindings are attached before running Dart code, initialize Firebase for push notifications, and configure background ports.
```dart
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Initialize communication port for foreground task
  FlutterForegroundTask.initCommunicationPort();
```

### B. Global CallKit Listener
**Purpose:** The app might be dead or minimized when a call comes in. The Node.js server sends a data-only FCM push, which triggers `flutter_callkit_incoming`. When the user taps "Accept" on their lock screen, this listener fires.
```dart
  FlutterCallkitIncoming.onEvent.listen((CallEvent? event) {
    if (event == null) return;
    switch (event.event) {
      case Event.actionCallAccept:
        // Logic to extract callerId and SDP Offer from event.body['extra']
        // Navigates directly using navigatorKey
        break;
      case Event.actionCallDecline:
        // Extracts callerId, calls _signaling.rejectCall({'to': callerId})
        break;
    }
  });
```
**Why it was written this way:** `navigatorKey` is used so that UI transitions (pushing `CallScreen`) can occur from a global headless callback without requiring a Flutter `BuildContext`.

---

## 3. UI Layer & Screens

### A. HomeScreen Tab Layout
**File Path:** `lib/screens/home_screen.dart`
**Purpose:** The central hub, implementing an `IndexedStack` to preserve state between tabs (Calls, Shield, History, Scans).
**Execution Flow:** 
1. `initState()` calls `UserService.getUserId()`.
2. Requests background battery-optimization overrides via `ForegroundService.requestPermissions()`.
3. Calls `_connectSignaling()` to bind the Socket.IO callbacks.
4. If a call arrives while the app is active, `_onIncomingCall` fires `FlutterCallkitIncoming.showCallkitIncoming(params)`.

### B. Active Call Screen (`CallScreen`)
**File Path:** `lib/screens/call_screen.dart`
**Purpose:** Handles the active WebRTC lifecycle, displaying the avatar, connection status, and duration timer.
**Code Snippet (Call Setup):**
```dart
  Future<void> _setupCall() async {
    final iceConfig = await WebRTCService.fetchIceConfig();
    await _webrtc.initialize(iceConfig);

    if (widget.isIncoming) {
      _setStatus(CallStatus.answering);
      await _webrtc.setRemoteDescription(
        RTCSessionDescription(widget.sdpOffer['sdp'], widget.sdpOffer['type']),
      );
      final answer = await _webrtc.createAnswer();
      widget.signaling.answerCall({
        'to': widget.remoteId,
        'answer': {'sdp': answer.sdp, 'type': answer.type},
      });
    } else {
      _setStatus(CallStatus.ringing);
      _ringtone.playRingback();
      final offer = await _webrtc.createOffer();
      widget.signaling.callUser({
        'from': widget.userId,
        'target': widget.remoteId,
        'offer': {'sdp': offer.sdp, 'type': offer.type},
      });
    }
```
**Error Handling:** It binds to `_webrtc.onIceConnectionState`. If it hits `RTCIceConnectionStateFailed`, it calls `_fail(CallStatus.connectionFailed)` which logs the failed call to the SQLite database, plays a heavy haptic vibration, and pops the navigator.

---

## 4. Identity & Permissions

### A. User Service
**File Path:** `lib/services/user_service.dart`
**Purpose:** Manages the 6-digit random user identity.
```dart
  static Future<String> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString(_key);
    if (id == null) {
      id = _generateId(); // Random 6 digit generator
      await prefs.setString(_key, id);
    }
    return id;
  }
```

---

## 5. Network Connectivity

### A. Signaling Service
**File Path:** `lib/services/signaling_service.dart`
**Purpose:** Wraps `socket_io_client`.
**Data Flow:** Maps raw socket events (`incoming-call`, `call-answered`, `ice-candidate`) to strongly typed Dart callbacks (`Function(dynamic)? onIncomingCall`, etc.) so that the UI can consume them cleanly.

### B. WebRTC Service
**File Path:** `lib/services/webrtc_service.dart`
**Purpose:** Manages the actual peer-to-peer audio transmission.
**Execution Flow:**
1. `navigator.mediaDevices.getUserMedia({'audio': true, 'video': false})` requests microphone access.
2. `createPeerConnection(iceConfig)` sets up the RTCPeerConnection using TURN servers fetched via `fetchIceConfig()`.
3. `peerConnection!.addTrack(track, localStream!)` injects the microphone data.
4. Generates SDP offers/answers and listens for `onIceCandidate`.

---

## 6. On-Device AI / ML Pipeline

**Security Implications:** To ensure zero audio leaves the device, CallGuard runs its fraud detection entirely offline utilizing three consecutive services.

### Phase 1: Whisper STT Engine (`WhisperService`)
**File Path:** `lib/services/whisper_service.dart`
**Purpose:** A C++ binding to `whisper.cpp` for local `.wav` transcription.
```dart
  Future<void> initialize() async {
    final modelFile = File('$modelDir/ggml-tiny.bin');
    if (!modelFile.existsSync()) {
      // Copies the ggml-tiny model from assets to app directory on first run
      final modelData = await rootBundle.load('assets/models/ggml-tiny.en.bin');
      await modelFile.writeAsBytes(bytes, flush: true);
    }
    _whisper = Whisper(model: WhisperModel.tiny, modelDir: modelDir);
  }
```

### Phase 2: Text Preprocessor (`TextPreprocessor`)
**File Path:** `lib/services/preprocessor.dart`
**Purpose:** Neural networks require uniform numeric input. This takes the transcript, converts it to lowercase, removes punctuation, and maps words to integers using `assets/models/vocab.json`.
```dart
    final tokenIds = words.map((token) {
      if (_vocab.containsKey(token)) {
        return _vocab[token]!;
      } else {
        return 0; // Unrecognized words mapped to 0
      }
    }).toList();

    // Zero-padding prepended to match Python/Keras Conv1D input shape (length 60)
    int paddingNeeded = maxSequenceLength - tokenIds.length;
    finalSequence = List<int>.filled(paddingNeeded, 0) + tokenIds;
```

### Phase 3: Classification (`FraudClassifier`)
**File Path:** `lib/services/classifier.dart`
**Purpose:** Runs the padded `int` array through a TensorFlow Lite model.
```dart
  double classify(List<int> tokenIds) {
    // Keras models expect a 2D batch array (e.g. shape [1, 60] with float32 type)
    final input = [tokenIds.map((e) => e.toDouble()).toList()];
    final output = [<double>[0.0]]; // Pre-allocate output buffer

    _interpreter!.run(input, output);

    double confidenceScore = output[0][0]; // 0.0 to 1.0 probability
    return confidenceScore;
  }
```

---

## 7. Audio & Media Handling

### Ringtone Service (`RingtoneService`)
**File Path:** `lib/services/ringtone_service.dart`
**Purpose:** Generates the "trrr... trrr..." telephony ringing sound locally while the caller waits for the callee to pick up.
```dart
  void _startRingCycle() {
    _player.play(android: AndroidSounds.ringtone, ios: IosSounds.electronic, looping: false, volume: 0.6);

    // Stop after 2 seconds, then wait 3 seconds before next ring (Standard telephony spec)
    _ringbackTimer = Timer(const Duration(seconds: 2), () {
      _player.stop();
      if (_isPlaying) {
        _ringbackTimer = Timer(const Duration(seconds: 3), () {
          if (_isPlaying) _startRingCycle();
        });
      }
    });
  }
```
**Why it was written this way:** WebRTC does not natively produce ringback tones when `createOffer` is called. Emulating this locally provides the standard psychological feedback users expect when making phone calls.

---

## 8. Persistence (Local Database)

### Database Service (`DatabaseService`)
**File Path:** `lib/services/database_service.dart`
**Purpose:** A SQLite singleton (`sqflite`) managing two tables: `call_history` and `classification_history`.
```dart
// Table Schema Example:
CREATE TABLE call_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  remoteId TEXT NOT NULL,
  savedName TEXT,
  isIncoming INTEGER NOT NULL,
  startTime TEXT NOT NULL,
  endTime TEXT,
  durationSeconds INTEGER NOT NULL,
  status TEXT NOT NULL
)
```
**Data Flow:** Invoked when `CallScreen` finishes execution (via the `_logCallHistory` method) and when `FraudAnalysisScreen` completes a classification. The respective history screens execute simple `SELECT * ORDER BY` queries to populate their UI list views.
