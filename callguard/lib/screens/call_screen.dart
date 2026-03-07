import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/signaling_service.dart';
import '../services/webrtc_service.dart';

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

class _CallScreenState extends State<CallScreen> with SingleTickerProviderStateMixin {
  final WebRTCService _webrtc = WebRTCService();
  String _callStatus = 'Connecting...';
  bool _isMuted = false;
  bool _isSpeaker = false;
  Timer? _callTimer;
  int _seconds = 0;
  late AnimationController _ringController;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _setupCall();
  }

  Future<void> _setupCall() async {
    try {
      await _webrtc.initialize();
    } catch (e) {
      print('WebRTC init error: $e');
      if (mounted) {
        setState(() => _callStatus = 'Microphone Error');
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) Navigator.pop(context);
      }
      return;
    }

    // Send ICE candidates to the other peer
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
      if (mounted) {
        setState(() => _callStatus = 'Connected');
        _startTimer();
      }
    };

    // Handle incoming ICE candidates
    widget.signaling.onIceCandidate = (data) {
      try {
        if (data['candidate'] != null) {
          _webrtc.addIceCandidate(
            RTCIceCandidate(
              data['candidate']['candidate'],
              data['candidate']['sdpMid'],
              data['candidate']['sdpMLineIndex'],
            ),
          );
        }
      } catch (e) {
        print('ICE candidate error: $e');
      }
    };

    // Handle call ended by remote
    widget.signaling.onCallEnded = (data) {
      _endCall(showSnackbar: false);
    };

    try {
      if (widget.isIncoming) {
        // Incoming call: set remote offer, create answer
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
        // Outgoing call: create offer and send
        if (mounted) setState(() => _callStatus = 'Ringing...');
        final offer = await _webrtc.createOffer();
        widget.signaling.callUser({
          'from': widget.userId,
          'target': widget.remoteId,
          'offer': {'sdp': offer.sdp, 'type': offer.type},
        });

        // Listen for answer
        widget.signaling.onCallAnswered = (data) async {
          try {
            if (data['answer'] != null) {
              await _webrtc.setRemoteDescription(
                RTCSessionDescription(data['answer']['sdp'], data['answer']['type']),
              );
              if (mounted) {
                setState(() => _callStatus = 'Connected');
                _startTimer();
              }
            }
          } catch (e) {
            print('Answer handling error: $e');
          }
        };

        // Listen for rejection
        widget.signaling.onCallRejected = (data) {
          if (mounted) {
            setState(() => _callStatus = 'Call Rejected');
            Future.delayed(const Duration(seconds: 1), () {
              if (mounted) Navigator.pop(context);
            });
          }
        };
      }
    } catch (e) {
      print('Call setup error: $e');
      if (mounted) {
        setState(() => _callStatus = 'Call Failed');
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) Navigator.pop(context);
      }
    }
  }

  void _startTimer() {
    _ringController.stop();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _seconds++);
      }
    });
  }

  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    _webrtc.localStream?.getAudioTracks().forEach((track) {
      track.enabled = !_isMuted;
    });
  }

  void _toggleSpeaker() async {
    setState(() => _isSpeaker = !_isSpeaker);
    try {
      await Helper.setSpeakerphoneOn(_isSpeaker);
    } catch (e) {
      print('Speaker toggle error: $e');
    }
  }

  void _endCall({bool showSnackbar = true}) async {
    _callTimer?.cancel();
    try {
      widget.signaling.endCall({'to': widget.remoteId});
      await _webrtc.dispose();
    } catch (e) {
      print('End call error: $e');
    }
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _ringController.dispose();
    _webrtc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _callStatus == 'Connected';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),

            // ── Remote peer avatar ──
            AnimatedBuilder(
              animation: _ringController,
              builder: (context, child) {
                final scale = isConnected ? 1.0 : 1.0 + (_ringController.value * 0.08);
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF00D2FF), Color(0xFF7B2FFF)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00D2FF).withOpacity(isConnected ? 0.3 : 0.5),
                          blurRadius: isConnected ? 20 : 30,
                          spreadRadius: isConnected ? 2 : 5,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.person, color: Colors.white, size: 60),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // ── Remote ID ──
            Text(
              widget.remoteId,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
                letterSpacing: 6,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'CallGuard ID',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 14,
                letterSpacing: 2,
              ),
            ),

            const SizedBox(height: 20),

            // ── Status / Timer ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: isConnected
                    ? Colors.greenAccent.withOpacity(0.1)
                    : Colors.orangeAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isConnected ? _formatDuration(_seconds) : _callStatus,
                style: TextStyle(
                  color: isConnected ? Colors.greenAccent : Colors.orangeAccent,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: isConnected ? 4 : 1,
                ),
              ),
            ),

            const Spacer(flex: 3),

            // ── Action buttons ──
            if (isConnected)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(
                      icon: _isMuted ? Icons.mic_off : Icons.mic,
                      label: _isMuted ? 'Unmute' : 'Mute',
                      onTap: _toggleMute,
                      isActive: _isMuted,
                    ),
                    _buildActionButton(
                      icon: _isSpeaker ? Icons.volume_up : Icons.volume_down,
                      label: 'Speaker',
                      onTap: _toggleSpeaker,
                      isActive: _isSpeaker,
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 40),

            // ── End call button ──
            GestureDetector(
              onTap: _endCall,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.call_end, color: Colors.white, size: 32),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'End Call',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 13,
              ),
            ),

            const Spacer(),
          ],
        ),
      ),
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
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF00D2FF).withOpacity(0.2)
                  : Colors.white.withOpacity(0.08),
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive
                    ? const Color(0xFF00D2FF).withOpacity(0.5)
                    : Colors.white.withOpacity(0.15),
              ),
            ),
            child: Center(
              child: Icon(
                icon,
                color: isActive ? const Color(0xFF00D2FF) : Colors.white70,
                size: 26,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
