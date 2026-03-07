import 'package:socket_io_client/socket_io_client.dart' as IO;

class SignalingService {
  late IO.Socket socket;

  Function(dynamic)? onIncomingCall;
  Function(dynamic)? onCallAnswered;
  Function(dynamic)? onIceCandidate;
  Function(dynamic)? onCallRejected;
  Function(dynamic)? onCallEnded;

  void connect(String serverUrl, String userId) {
    socket = IO.io(
      serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    socket.connect();

    socket.onConnect((_) {
      print('Connected to signaling server');
      socket.emit('register', userId);
    });

    socket.on('incoming-call', (data) {
      if (onIncomingCall != null) onIncomingCall!(data);
    });

    socket.on('call-answered', (data) {
      if (onCallAnswered != null) onCallAnswered!(data);
    });

    socket.on('ice-candidate', (data) {
      if (onIceCandidate != null) onIceCandidate!(data);
    });

    socket.on('call-rejected', (data) {
      if (onCallRejected != null) onCallRejected!(data);
    });

    socket.on('call-ended', (data) {
      if (onCallEnded != null) onCallEnded!(data);
    });

    socket.onDisconnect((_) {
      print('Disconnected from signaling server');
    });
  }

  void callUser(Map<String, dynamic> data) {
    socket.emit('call-user', data);
  }

  void answerCall(Map<String, dynamic> data) {
    socket.emit('answer-call', data);
  }

  void sendIceCandidate(Map<String, dynamic> data) {
    socket.emit('ice-candidate', data);
  }

  void rejectCall(Map<String, dynamic> data) {
    socket.emit('reject-call', data);
  }

  void endCall(Map<String, dynamic> data) {
    socket.emit('end-call', data);
  }

  void disconnect() {
    socket.disconnect();
  }
}
