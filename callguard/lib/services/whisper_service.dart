import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:whisper_flutter_new/whisper_flutter_new.dart';

/// Service for offline audio-to-text transcription using Whisper (whisper.cpp).
class WhisperService {
  Whisper? _whisper;

  /// Initialize whisper engine — copies model from assets on first run.
  Future<void> initialize() async {
    try {
      final appSupportDir = await getApplicationSupportDirectory();
      final modelDir = appSupportDir.path;
      final modelFile = File('$modelDir/ggml-tiny.bin');

      if (!modelFile.existsSync()) {
        debugPrint('[WHISPER] Copying model to app support dir...');
        final modelData =
            await rootBundle.load('assets/models/ggml-tiny.en.bin');
        final bytes = modelData.buffer.asUint8List();
        await modelFile.writeAsBytes(bytes, flush: true);
        debugPrint('[WHISPER] Model copied successfully');
      }

      _whisper = Whisper(
        model: WhisperModel.tiny,
        modelDir: modelDir,
      );

      await _whisper!.getVersion();
      debugPrint('✅ Whisper STT engine loaded');
    } catch (error) {
      debugPrint('❌ Whisper init error: $error');
    }
  }

  /// Transcribe an audio file to text. Returns the transcribed string.
  Future<String> transcribe(String filePath) async {
    if (_whisper == null) {
      return 'Error: Transcription engine not loaded.';
    }

    try {
      final response = await _whisper!.transcribe(
        transcribeRequest: TranscribeRequest(
          audio: filePath,
          language: 'en',
          isTranslate: false,
          isNoTimestamps: true,
          splitOnWord: true,
        ),
      );

      final text = response.text.trim();
      return text.isEmpty ? 'No speech detected in file.' : text;
    } catch (error) {
      debugPrint('❌ Transcription error: $error');
      return 'Transcription failed.';
    }
  }

  bool get isReady => _whisper != null;
}
