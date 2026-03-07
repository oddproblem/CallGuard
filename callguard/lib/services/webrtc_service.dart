import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import '../config/constants.dart';

/// Manages the WebRTC peer connection lifecycle.
///
/// Responsibilities:
/// - Peer connection creation with ICE servers
/// - Local media stream (audio)
/// - Offer/answer/ICE candidate exchange
/// - Resource cleanup
class WebRTCService {
  RTCPeerConnection? peerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream;

  // ── Callbacks ──
  Function(RTCIceCandidate)? onIceCandidate;
  Function(MediaStream)? onRemoteStream;
  Function(RTCIceConnectionState)? onIceConnectionState;

  /// Fetch TURN/STUN credentials from the signaling server.
  static Future<Map<String, dynamic>> fetchIceConfig() async {
    try {
      final response = await http
          .get(Uri.parse('${AppConfig.serverUrl}/turn-credentials'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      // Fall through to fallback
    }
    return AppConfig.fallbackIceConfig;
  }

  /// Initialize: acquire mic → create peer connection → attach tracks.
  Future<void> initialize(Map<String, dynamic> iceConfig) async {
    localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': false,
    });

    peerConnection = await createPeerConnection(iceConfig);

    for (final track in localStream!.getAudioTracks()) {
      peerConnection!.addTrack(track, localStream!);
    }

    peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        remoteStream = event.streams[0];
        onRemoteStream?.call(remoteStream!);
      }
    };

    peerConnection!.onIceCandidate = (candidate) {
      onIceCandidate?.call(candidate);
    };

    peerConnection!.onIceConnectionState = (state) {
      onIceConnectionState?.call(state);
    };
  }

  /// Create an SDP offer (caller side).
  Future<RTCSessionDescription> createOffer() async {
    final offer = await peerConnection!.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': false,
    });
    await peerConnection!.setLocalDescription(offer);
    return offer;
  }

  /// Create an SDP answer (callee side).
  Future<RTCSessionDescription> createAnswer() async {
    final answer = await peerConnection!.createAnswer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': false,
    });
    await peerConnection!.setLocalDescription(answer);
    return answer;
  }

  Future<void> setRemoteDescription(RTCSessionDescription description) async {
    await peerConnection!.setRemoteDescription(description);
  }

  Future<void> addIceCandidate(RTCIceCandidate candidate) async {
    await peerConnection!.addCandidate(candidate);
  }

  /// Release all WebRTC resources.
  Future<void> dispose() async {
    try {
      localStream?.getTracks().forEach((track) => track.stop());
      await localStream?.dispose();
      localStream = null;
      await peerConnection?.close();
      peerConnection = null;
      remoteStream = null;
    } catch (e) {
      // Swallow — disposal errors are non-critical
    }
  }
}
