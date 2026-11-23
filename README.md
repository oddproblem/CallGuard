# CallGuard

**Architecture:** Flutter mobile app using WebRTC for real-time calls and Socket.IO for signaling/server updates, with on-device edge inference for fraud detection and voice analysis.

CallGuard provides real-time call monitoring and fraud detection on iOS and Android. Audio analysis and speech processing run with local machine-learning models, while call records are stored in SQLite for offline access.

## Architecture at a glance

- **Mobile client:** Flutter/Dart application.
- **Call and signaling:** `flutter_webrtc` for peer-to-peer communication and `socket_io_client` for server communication.
- **Edge inference:** TensorFlow Lite fraud classifier and local Whisper speech-to-text model; voice recognition is supported by `speech_to_text`.
- **Local persistence:** SQLite (`sqflite`) for call history and metadata.

## Key features

- Real-time machine-learning fraud detection
- Voice analysis and speech-to-text
- WebRTC call management
- Local call history and offline support
- Microphone, call-handling, storage, and network permission management

## Requirements

- Flutter SDK: ^3.11.0
- Dart SDK: ^3.11.0
- Android API level 21 or higher
- iOS 11.0 or higher

## Installation

```bash
git clone https://github.com/oddproblem/CallGuard.git
cd CallGuard/callguard
flutter pub get
flutter run
```

## Building

```bash
flutter build apk
flutter build ios
```

## Machine-learning models

Pre-trained models are located in `assets/models/`:

- `fraud_model.tflite` — classification of fraudulent call patterns
- `vocab.json` — vocabulary mapping for text processing
- `ggml-tiny.en.bin` — Whisper speech-to-text model

## Configuration and data

Application preferences are managed with `shared_preferences`. SQLite stores call records, timestamps, and metadata locally. Users can configure preferences, call-history retention, and fraud-detection sensitivity.

## Contributing

Contributions are welcome. Please keep changes compatible with the existing codebase and follow Flutter best practices.

## License

This project is currently unlicensed.

## Disclaimer

CallGuard is intended for legitimate call monitoring and fraud prevention purposes. Users must comply with applicable laws and regulations regarding call recording, call interception, and audio processing.
