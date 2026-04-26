import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../config/constants.dart';
import '../config/theme.dart';
import '../models/call_state.dart';
import '../services/ringtone_service.dart';
import '../services/signaling_service.dart';
import '../services/webrtc_service.dart';
import '../widgets/call_actions.dart';
import '../widgets/call_avatar.dart';
import '../widgets/call_status_pill.dart';
import '../widgets/call_waiting_dialog.dart';

class CallScreen extends StatefulWidget {
  final SignalingService signaling;
  final String userId;
  final String remoteId;
  final bool isIncoming;
  final dynamic sdpOffer;

  const CallScreen({
    super.key,
    required this.signaling,
    required this.userId,
    required this.remoteId,
    required this.isIncoming,
    this.sdpOffer,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with TickerProviderStateMixin {
  final WebRTCService _webrtc = WebRTCService();
  final RingtoneService _ringtone = RingtoneService();

  CallStatus _status = CallStatus.connecting;
  bool _isMuted = false;
  bool _isSpeaker = false;
  bool _callEnded = false;
  Timer? _callTimer;
  Timer? _ringTimeout;
  int _seconds = 0;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _setupCall();
  }

  Future<void> _setupCall() async {
    final iceConfig = await WebRTCService.fetchIceConfig();

    try {
      await _webrtc.initialize(iceConfig);
    } catch (e) {
      _fail(CallStatus.microphoneError);
      return;
    }

    _webrtc.onIceCandidate = (candidate) {
      widget.signaling.sendIceCandidate({
        'to': widget.remoteId,
        'candidate': {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      });
    };

    _webrtc.onRemoteStream = (_) {
      if (!_callEnded) _onConnected();
    };

    _webrtc.onIceConnectionState = (state) {
      if (_callEnded) return;
      switch (state) {
        case RTCIceConnectionState.RTCIceConnectionStateFailed:
          _fail(CallStatus.connectionFailed);
          break;
        case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
          _setStatus(CallStatus.reconnecting);
          break;
        case RTCIceConnectionState.RTCIceConnectionStateConnected:
        case RTCIceConnectionState.RTCIceConnectionStateCompleted:
          if (!_status.isActive) _onConnected();
          break;
        default:
          break;
      }
    };

    // ICE candidates from remote
    widget.signaling.onIceCandidate = (data) {
      try {
        if (data['candidate'] != null) {
          _webrtc.addIceCandidate(RTCIceCandidate(
            data['candidate']['candidate'],
            data['candidate']['sdpMid'],
            data['candidate']['sdpMLineIndex'],
          ));
        }
      } catch (_) {}
    };

    widget.signaling.onCallEnded = (_) {
      if (!_callEnded) _endCall(reason: CallStatus.ended);
    };

    widget.signaling.onUserOffline = (_) {
      if (!_callEnded) _fail(CallStatus.offline);
    };

    // Call waiting: incoming call while on this call
    widget.signaling.onIncomingCall = (data) => _onCallWaiting(data);

    try {
      if (widget.isIncoming) {
        _setStatus(CallStatus.answering);
        await _webrtc.setRemoteDescription(
          RTCSessionDescription(widget.sdpOffer['sdp'], widget.sdpOffer['type']),
        );
        final answer = await _webrtc.createAnswer();
        widget.signaling.answerCall({
          'to': widget.remoteId,
          'answer': {'sdp': answer.sdp, 'type': answer.type},
        });
      } else {
        _setStatus(CallStatus.ringing);
        _ringtone.playRingback();

        final offer = await _webrtc.createOffer();
        widget.signaling.callUser({
          'from': widget.userId,
          'target': widget.remoteId,
          'offer': {'sdp': offer.sdp, 'type': offer.type},
        });

        _ringTimeout = Timer(
          const Duration(seconds: AppConfig.ringTimeoutSeconds),
          () {
            if (_status == CallStatus.ringing && !_callEnded) {
              _fail(CallStatus.noAnswer);
            }
          },
        );

        widget.signaling.onCallAnswered = (data) async {
          _ringTimeout?.cancel();
          _ringtone.stop();
          try {
            if (data['answer'] != null) {
              await _webrtc.setRemoteDescription(
                RTCSessionDescription(data['answer']['sdp'], data['answer']['type']),
              );
              _onConnected();
            }
          } catch (e) {
            _fail(CallStatus.connectionError);
          }
        };

        widget.signaling.onCallRejected = (_) {
          if (!_callEnded) _fail(CallStatus.declined);
        };
      }
    } catch (e) {
      _fail(CallStatus.failed);
    }
  }

  // ── State transitions ──

  void _setStatus(CallStatus status) {
    if (mounted) setState(() => _status = status);
  }

  void _onConnected() {
    _ringtone.stop();
    _ringTimeout?.cancel();
    // Dismiss the native callkit incoming notification
    FlutterCallkitIncoming.endAllCalls();
    if (mounted && !_callEnded) {
      HapticFeedback.mediumImpact();
      _setStatus(CallStatus.connected);
      _pulseController.stop();
      _pulseController.value = 0;
      _callTimer?.cancel();
      _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _seconds++);
      });
    }
  }

  void _fail(CallStatus reason) {
    if (_callEnded) return;
    _callEnded = true;
    _ringtone.stop();
    _ringTimeout?.cancel();
    _callTimer?.cancel();
    HapticFeedback.heavyImpact();
    if (mounted) {
      _setStatus(reason);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      });
    }
  }

  void _endCall({CallStatus? reason}) async {
    if (_callEnded) return;
    _callEnded = true;
    _ringtone.stop();
    _callTimer?.cancel();
    _ringTimeout?.cancel();
    HapticFeedback.mediumImpact();
    // Dismiss any lingering callkit notification
    FlutterCallkitIncoming.endAllCalls();
    try {
      widget.signaling.endCall({'to': widget.remoteId});
      await _webrtc.dispose();
    } catch (_) {}
    if (reason != null && mounted) {
      _setStatus(reason);
      await Future.delayed(const Duration(seconds: 1));
    }
    if (mounted && Navigator.canPop(context)) Navigator.pop(context);
  }

  // ── Call waiting ──

  void _onCallWaiting(dynamic data) {
    final callerId = data['from'] ?? 'Unknown';
    HapticFeedback.heavyImpact();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CallWaitingDialog(
        callerId: callerId,
        currentCallId: widget.remoteId,
        onReject: () {
          Navigator.of(ctx).pop();
          widget.signaling.rejectCall({'to': callerId});
        },
        onSwitch: () {
          Navigator.of(ctx).pop();
          _switchToCall(callerId, data['offer']);
        },
      ),
    );
  }

  void _switchToCall(String callerId, dynamic sdpOffer) async {
    _callTimer?.cancel();
    try {
      widget.signaling.endCall({'to': widget.remoteId});
      await _webrtc.dispose();
    } catch (_) {}

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          signaling: widget.signaling,
          userId: widget.userId,
          remoteId: callerId,
          isIncoming: true,
          sdpOffer: sdpOffer,
        ),
      ),
    );
  }

  // ── Controls ──

  void _toggleMute() {
    HapticFeedback.lightImpact();
    setState(() => _isMuted = !_isMuted);
    _webrtc.localStream?.getAudioTracks().forEach((t) => t.enabled = !_isMuted);
  }

  void _toggleSpeaker() async {
    HapticFeedback.lightImpact();
    setState(() => _isSpeaker = !_isSpeaker);
    try { await Helper.setSpeakerphoneOn(_isSpeaker); } catch (_) {}
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _ringTimeout?.cancel();
    _pulseController.dispose();
    _ringtone.stop();
    _webrtc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              if (_status.isTerminal) ...[
                Colors.red.shade900.withOpacity(0.3),
                AppColors.background,
              ] else if (_status.isActive) ...[
                const Color(0xFF0A1A2E),
                AppColors.background,
              ] else ...[
                const Color(0xFF0A0A2E),
                AppColors.background,
              ],
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _status.isActive ? Icons.lock : Icons.signal_cellular_alt,
                            color: AppColors.textSecondary, size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _status.isActive ? 'Encrypted' : 'CallGuard',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12, letterSpacing: 1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 2),

              // Avatar
              CallAvatar(
                remoteId: widget.remoteId,
                status: _status,
                pulseAnimation: _pulseController,
              ),

              const SizedBox(height: 28),

              // Remote ID
              Text(widget.remoteId, style: AppTextStyles.idDisplaySmall),
              const SizedBox(height: 6),
              Text('CallGuard ID', style: AppTextStyles.caption),

              const SizedBox(height: 24),

              // Status pill
              CallStatusPill(
                status: _status,
                seconds: _seconds,
                pulseAnimation: _pulseController,
              ),

              const Spacer(flex: 3),

              // Actions
              if (!_status.isTerminal)
                CallActions(
                  isMuted: _isMuted,
                  isSpeaker: _isSpeaker,
                  showControls: _status.isActive,
                  onToggleMute: _toggleMute,
                  onToggleSpeaker: _toggleSpeaker,
                  onEndCall: () => _endCall(),
                ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
