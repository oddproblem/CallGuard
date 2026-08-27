import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Result of text preprocessing, including keyword metadata for history.
class PreprocessResult {
  final List<int> tokenIds;
  final List<String> matchedWords;
  final List<String> unmatchedWords;

  PreprocessResult({
    required this.tokenIds,
    required this.matchedWords,
    required this.unmatchedWords,
  });
}

/// Cleans transcribed text and converts it into a token array for the ML model.
///
/// Also tracks which words were recognized by the vocabulary (matched)
/// vs. which were unknown (unmatched / mapped to 0).
class TextPreprocessor {
  // Must match the Conv1D model's expected input shape
  static const int maxSequenceLength = 60;

  Map<String, int> _vocab = {};

  Future<void> loadVocab() async {
    try {
      final vocabString =
          await rootBundle.loadString('assets/models/vocab.json');
      final decoded = jsonDecode(vocabString);

      _vocab = {};

      if (decoded is Map) {
        // Standard dictionary {"word": 1}
        decoded.forEach((key, value) {
          _vocab[key.toString()] = int.tryParse(value.toString()) ?? 0;
        });
        debugPrint('✅ VOCAB LOADED: ${_vocab.length} words found (Map format)');
      } else if (decoded is List) {
        // Flat list ["word1", "word2"] — Keras is usually 1-indexed
        for (int i = 0; i < decoded.length; i++) {
          _vocab[decoded[i].toString()] = i + 1;
        }
        debugPrint(
            '✅ VOCAB LOADED: ${_vocab.length} words found (List format)');
      } else {
        debugPrint('❌ ERROR: Unrecognized vocab.json format.');
      }
    } catch (e) {
      debugPrint('❌ CRITICAL ERROR loading vocab.json: $e');
    }
  }

  /// Preprocess text into model-ready tokens and keyword metadata.
  PreprocessResult preprocess(String text) {
    final normalizedText =
        text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), '');

    final words = normalizedText
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();

    final List<String> matchedWords = [];
    final List<String> unmatchedWords = [];

    final tokenIds = words.map((token) {
      if (_vocab.containsKey(token)) {
        if (!matchedWords.contains(token)) matchedWords.add(token);
        return _vocab[token]!;
      } else {
        if (!unmatchedWords.contains(token)) unmatchedWords.add(token);
        return 0;
      }
    }).toList();

    // Pre-padding to match Python/Keras default behavior
    List<int> finalSequence;
    if (tokenIds.length > maxSequenceLength) {
      // Truncate from the beginning
      finalSequence = tokenIds.sublist(tokenIds.length - maxSequenceLength);
    } else if (tokenIds.length < maxSequenceLength) {
      // Pad with zeros at the beginning
      int paddingNeeded = maxSequenceLength - tokenIds.length;
      finalSequence = List<int>.filled(paddingNeeded, 0) + tokenIds;
    } else {
      finalSequence = tokenIds;
    }

    debugPrint('🔢 TOKEN ARRAY: $finalSequence');

    return PreprocessResult(
      tokenIds: finalSequence,
      matchedWords: matchedWords,
      unmatchedWords: unmatchedWords,
    );
  }

  bool get isLoaded => _vocab.isNotEmpty;
}
