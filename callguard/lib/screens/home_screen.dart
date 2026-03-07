import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../utils/id_generator.dart';
import '../services/signaling_service.dart';
import 'call_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  String _userId = '------';
  final TextEditingController _targetIdController = TextEditingController();
  final SignalingService _signaling = SignalingService();
  bool _isConnected = false;

  // ── Change this to your server IP ──
  static const String _serverUrl = 'http://192.168.1.39:3000';

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _initUser();
  }

  Future<void> _initUser() async {
    final id = await getUserId();
    if (mounted) {
      setState(() => _userId = id);
    }
    _connectToServer(id);
  }

  void _connectToServer(String userId) {
    _signaling.connect(_serverUrl, userId);

    _signaling.onIncomingCall = (data) {
      _showIncomingCallDialog(data);
    };

    _signaling.onCallRejected = (data) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Call was rejected'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    };

    // A small delay to check connection state
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _isConnected = true);
      }
    });
  }

  void _showIncomingCallDialog(dynamic data) {
    final callerId = data['from'] ?? 'Unknown';
    final sdpOffer = data['offer'];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.phone_callback, color: Color(0xFF00D2FF), size: 28),
            SizedBox(width: 12),
            Text('Incoming Call', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'CallGuard ID: $callerId is calling you',
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              _signaling.rejectCall({'to': callerId});
            },
            icon: const Icon(Icons.call_end, color: Colors.redAccent),
            label: const Text('Reject', style: TextStyle(color: Colors.redAccent)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D2FF),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _acceptCall(callerId, sdpOffer);
            },
            icon: const Icon(Icons.call),
            label: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  void _acceptCall(String callerId, dynamic sdpOffer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          signaling: _signaling,
          userId: _userId,
          remoteId: callerId,
          isIncoming: true,
          sdpOffer: sdpOffer,
        ),
      ),
    );
  }

  Future<void> _makeCall() async {
    final targetId = _targetIdController.text.trim();
    if (targetId.isEmpty || targetId.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 6-digit CallGuard ID'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }
    if (targetId == _userId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot call yourself!'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    // Request microphone permission before starting the call
    try {
      final stream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
      // Permission granted — dispose the test stream immediately
      stream.getTracks().forEach((track) => track.stop());
      await stream.dispose();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission is required for calls'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          signaling: _signaling,
          userId: _userId,
          remoteId: targetId,
          isIncoming: false,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _targetIdController.dispose();
    _signaling.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // ── App Logo / Title ──
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [
                        Color.lerp(const Color(0xFF00D2FF), const Color(0xFF7B2FFF), _pulseController.value)!,
                        Color.lerp(const Color(0xFF7B2FFF), const Color(0xFF00D2FF), _pulseController.value)!,
                      ],
                    ).createShader(bounds),
                    child: const Text(
                      'CallGuard',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Secure VoIP Calling',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 14,
                  letterSpacing: 4,
                ),
              ),

              const SizedBox(height: 40),

              // ── Your ID Card ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF00D2FF).withOpacity(0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00D2FF).withOpacity(0.1),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'YOUR CALLGUARD ID',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: _userId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('ID copied to clipboard!'),
                            backgroundColor: Color(0xFF00D2FF),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _userId,
                            style: const TextStyle(
                              color: Color(0xFF00D2FF),
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 8,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.copy,
                            color: Colors.white.withOpacity(0.3),
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _isConnected ? Colors.greenAccent : Colors.redAccent,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (_isConnected ? Colors.greenAccent : Colors.redAccent).withOpacity(0.5),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isConnected ? 'Online' : 'Connecting...',
                          style: TextStyle(
                            color: _isConnected ? Colors.greenAccent : Colors.redAccent,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // ── Dial Section ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E).withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MAKE A CALL',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _targetIdController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        letterSpacing: 6,
                        fontFamily: 'monospace',
                      ),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: '000000',
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.15),
                          fontSize: 24,
                          letterSpacing: 6,
                          fontFamily: 'monospace',
                        ),
                        counterText: '',
                        filled: true,
                        fillColor: const Color(0xFF0A0A1A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFF00D2FF), width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _makeCall,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00D2FF),
                          foregroundColor: const Color(0xFF0A0A1A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.call, size: 24),
                            SizedBox(width: 10),
                            Text(
                              'CALL',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // ── Footer info ──
              Text(
                'Share your ID with others to receive calls',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
