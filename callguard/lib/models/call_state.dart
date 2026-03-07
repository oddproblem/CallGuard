/// All possible call states.
enum CallStatus {
  connecting('Connecting...'),
  ringing('Ringing...'),
  answering('Answering...'),
  connected('Connected'),
  reconnecting('Reconnecting...'),
  ended('Call Ended'),
  failed('Call Failed'),
  declined('Call Declined'),
  offline('User Offline'),
  noAnswer('No Answer'),
  connectionFailed('Connection Failed'),
  connectionError('Connection Error'),
  microphoneError('Microphone Error');

  final String label;
  const CallStatus(this.label);

  bool get isTerminal => [ended, failed, declined, offline, noAnswer,
                          connectionFailed, connectionError, microphoneError].contains(this);

  bool get isActive => this == connected;

  bool get isRinging => this == ringing || this == answering;
}

/// Holds information about an active or pending call.
class CallInfo {
  final String remoteId;
  final bool isIncoming;
  final dynamic sdpOffer;
  final DateTime startedAt;

  CallInfo({
    required this.remoteId,
    required this.isIncoming,
    this.sdpOffer,
    DateTime? startedAt,
  }) : startedAt = startedAt ?? DateTime.now();
}
