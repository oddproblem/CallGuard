import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/signaling_service.dart';
import '../services/webrtc_service.dart';

class CallScreen extends StatefulWidget {
  final SignalingService signaling;
  final String userId;
  final String remoteId;
  final bool isIncoming;
  final dynamic sdpOffer;
  final String serverUrl;

  const CallScreen({
    super.key,
    required this.signaling,
    required this.userId,
    required this.remoteId,
    required this.isIncoming,
    required this.serverUrl,
    this.sdpOffer,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with TickerProviderStateMixin {
  final WebRTCService _webrtc = WebRTCService();
  String _callStatus = 'Connecting...';
  bool _isMuted = false;
  bool _isSpeaker = false;
  bool _callEnded = false;
  Timer? _callTimer;
  Timer? _ringTimeout;
  Timer? _ringbackTimer;
  int _seconds = 0;
  late AnimationController _pulseController;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
      value: 1.0,
    );
    _setupCall();
  }

  Future<void> _setupCall() async {
    final iceConfig = await WebRTCService.fetchIceConfig(widget.serverUrl);

    try {
      await _webrtc.initialize(iceConfig);
    } catch (e) {
      print('WebRTC init error: $e');
      _handleCallFailed('Microphone Error');
      return;
    }

    // Send ICE candidates
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

    _webrtc.onRemoteStream = (stream) {
      if (mounted && !_callEnded) {
        _onCallConnected();
      }
    };

    // Monitor ICE state
    _webrtc.onIceConnectionState = (state) {
      if (_callEnded) return;
      if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        _handleCallFailed('Connection Failed');
      } else if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
        if (mounted) setState(() => _callStatus = 'Reconnecting...');
      } else if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
                 state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        if (_callStatus != 'Connected') _onCallConnected();
      }
    };

    // Handle incoming ICE candidates
    widget.signaling.onIceCandidate = (data) {
      try {
        if (data['candidate'] != null) {
          _webrtc.addIceCandidate(RTCIceCandidate(
            data['candidate']['candidate'],
            data['candidate']['sdpMid'],
            data['candidate']['sdpMLineIndex'],
          ));
        }
      } catch (e) {
        print('ICE candidate error: $e');
      }
    };

    widget.signaling.onCallEnded = (data) {
      if (!_callEnded) _endCall(reason: 'Call Ended');
    };

    widget.signaling.onUserOffline = (data) {
      if (!_callEnded) _handleCallFailed('User Offline');
    };

    // Handle incoming calls while on this call
    widget.signaling.onIncomingCall = (data) {
      _showCallWaitingDialog(data);
    };

    try {
      if (widget.isIncoming) {
        if (mounted) setState(() => _callStatus = 'Answering...');
        await _webrtc.setRemoteDescription(
          RTCSessionDescription(widget.sdpOffer['sdp'], widget.sdpOffer['type']),
        );
        final answer = await _webrtc.createAnswer();
        widget.signaling.answerCall({
          'to': widget.remoteId,
          'answer': {'sdp': answer.sdp, 'type': answer.type},
        });
      } else {
        if (mounted) setState(() => _callStatus = 'Ringing...');
        // Play ringback tone (short beeps, NOT the phone ringtone)
        _startRingback();

        final offer = await _webrtc.createOffer();
        widget.signaling.callUser({
          'from': widget.userId,
          'target': widget.remoteId,
          'offer': {'sdp': offer.sdp, 'type': offer.type},
        });

        _ringTimeout = Timer(const Duration(seconds: 45), () {
          if (_callStatus == 'Ringing...' && !_callEnded) {
            _handleCallFailed('No Answer');
          }
        });

        widget.signaling.onCallAnswered = (data) async {
          _ringTimeout?.cancel();
          _stopRingback();
          try {
            if (data['answer'] != null) {
              await _webrtc.setRemoteDescription(
                RTCSessionDescription(data['answer']['sdp'], data['answer']['type']),
              );
              _onCallConnected();
            }
          } catch (e) {
            print('Answer handling error: $e');
            _handleCallFailed('Connection Error');
          }
        };

        widget.signaling.onCallRejected = (data) {
          if (!_callEnded) _handleCallFailed('Call Declined');
        };
      }
    } catch (e) {
      print('Call setup error: $e');
      _handleCallFailed('Call Failed');
    }
  }

  void _onCallConnected() {
    _stopRingback();
    _ringTimeout?.cancel();
    if (mounted && !_callEnded) {
      HapticFeedback.mediumImpact();
      setState(() => _callStatus = 'Connected');
      _startTimer();
    }
  }

  // ── Ringback tone (outgoing call "ring ring") ──
  void _startRingback() {
    // Play a short notification tone every 3 seconds to simulate ringback
    _playRingbackBeep();
    _ringbackTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_callStatus == 'Ringing...' && !_callEnded) {
        _playRingbackBeep();
      }
    });
  }

  void _playRingbackBeep() {
    FlutterRingtonePlayer().play(
      android: AndroidSounds.notification,
      ios: IosSounds.glass,
      looping: false,
      volume: 0.3,
    );
  }

  void _stopRingback() {
    _ringbackTimer?.cancel();
    _ringbackTimer = null;
    FlutterRingtonePlayer().stop();
  }

  // ── Call Waiting Dialog ──
  void _showCallWaitingDialog(dynamic data) {
    final callerId = data['from'] ?? 'Unknown';

    HapticFeedback.heavyImpact();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF00D2FF).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.phone_callback, color: Color(0xFF00D2FF), size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Incoming Call',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              callerId,
              style: const TextStyle(
                color: Color(0xFF00D2FF),
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You are currently on a call with ${widget.remoteId}',
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actionsPadding: const EdgeInsets.only(bottom: 16),
        actions: [
          // Reject the incoming call
          _buildDialogButton(
            icon: Icons.call_end,
            label: 'Reject',
            color: Colors.redAccent,
            onTap: () {
              Navigator.of(ctx).pop();
              widget.signaling.rejectCall({'to': callerId});
            },
          ),
          // End current call and accept new one
          _buildDialogButton(
            icon: Icons.swap_calls,
            label: 'Switch',
            color: Colors.orangeAccent,
            onTap: () {
              Navigator.of(ctx).pop();
              _switchToNewCall(callerId, data['offer']);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDialogButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.4)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _switchToNewCall(String callerId, dynamic sdpOffer) async {
    // End current call silently
    _callTimer?.cancel();
    try {
      widget.signaling.endCall({'to': widget.remoteId});
      await _webrtc.dispose();
    } catch (e) {
      print('Switch call dispose error: $e');
    }

    if (!mounted) return;

    // Navigate to new call screen, replacing current one
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          signaling: widget.signaling,
          userId: widget.userId,
          remoteId: callerId,
          isIncoming: true,
          sdpOffer: sdpOffer,
          serverUrl: widget.serverUrl,
        ),
      ),
    );
  }

  void _handleCallFailed(String reason) {
    if (_callEnded) return;
    _callEnded = true;
    _stopRingback();
    _ringTimeout?.cancel();
    _callTimer?.cancel();
    HapticFeedback.heavyImpact();
    if (mounted) {
      setState(() => _callStatus = reason);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _navigateBack();
      });
    }
  }

  void _startTimer() {
    _pulseController.stop();
    _pulseController.value = 0;
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _seconds++);
    });
  }

  String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    if (hours > 0) return '$hours:$minutes:$seconds';
    return '$minutes:$seconds';
  }

  void _toggleMute() {
    HapticFeedback.lightImpact();
    setState(() => _isMuted = !_isMuted);
    _webrtc.localStream?.getAudioTracks().forEach((track) {
      track.enabled = !_isMuted;
    });
  }

  void _toggleSpeaker() async {
    HapticFeedback.lightImpact();
    setState(() => _isSpeaker = !_isSpeaker);
    try {
      await Helper.setSpeakerphoneOn(_isSpeaker);
    } catch (e) {
      print('Speaker toggle error: $e');
    }
  }

  void _endCall({String? reason}) async {
    if (_callEnded) return;
    _callEnded = true;
    _stopRingback();
    _callTimer?.cancel();
    _ringTimeout?.cancel();
    HapticFeedback.mediumImpact();
    try {
      widget.signaling.endCall({'to': widget.remoteId});
      await _webrtc.dispose();
    } catch (e) {
      print('End call error: $e');
    }
    if (reason != null && mounted) {
      setState(() => _callStatus = reason);
      await Future.delayed(const Duration(seconds: 1));
    }
    if (mounted) _navigateBack();
  }

  void _navigateBack() {
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _ringTimeout?.cancel();
    _ringbackTimer?.cancel();
    _pulseController.dispose();
    _fadeController.dispose();
    FlutterRingtonePlayer().stop();
    _webrtc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _callStatus == 'Connected';
    final isRinging = _callStatus == 'Ringing...' || _callStatus == 'Answering...';
    final isFailed = ['Call Declined', 'User Offline', 'No Answer', 'Connection Failed',
                      'Call Failed', 'Connection Error', 'Microphone Error', 'Call Ended']
                      .contains(_callStatus);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              if (isFailed) ...[
                Colors.red.shade900.withOpacity(0.3),
                const Color(0xFF0A0A1A),
              ] else if (isConnected) ...[
                const Color(0xFF0A1A2E),
                const Color(0xFF0A0A1A),
              ] else ...[
                const Color(0xFF0A0A2E),
                const Color(0xFF0A0A1A),
              ],
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Top bar ──
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
                            isConnected ? Icons.lock : Icons.signal_cellular_alt,
                            color: Colors.white.withOpacity(0.4),
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isConnected ? 'Encrypted' : 'CallGuard',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 12,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 2),

              // ── Avatar ──
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final glowRadius = isConnected ? 15.0 : 15.0 + (_pulseController.value * 20);
                  final scale = isConnected ? 1.0 : 1.0 + (_pulseController.value * 0.05);
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isFailed
                              ? [Colors.red.shade400, Colors.red.shade900]
                              : [const Color(0xFF00D2FF), const Color(0xFF7B2FFF)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (isFailed ? Colors.redAccent : const Color(0xFF00D2FF))
                                .withOpacity(0.4),
                            blurRadius: glowRadius,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          widget.remoteId.isNotEmpty ? widget.remoteId[0] : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 28),

              // ── Remote ID ──
              Text(
                widget.remoteId,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 6,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'CallGuard ID',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 13,
                  letterSpacing: 2,
                ),
              ),

              const SizedBox(height: 24),

              // ── Status / Timer ──
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  color: _getStatusColor().withOpacity(0.12),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _getStatusColor().withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isRinging)
                      _buildPulsingDot(Colors.orangeAccent),
                    if (isConnected)
                      _buildPulsingDot(Colors.greenAccent),
                    if (isFailed)
                      Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      isConnected ? _formatDuration(_seconds) : _callStatus,
                      style: TextStyle(
                        color: _getStatusColor(),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: isConnected ? 3 : 0.5,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 3),

              // ── Action buttons (visible when connected) ──
              if (isConnected)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 50),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActionButton(
                        icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                        label: _isMuted ? 'Unmute' : 'Mute',
                        onTap: _toggleMute,
                        isActive: _isMuted,
                      ),
                      _buildActionButton(
                        icon: _isSpeaker ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                        label: 'Speaker',
                        onTap: _toggleSpeaker,
                        isActive: _isSpeaker,
                      ),
                    ],
                  ),
                ),

              if (!isFailed) ...[
                const SizedBox(height: 48),

                // ── End call button ──
                GestureDetector(
                  onTap: () => _endCall(),
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.red.shade400, Colors.red.shade700],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.redAccent.withOpacity(0.4),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.call_end_rounded, color: Colors.white, size: 30),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'End Call',
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                ),
              ],

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor() {
    if (_callStatus == 'Connected') return Colors.greenAccent;
    if (['Call Declined', 'User Offline', 'No Answer', 'Connection Failed',
         'Call Failed', 'Connection Error', 'Microphone Error', 'Call Ended']
         .contains(_callStatus)) return Colors.redAccent;
    if (_callStatus == 'Reconnecting...') return Colors.amberAccent;
    return Colors.orangeAccent;
  }

  Widget _buildPulsingDot(Color color) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color.withOpacity(0.6 + _pulseController.value * 0.4),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.3), blurRadius: 4),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF00D2FF).withOpacity(0.2)
                  : Colors.white.withOpacity(0.06),
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive
                    ? const Color(0xFF00D2FF).withOpacity(0.5)
                    : Colors.white.withOpacity(0.1),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Icon(
                icon,
                color: isActive ? const Color(0xFF00D2FF) : Colors.white60,
                size: 26,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: isActive ? const Color(0xFF00D2FF).withOpacity(0.8) : Colors.white.withOpacity(0.4),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
