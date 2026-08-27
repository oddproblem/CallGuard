# CallGuard

CallGuard is a mobile application that provides real-time fraud detection and call monitoring capabilities. Built with Flutter, the application combines voice analysis, machine learning, and WebRTC technology to identify and prevent fraudulent calls.

## Overview

This project implements a comprehensive call security solution for mobile platforms (iOS and Android). It uses advanced machine learning models for fraud detection, real-time audio processing, and secure communication protocols.

## Key Features

- **Real-time Fraud Detection**: Machine learning-based classification system to identify fraudulent calls
- **Voice Analysis**: Speech-to-text and audio processing capabilities
- **Call Management**: WebRTC integration for peer-to-peer communication
- **Call History**: Local database storage for call records and metadata
- **Permission Management**: Granular control over microphone and system permissions
- **Offline Support**: Local data persistence with SQLite

## Technology Stack

### Frontend
- **Dart**: Primary language (55.4% of codebase)
- **Flutter**: Cross-platform mobile framework
- **Material Design**: UI component system

### Backend & Processing
- **C++**: Performance-critical implementations (19.8% of codebase)
- **CMake**: Build configuration system (15.3% of codebase)

### Core Dependencies
- **WebRTC**: `flutter_webrtc` - Real-time communication
- **Socket.IO**: `socket_io_client` - Server communication
- **Machine Learning**: 
  - `tflite_flutter` - TensorFlow Lite model inference
  - `whisper_flutter_new` - Audio transcription
  - `speech_to_text` - Voice recognition
- **Audio**: `flutter_ringtone_player` - Call notifications
- **Storage**: `sqflite` - Local database
- **Permissions**: `permission_handler` - System access control

## Project Structure

```
callguard/
├── lib/                    # Dart application code
├── ios/                    # iOS-specific configuration
├── android/                # Android-specific configuration
├── assets/
│   └── models/            # Pre-trained ML models
│       ├── fraud_model.tflite
│       ├── vocab.json
│       └── ggml-tiny.en.bin
├── pubspec.yaml           # Dart package configuration
└── CMakeLists.txt         # C++ build configuration
```

## Requirements

- Flutter SDK: ^3.11.0
- Dart SDK: ^3.11.0
- Android API level: 21 or higher
- iOS: 11.0 or higher

## Installation

1. Clone the repository:
```bash
git clone https://github.com/oddproblem/CallGuard.git
cd CallGuard/callguard
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the application:
```bash
flutter run
```

## Building

### Android
```bash
flutter build apk
```

### iOS
```bash
flutter build ios
```

## Machine Learning Models

The application uses three pre-trained models located in `assets/models/`:

- **fraud_model.tflite**: Classification model for detecting fraudulent call patterns
- **vocab.json**: Vocabulary mapping for text processing
- **ggml-tiny.en.bin**: Whisper model for speech-to-text conversion

## Permissions

The application requires the following permissions:

- Microphone access: For audio capture and voice analysis
- Call handling: For call interception and monitoring
- Storage: For saving call records and model data
- Network: For server communication and real-time updates

## Configuration

Application preferences are managed through the `shared_preferences` package. Configuration includes:
- User preferences
- Call history retention settings
- Fraud detection sensitivity levels

## Database

The application uses SQLite for local data persistence. Call records, timestamps, and metadata are stored locally for offline access and historical analysis.

## Contributing

Contributions are welcome. Please ensure all changes maintain compatibility with the existing codebase and follow Flutter best practices.

## License

This project is currently unlicensed.

## Disclaimer

CallGuard is intended for legitimate call monitoring and fraud prevention purposes. Users must comply with applicable laws and regulations regarding call recording, call interception, and audio processing in their jurisdiction.
