import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../config/theme.dart';
import '../models/classification_entry.dart';
import '../services/classifier.dart';
import '../services/database_service.dart';
import '../services/preprocessor.dart';
import '../services/whisper_service.dart';

enum FraudAnalysisState { idle, recording, processing }

/// Standalone fraud detection screen — Record or upload audio for AI analysis.
class FraudAnalysisScreen extends StatefulWidget {
  const FraudAnalysisScreen({super.key});

  @override
  State<FraudAnalysisScreen> createState() => _FraudAnalysisScreenState();
}

class _FraudAnalysisScreenState extends State<FraudAnalysisScreen> {
  FraudAnalysisState _state = FraudAnalysisState.idle;
  final TextPreprocessor _preprocessor = TextPreprocessor();
  final FraudClassifier _classifier = FraudClassifier();
  final WhisperService _whisper = WhisperService();
  final SpeechToText _speechToText = SpeechToText();
  final DatabaseService _db = DatabaseService();

  String _liveTranscript = '';
  String? _resultLabel;
  double? _confidenceScore;
  String? _uploadedFileName;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      await Future.wait([
        _preprocessor.loadVocab(),
        _classifier.loadModel(),
        _whisper.initialize(),
      ]);
      debugPrint('✅ All fraud detection services initialized');
    } catch (error) {
      debugPrint('Initialization error: $error');
    }
  }

  // ── Live Recording ──

  Future<void> _startRecording() async {
    setState(() {
      _state = FraudAnalysisState.recording;
      _liveTranscript = '';
      _resultLabel = null;
      _confidenceScore = null;
      _uploadedFileName = null;
    });

    final available = await _speechToText.initialize();
    if (!available) {
      if (mounted) {
        _showSnack('Speech recognition unavailable');
        setState(() => _state = FraudAnalysisState.idle);
      }
      return;
    }

    await _speechToText.listen(
      onResult: _onSpeechResult,
      localeId: 'en_IN',
      partialResults: true,
      pauseFor: const Duration(seconds: 5),
      listenFor: const Duration(minutes: 5),
    );
  }

  Future<void> _stopRecording() async {
    await _speechToText.stop();

    if (_liveTranscript.trim().isEmpty) {
      if (mounted) {
        _showSnack('No speech detected');
        setState(() => _state = FraudAnalysisState.idle);
      }
      return;
    }

    if (mounted) setState(() => _state = FraudAnalysisState.processing);
    _analyzeTranscript(_liveTranscript, inputType: 'recording');
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    setState(() => _liveTranscript = result.recognizedWords);
  }

  // ── File Upload ──

  Future<void> _uploadRecording() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.audio);
      if (result == null || result.files.single.path == null) return;

      setState(() {
        _state = FraudAnalysisState.processing;
        _uploadedFileName = result.files.single.name;
        _liveTranscript = 'Transcribing audio...';
        _resultLabel = null;
        _confidenceScore = null;
      });

      final extractedText =
          await _whisper.transcribe(result.files.single.path!);

      if (!mounted) return;
      setState(() => _liveTranscript = extractedText);
      _analyzeTranscript(extractedText,
          inputType: 'file_upload', fileName: _uploadedFileName);
    } catch (error) {
      debugPrint('Upload error: $error');
      if (mounted) setState(() => _state = FraudAnalysisState.idle);
    }
  }

  // ── Analysis ──

  void _analyzeTranscript(String transcript,
      {required String inputType, String? fileName}) {
    if (transcript.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _state = FraudAnalysisState.idle;
          _resultLabel = 'No speech detected';
        });
      }
      return;
    }

    if (!_classifier.isLoaded) {
      if (mounted) {
        setState(() {
          _state = FraudAnalysisState.idle;
          _resultLabel = 'Model not loaded';
        });
      }
      return;
    }

    try {
      final result = _preprocessor.preprocess(transcript);
      final score = _classifier.classify(result.tokenIds);

      if (!mounted) return;

      final verdict = score >= 0.5 ? 'FRAUD' : 'LEGITIMATE';

      setState(() {
        _confidenceScore = score;
        _resultLabel =
            score >= 0.5 ? '🔴 FRAUD DETECTED' : '🟢 LEGITIMATE CALL';
        _state = FraudAnalysisState.idle;
      });

      // Save to classification history
      _db.insertClassification(ClassificationEntry(
        timestamp: DateTime.now(),
        inputType: inputType,
        fileName: fileName,
        transcript: transcript,
        matchedKeywords: result.matchedWords,
        unmatchedWords: result.unmatchedWords,
        confidenceScore: score,
        verdict: verdict,
      ));
    } catch (error) {
      debugPrint('Analysis error: $error');
      if (mounted) {
        setState(() {
          _state = FraudAnalysisState.idle;
          _resultLabel = 'Analysis failed';
        });
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: AppColors.surface,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  void dispose() {
    _classifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppGradients.backgroundSubtle),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Header
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [AppColors.accent, AppColors.accentDark],
                ).createShader(bounds),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shield_rounded, color: Colors.white, size: 26),
                    SizedBox(width: 10),
                    Text('ScamShield AI', style: AppTextStyles.heading),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text('AI-Powered Fraud Detection', style: AppTextStyles.caption),

              const SizedBox(height: 28),
              _buildResultCard(),

              const SizedBox(height: 24),
              // Transcript section
              _buildTranscriptSection(),

              const SizedBox(height: 28),
              _buildControls(),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    final bool isFraud = _resultLabel?.contains('FRAUD') ?? false;
    final bool hasResult =
        _resultLabel != null && _confidenceScore != null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: hasResult
              ? (isFraud
                  ? [Colors.red.shade800, Colors.red.shade600]
                  : [Colors.green.shade800, Colors.green.shade600])
              : [AppColors.surface, AppColors.surfaceLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: hasResult
              ? (isFraud
                  ? Colors.red.withOpacity(0.4)
                  : Colors.green.withOpacity(0.4))
              : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: hasResult
                ? (isFraud
                    ? Colors.red.withOpacity(0.15)
                    : Colors.green.withOpacity(0.15))
                : Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            hasResult
                ? (isFraud
                    ? Icons.warning_rounded
                    : Icons.verified_user_rounded)
                : Icons.security_rounded,
            size: 56,
            color: hasResult ? Colors.white : AppColors.accent.withOpacity(0.6),
          ),
          const SizedBox(height: 16),
          Text(
            _resultLabel ?? 'Awaiting Analysis',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: hasResult ? Colors.white : AppColors.textPrimary,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
          if (_confidenceScore != null) ...[
            const SizedBox(height: 12),
            Text(
              'Confidence: ${(_confidenceScore! * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 15,
                color:
                    hasResult ? Colors.white70 : AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (_uploadedFileName != null && !hasResult) ...[
            const SizedBox(height: 10),
            Text(
              'File: $_uploadedFileName',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.accent.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTranscriptSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.subtitles_rounded,
                color: AppColors.textSecondary, size: 16),
            const SizedBox(width: 8),
            Text('LIVE TRANSCRIPT', style: AppTextStyles.label),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          height: 140,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: SingleChildScrollView(
            child: Text(
              _liveTranscript.isEmpty
                  ? 'Transcript will appear here...'
                  : _liveTranscript,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: _liveTranscript.isEmpty
                    ? AppColors.textMuted
                    : AppColors.textPrimary,
                fontStyle: _liveTranscript.isEmpty
                    ? FontStyle.italic
                    : FontStyle.normal,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControls() {
    if (_state == FraudAnalysisState.processing) {
      return Column(
        children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              color: AppColors.accent,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Running AI Analysis...',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      );
    }

    if (_state == FraudAnalysisState.recording) {
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: _stopRecording,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          icon: const Icon(Icons.stop_rounded, color: Colors.white),
          label: const Text(
            'STOP RECORDING',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ),
      );
    }

    // Idle state — show Record + Upload buttons
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _startRecording,
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: Ink(
              decoration: BoxDecoration(
                gradient: AppGradients.accent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.mic_rounded, size: 22, color: Colors.white),
                    SizedBox(width: 10),
                    Text(
                      'RECORD CALL',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton.icon(
            onPressed: _uploadRecording,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.accent.withOpacity(0.4)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            icon: Icon(Icons.upload_file_rounded,
                color: AppColors.accent, size: 22),
            label: Text(
              'UPLOAD AUDIO FILE',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
                color: AppColors.accent,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
