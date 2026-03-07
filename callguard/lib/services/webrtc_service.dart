import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebRTCService {
  RTCPeerConnection? peerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream;

  Function(RTCIceCandidate)? onIceCandidate;
  Function(MediaStream)? onRemoteStream;

  Future<void> initialize() async {
    // Step 1: Get local audio stream
    localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': false,
    });

    // Step 2: Create peer connection with minimal config
    // Using only a single STUN server to minimize network thread work
    peerConnection = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
    });

    // Step 3: Add local audio tracks to the peer connection
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
