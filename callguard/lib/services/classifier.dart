import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Loads and runs the TFLite fraud classification model on preprocessed tokens.
class FraudClassifier {
  Interpreter? _interpreter;

  Future<void> loadModel() async {
    try {
      _interpreter =
          await Interpreter.fromAsset('assets/models/fraud_model.tflite');
      debugPrint('✅ Fraud model loaded successfully');
    } catch (e) {
      debugPrint('❌ Model load FAILED: $e');
      rethrow;
    }
  }

  /// Classify preprocessed token IDs. Returns a confidence score (0.0–1.0).
  /// Score >= 0.5 → FRAUD, < 0.5 → LEGITIMATE.
  double classify(List<int> tokenIds) {
    assert(_interpreter != null, 'Model must be loaded before classification');

    // Convert int tokens to doubles and wrap in 2D array [1, 60]
    final input = [tokenIds.map((e) => e.toDouble()).toList()];
    final output = [<double>[0.0]];

    _interpreter!.run(input, output);

    double confidenceScore = output[0][0];

    String label =
        confidenceScore >= 0.5 ? '🔴 FRAUD DETECTED' : '🟢 LEGITIMATE CALL';
    debugPrint('🧠 MODEL PREDICTION: $label | Score: $confidenceScore');

    return confidenceScore;
  }

  void dispose() {
    _interpreter?.close();
  }

  bool get isLoaded => _interpreter != null;
}
