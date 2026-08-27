# ScamShield AI - Detailed Feature Breakdown

This document outlines the core features of the ScamShield AI Flutter application and details exactly how each feature is implemented within the codebase.

## 1. Live Microphone Recording & Real-time Transcription
**What it does:** Allows the user to record a live phone call or conversation directly from their device's microphone and see the speech transcribed to text in real-time.

**How it is implemented:**
- **Library used:** `speech_to_text` package.
- **Initialization:** Inside `home_screen.dart`, the `SpeechToText` instance is initialized. If speech recognition is unavailable or permissions are denied, it alerts the user.
- **Capture Process:** The `_startRecording()` function begins listening to the microphone. It is configured to listen for up to 5 minutes (`listenFor`) and will auto-pause if there's 5 seconds of silence (`pauseFor`). It is explicitly set to use the `en_IN` (English - India) locale.
- **Real-time Updates:** As the user speaks, `_onSpeechResult(SpeechRecognitionResult result)` is continuously called with `partialResults: true`. This updates the `_liveTranscript` state variable, which instantly updates the UI to show the transcript as it's being spoken.

## 2. Offline Audio File Upload & Transcription
**What it does:** Allows users to upload pre-recorded audio files. The app then transcribes the audio entirely locally (offline) using an embedded AI speech model.

**How it is implemented:**
- **File Selection:** Uses the `file_picker` package in `_uploadRecording()` to allow the user to select an audio file (`FileType.audio`) from their device's storage.
- **Transcription Engine:** Utilizes the `whisper_flutter_new` package, which is a Flutter binding for the local Whisper AI model.
- **Model Loading:** During app startup (`_initWhisper()`), the app checks if the Whisper tiny English model (`ggml-tiny.en.bin`) exists in the application's support directory. If not, it copies it from the app's bundled `assets/models/` folder.
- **Execution:** The selected audio file path is passed to `_transcribeAudioFile()`, which invokes the local Whisper model to transcribe the speech into text without requiring an internet connection.

## 3. Text Preprocessing & Tokenization
**What it does:** Cleans the transcribed text and converts it into a format (an array of numbers) that the Machine Learning model can understand.

**How it is implemented:**
- **Location:** Managed by the `TextPreprocessor` class in `lib/services/preprocessor.dart`.
- **Vocabulary Loading:** Loads a `vocab.json` dictionary from the assets folder. This maps specific words to unique integer IDs. It includes fallback logic to handle both Map (`{"word": 1}`) and List (`["word1"]`) formats.
- **Normalization:** Converts all text to lowercase and strips out all non-alphanumeric characters (punctuation) using Regex (`RegExp(r'[^a-z0-9\s]')`).
- **Tokenization:** Splits the cleaned text by spaces into a list of individual words. It then loops through these words and replaces them with their corresponding integer ID from the loaded vocabulary. Unknown words are assigned an ID of `0`.
- **Sequence Formatting (Pre-padding):** The ML model expects an exact input size of 60 words (`maxSequenceLength = 60`). If the transcript has fewer than 60 words, the preprocessor adds `0`s to the *beginning* of the array. If it has more than 60 words, it truncates the *beginning* of the array. This matches the standard Python/Keras pre-padding behavior.

## 4. On-Device Fraud Classification
**What it does:** Analyzes the processed transcript using a local Machine Learning model to determine if the conversation is a scam or a legitimate call.

**How it is implemented:**
- **Library used:** `tflite_flutter` package.
- **Location:** Managed by the `FraudClassifier` class in `lib/services/classifier.dart`.
- **Model Loading:** Loads a pre-trained TensorFlow Lite model (`fraud_model.tflite`) from the app's assets folder into memory using `Interpreter.fromAsset()`.
- **Execution:** The integer array from the preprocessor is converted to `double` values and wrapped in a 2D array of shape `[1, 60]`. This is passed to the `_interpreter!.run(input, output)` function.
- **Scoring:** The model outputs a single confidence score (probability). The classifier reads this raw score. A score `>= 0.5` is classified as `'🔴 FRAUD DETECTED'`, while `< 0.5` is `'🟢 LEGITIMATE CALL'`.

## 5. Dynamic Status UI & Result Presentation
**What it does:** Provides visual feedback to the user regarding the state of the app (recording, processing, result) and presents the final AI prediction clearly.

**How it is implemented:**
- **Location:** UI logic is housed in `_HomeScreenState` (`home_screen.dart`).
- **State Management:** Uses an `AppState` enum (`idle`, `recording`, `processing`) to determine which controls to show (e.g., hiding the "Record" button and showing a progress spinner when processing an audio file).
- **Result Card:** Implemented in `_buildResultCard()`. It utilizes an `AnimatedContainer` that dynamically changes its gradient background color based on the `_resultLabel`:
    - **Fraudulent:** Morphs into a red gradient with a warning icon.
    - **Legitimate:** Morphs into a green gradient with a verified shield icon.
- **Confidence Display:** Extracts the raw decimal score from the classifier, multiplies it by 100, and formats it to one decimal place to display a user-friendly confidence percentage (e.g., "Confidence: 94.2%").
