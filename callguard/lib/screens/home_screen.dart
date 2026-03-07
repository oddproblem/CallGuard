import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:permission_handler/permission_handler.dart';
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

  static const String _serverUrl = 'https://callguard-server-pw4i.onrender.com';

  late AnimationController _pulseController;
  late AnimationController _idRevealController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _idRevealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _initUser();
  }

  Future<void> _initUser() async {
    final id = await getUserId();
    if (mounted) {
      setState(() => _userId = id);
      _idRevealController.forward();
    }
    _connectToServer(id);
  }

  void _connectToServer(String userId) {
    _signaling.connect(_serverUrl, userId);

    _signaling.onConnected = () {
      if (mounted) setState(() => _isConnected = true);
    };

    _signaling.onDisconnected = () {
      if (mounted) setState(() => _isConnected = false);
    };

    _signaling.onIncomingCall = (data) {
      _showIncomingCallDialog(data);
    };

    _signaling.onCallRejected = (data) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.call_end, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Call was declined'),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    };
  }

  void _showIncomingCallDialog(dynamic data) {
    final callerId = data['from'] ?? 'Unknown';
    final sdpOffer = data['offer'];

    HapticFeedback.heavyImpact();
    FlutterRingtonePlayer().play(
      android: AndroidSounds.ringtone,
      ios: IosSounds.electronic,
      looping: true,
      volume: 1.0,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Caller avatar
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF00D2FF), Color(0xFF7B2FFF)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00D2FF).withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  callerId.isNotEmpty ? callerId[0] : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Incoming Call',
              style: TextStyle(color: Colors.white70, fontSize: 14, letterSpacing: 2),
            ),
            const SizedBox(height: 8),
            Text(
              callerId,
              style: const TextStyle(
                color: Color(0xFF00D2FF),
                fontSize: 30,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 24),
            // Action row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Reject
                GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    FlutterRingtonePlayer().stop();
                    Navigator.of(ctx).pop();
                    _signaling.rejectCall({'to': callerId});
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [Colors.red.shade400, Colors.red.shade700]),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 28),
                      ),
                      const SizedBox(height: 8),
                      Text('Reject', style: TextStyle(color: Colors.red.shade300, fontSize: 12)),
                    ],
                  ),
                ),
                // Accept
                GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    FlutterRingtonePlayer().stop();
                    Navigator.of(ctx).pop();
                    _acceptCall(callerId, sdpOffer);
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [Colors.green.shade400, Colors.green.shade700]),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.call_rounded, color: Colors.white, size: 28),
                      ),
                      const SizedBox(height: 8),
                      Text('Accept', style: TextStyle(color: Colors.green.shade300, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
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
          serverUrl: _serverUrl,
        ),
      ),
    );
  }

  Future<void> _makeCall() async {
    final targetId = _targetIdController.text.trim();
    if (targetId.isEmpty || targetId.length != 6) {
      _showSnackBar('Enter a valid 6-digit ID', Colors.orangeAccent);
      return;
    }
    if (targetId == _userId) {
      _showSnackBar('You cannot call yourself', Colors.orangeAccent);
      return;
    }
    if (!_isConnected) {
      _showSnackBar('Connecting to server, please wait...', Colors.orangeAccent);
      return;
    }

    HapticFeedback.mediumImpact();
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) _showSnackBar('Microphone permission required', Colors.redAccent);
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
          serverUrl: _serverUrl,
        ),
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _idRevealController.dispose();
    _targetIdController.dispose();
    _signaling.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A0A1A), Color(0xFF0A102A), Color(0xFF0A0A1A)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                const SizedBox(height: 12),

                // ── Logo ──
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
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shield_rounded, color: Colors.white, size: 30),
                          SizedBox(width: 10),
                          Text(
                            'CallGuard',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                Text(
                  'Secure VoIP Calling',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontSize: 12,
                    letterSpacing: 4,
                  ),
                ),

                const SizedBox(height: 36),

                // ── Your ID Card ──
                FadeTransition(
                  opacity: _idRevealController,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.1),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: _idRevealController,
                      curve: Curves.easeOut,
                    )),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF141428), Color(0xFF1A1A3E)],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0xFF00D2FF).withOpacity(0.15),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00D2FF).withOpacity(0.06),
                            blurRadius: 30,
                            spreadRadius: 0,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.fingerprint, color: Colors.white.withOpacity(0.3), size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'YOUR ID',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.4),
                                  fontSize: 11,
                                  letterSpacing: 3,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Clipboard.setData(ClipboardData(text: _userId));
                              _showSnackBar('ID copied!', const Color(0xFF00D2FF));
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _userId,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 8,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.copy_rounded, color: Colors.white.withOpacity(0.3), size: 16),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Status pill
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: (_isConnected ? Colors.greenAccent : Colors.orangeAccent).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: (_isConnected ? Colors.greenAccent : Colors.orangeAccent).withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: _isConnected ? Colors.greenAccent : Colors.orangeAccent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _isConnected ? 'Online' : 'Connecting...',
                                  style: TextStyle(
                                    color: _isConnected ? Colors.greenAccent : Colors.orangeAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // ── Dial Section ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.dialpad_rounded, color: Colors.white.withOpacity(0.3), size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'DIAL',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 11,
                              letterSpacing: 3,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _targetIdController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          letterSpacing: 8,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: '• • • • • •',
                          hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.12),
                            fontSize: 28,
                            letterSpacing: 8,
                          ),
                          counterText: '',
                          filled: true,
                          fillColor: const Color(0xFF0A0A1A),
                          contentPadding: const EdgeInsets.symmetric(vertical: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
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
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: Ink(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF00D2FF), Color(0xFF0099CC)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Container(
                              alignment: Alignment.center,
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.call_rounded, size: 22, color: Colors.white),
                                  SizedBox(width: 10),
                                  Text(
                                    'CALL',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 4,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // ── Help text ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: Colors.white.withOpacity(0.2), size: 16),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Tap your ID to copy it. Share it with others to receive calls.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.25),
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
