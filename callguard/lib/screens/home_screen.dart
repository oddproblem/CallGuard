import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:uuid/uuid.dart';
import '../config/constants.dart';
import '../config/theme.dart';
import '../services/permission_service.dart';
import '../services/push_notification_service.dart';
import '../services/ringtone_service.dart';
import '../services/signaling_service.dart';
import '../services/user_service.dart';
import '../widgets/dial_pad.dart';
import '../widgets/id_card.dart';
import 'call_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  String _userId = '------';
  final TextEditingController _dialController = TextEditingController();
  final SignalingService _signaling = SignalingService();
  final RingtoneService _ringtone = RingtoneService();
  final PushNotificationService _pushService = PushNotificationService();
  bool _isConnected = false;

  late AnimationController _pulseController;
  late AnimationController _idRevealController;

  StreamSubscription? _callkitSubscription;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this, duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _idRevealController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800),
    );
    _init();
  }

  Future<void> _init() async {
    final id = await UserService.getUserId();
    if (mounted) {
      setState(() => _userId = id);
      _idRevealController.forward();
    }
    await _pushService.initialize();
    _connectSignaling(id);
    _listenCallkitEvents();
  }

  /// Listen for callkit accept/decline events.
  /// When the user accepts a call from the native callkit UI,
  /// we navigate to the call screen.
  void _listenCallkitEvents() {
    _callkitSubscription = FlutterCallkitIncoming.onEvent.listen((CallEvent? event) {
      if (event == null) return;

      switch (event.event) {
        case Event.actionCallAccept:
          // User accepted the incoming call from native UI
          final body = event.body as Map<dynamic, dynamic>?;
          if (body != null) {
            final extra = body['extra'] as Map<dynamic, dynamic>?;
            if (extra != null) {
              final callerId = extra['callerId'] as String? ?? 'Unknown';
              final offerStr = extra['offer'] as String? ?? '';

              // Parse the SDP offer
              dynamic sdpOffer;
              if (offerStr.isNotEmpty) {
                try {
                  sdpOffer = json.decode(offerStr);
                } catch (_) {}
              }

              if (sdpOffer != null) {
                _navigateToCall(callerId, isIncoming: true, sdpOffer: sdpOffer);
              } else {
                // If we don't have the offer (e.g. app was killed),
                // just navigate and let the call screen handle reconnection
                _navigateToCall(callerId, isIncoming: true, sdpOffer: sdpOffer);
              }
            }
          }
          break;

        case Event.actionCallDecline:
          // User declined the call from native UI
          final body = event.body as Map<dynamic, dynamic>?;
          if (body != null) {
            final extra = body['extra'] as Map<dynamic, dynamic>?;
            if (extra != null) {
              final callerId = extra['callerId'] as String? ?? '';
              if (callerId.isNotEmpty) {
                _signaling.rejectCall({'to': callerId});
              }
            }
          }
          break;

        case Event.actionCallTimeout:
          debugPrint('[CALLKIT] Call timed out');
          break;

        default:
          break;
      }
    });
  }

  void _connectSignaling(String userId) {
    _signaling.connect(AppConfig.serverUrl, userId);

    _signaling.onConnected = () async {
      if (mounted) setState(() => _isConnected = true);

      final token = await _pushService.getToken();
      if (token != null) {
        _signaling.socket.emit('register-fcm-token', {'userId': userId, 'token': token});
      }

      _pushService.onTokenRefresh((newToken) {
        _signaling.socket.emit('register-fcm-token', {'userId': userId, 'token': newToken});
      });
    };

    _signaling.onDisconnected = () {
      if (mounted) setState(() => _isConnected = false);
    };

    _signaling.onIncomingCall = (data) => _onIncomingCall(data);

    _signaling.onCallRejected = (data) {
      if (mounted) _showSnack('Call was declined', AppColors.error);
    };
  }

  // ── Incoming call via socket (user is online with app open) ──
  void _onIncomingCall(dynamic data) {
    final callerId = data['from'] ?? 'Unknown';
    final sdpOffer = data['offer'];

    HapticFeedback.heavyImpact();

    // Show native callkit incoming screen instead of custom dialog
    final callId = const Uuid().v4();
    final params = CallKitParams(
      id: callId,
      nameCaller: 'CallGuard User',
      handle: callerId,
      appName: 'CallGuard',
      type: 0,
      textAccept: 'Accept',
      textDecline: 'Decline',
      duration: 45000,
      extra: <String, dynamic>{
        'callerId': callerId,
        'offer': json.encode(sdpOffer),
      },
      missedCallNotification: const NotificationParams(
        showNotification: true,
        isShowCallback: true,
        subtitle: 'Missed call',
        callbackText: 'Call back',
      ),
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#0A0A2E',
        actionColor: '#6C63FF',
        textColor: '#ffffff',
        incomingCallNotificationChannelName: 'Incoming Call',
        missedCallNotificationChannelName: 'Missed Call',
        isShowCallID: true,
      ),
    );

    FlutterCallkitIncoming.showCallkitIncoming(params);
    // The callkit event listener (_listenCallkitEvents) will handle accept/decline
  }

  // ── Make outgoing call ──
  Future<void> _makeCall() async {
    final targetId = _dialController.text.trim();

    if (targetId.isEmpty || targetId.length != AppConfig.idLength) {
      _showSnack('Enter a valid ${AppConfig.idLength}-digit ID', AppColors.warning);
      return;
    }
    if (targetId == _userId) {
      _showSnack('You cannot call yourself', AppColors.warning);
      return;
    }
    if (!_isConnected) {
      _showSnack('Connecting to server, please wait...', AppColors.warning);
      return;
    }

    HapticFeedback.mediumImpact();

    final hasMic = await PermissionService.requestMicrophone();
    if (!hasMic) {
      if (mounted) _showSnack('Microphone permission required', AppColors.error);
      return;
    }

    if (mounted) _navigateToCall(targetId, isIncoming: false);
  }

  void _navigateToCall(String remoteId, {required bool isIncoming, dynamic sdpOffer}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          signaling: _signaling,
          userId: _userId,
          remoteId: remoteId,
          isIncoming: isIncoming,
          sdpOffer: sdpOffer,
        ),
      ),
    );
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    ));
  }

  @override
  void dispose() {
    _callkitSubscription?.cancel();
    _pulseController.dispose();
    _idRevealController.dispose();
    _dialController.dispose();
    _signaling.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.backgroundSubtle),
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
                          Color.lerp(AppColors.accent, AppColors.purple, _pulseController.value)!,
                          Color.lerp(AppColors.purple, AppColors.accent, _pulseController.value)!,
                        ],
                      ).createShader(bounds),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shield_rounded, color: Colors.white, size: 30),
                          SizedBox(width: 10),
                          Text('CallGuard', style: AppTextStyles.heading),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                Text('Secure VoIP Calling', style: AppTextStyles.caption),

                const SizedBox(height: 36),

                // ── ID Card ──
                IdCard(
                  userId: _userId,
                  isConnected: _isConnected,
                  revealAnimation: _idRevealController,
                  onCopied: () => _showSnack('ID copied!', AppColors.accent),
                ),

                const SizedBox(height: 28),

                // ── Dial Pad ──
                DialPad(
                  controller: _dialController,
                  onCall: _makeCall,
                ),

                const SizedBox(height: 32),

                // ── Help tip ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: AppColors.textMuted, size: 16),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Tap your ID to copy it. Share it with others to receive calls.',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.4),
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
