import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;

class WebRTCService {
  RTCPeerConnection? peerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream;

  Function(RTCIceCandidate)? onIceCandidate;
  Function(MediaStream)? onRemoteStream;
  Function(RTCIceConnectionState)? onIceConnectionState;

  // Fallback ICE config (STUN only)
  static final Map<String, dynamic> _fallbackConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ],
  };

  /// Fetch TURN credentials from the signaling server
  static Future<Map<String, dynamic>> fetchIceConfig(String serverUrl) async {
    try {
      final response = await http
          .get(Uri.parse('$serverUrl/turn-credentials'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Fetched TURN credentials: ${data['iceServers'].length} servers');
        return data;
      }
    } catch (e) {
      print('Failed to fetch TURN credentials: $e');
    }
    return _fallbackConfig;
  }

  Future<void> initialize(Map<String, dynamic> iceConfig) async {
    // Step 1: Get local audio stream
    localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': false,
    });

    // Step 2: Create peer connection with TURN servers
    peerConnection = await createPeerConnection(iceConfig);

    // Step 3: Add local audio tracks
    localStream!.getAudioTracks().forEach((track) {
      peerConnection!.addTrack(track, localStream!);
    });

    // Step 4: Set up callbacks
    peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        remoteStream = event.streams[0];
        onRemoteStream?.call(remoteStream!);
      }
    };

    peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      onIceCandidate?.call(candidate);
    };

    peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      print('ICE Connection State: $state');
      onIceConnectionState?.call(state);
    };
  }

  Future<RTCSessionDescription> createOffer() async {
    final offer = await peerConnection!.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': false,
    });
    await peerConnection!.setLocalDescription(offer);
    return offer;
  }

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

  Future<void> dispose() async {
    try {
      localStream?.getTracks().forEach((track) => track.stop());
      await localStream?.dispose();
      localStream = null;
      await peerConnection?.close();
      peerConnection = null;
      remoteStream = null;
    } catch (e) {
      print('WebRTC dispose error: $e');
    }
  }
}
