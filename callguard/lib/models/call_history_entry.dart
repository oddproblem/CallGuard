/// Represents a single entry in the VoIP call history log.
class CallHistoryEntry {
  final int? id;
  final String remoteId;
  final String? savedName;
  final bool isIncoming;
  final DateTime startTime;
  final DateTime? endTime;
  final int durationSeconds;
  final String status; // connected, declined, missed, no_answer, failed

  CallHistoryEntry({
    this.id,
    required this.remoteId,
    this.savedName,
    required this.isIncoming,
    required this.startTime,
    this.endTime,
    required this.durationSeconds,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'remoteId': remoteId,
      'savedName': savedName,
      'isIncoming': isIncoming ? 1 : 0,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'durationSeconds': durationSeconds,
      'status': status,
    };
  }

  factory CallHistoryEntry.fromMap(Map<String, dynamic> map) {
    return CallHistoryEntry(
      id: map['id'] as int?,
      remoteId: map['remoteId'] as String,
      savedName: map['savedName'] as String?,
      isIncoming: (map['isIncoming'] as int) == 1,
      startTime: DateTime.parse(map['startTime'] as String),
      endTime: map['endTime'] != null
          ? DateTime.parse(map['endTime'] as String)
          : null,
      durationSeconds: map['durationSeconds'] as int,
      status: map['status'] as String,
    );
  }
}
