import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebRTCService {
  RTCPeerConnection? peerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream;

  Function(RTCIceCandidate)? onIceCandidate;
  Function(MediaStream)? onRemoteStream;

  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ]
  };

  Future<void> initialize() async {
    peerConnection = await createPeerConnection(_configuration);

    // Capture local audio
    localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': false,
    });

    // Add local tracks to the peer connection
    for (var track in localStream!.getTracks()) {
      await peerConnection!.addTrack(track, localStream!);
    }

    // Listen for remote tracks
    peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        remoteStream = event.streams[0];
        if (onRemoteStream != null) onRemoteStream!(remoteStream!);
      }
    };

    // Listen for ICE candidates
    peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (onIceCandidate != null) onIceCandidate!(candidate);
    };

    peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      print('ICE Connection State: $state');
    };
  }

  Future<RTCSessionDescription> createOffer() async {
    RTCSessionDescription offer = await peerConnection!.createOffer();
    await peerConnection!.setLocalDescription(offer);
    return offer;
  }

  Future<RTCSessionDescription> createAnswer() async {
    RTCSessionDescription answer = await peerConnection!.createAnswer();
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
    localStream?.getTracks().forEach((track) => track.stop());
    await localStream?.dispose();
    await peerConnection?.close();
    peerConnection = null;
    localStream = null;
    remoteStream = null;
  }
}
