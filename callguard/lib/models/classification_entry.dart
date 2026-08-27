import 'dart:convert';

/// Represents a single fraud classification result.
class ClassificationEntry {
  final int? id;
  final DateTime timestamp;
  final String inputType; // 'recording' or 'file_upload'
  final String? fileName;
  final String transcript;
  final List<String> matchedKeywords;
  final List<String> unmatchedWords;
  final double confidenceScore;
  final String verdict; // 'FRAUD' or 'LEGITIMATE'

  ClassificationEntry({
    this.id,
    required this.timestamp,
    required this.inputType,
    this.fileName,
    required this.transcript,
    required this.matchedKeywords,
    required this.unmatchedWords,
    required this.confidenceScore,
    required this.verdict,
  });

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'inputType': inputType,
      'fileName': fileName,
      'transcript': transcript,
      'matchedKeywords': jsonEncode(matchedKeywords),
      'unmatchedWords': jsonEncode(unmatchedWords),
      'confidenceScore': confidenceScore,
      'verdict': verdict,
    };
  }

  factory ClassificationEntry.fromMap(Map<String, dynamic> map) {
    return ClassificationEntry(
      id: map['id'] as int?,
      timestamp: DateTime.parse(map['timestamp'] as String),
      inputType: map['inputType'] as String,
      fileName: map['fileName'] as String?,
      transcript: map['transcript'] as String,
      matchedKeywords: List<String>.from(jsonDecode(map['matchedKeywords'] as String)),
      unmatchedWords: List<String>.from(jsonDecode(map['unmatchedWords'] as String)),
      confidenceScore: (map['confidenceScore'] as num).toDouble(),
      verdict: map['verdict'] as String,
    );
  }
}
