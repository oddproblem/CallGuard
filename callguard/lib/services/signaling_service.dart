import 'package:socket_io_client/socket_io_client.dart' as IO;

class SignalingService {
  late IO.Socket socket;
  bool isConnected = false;

  Function(dynamic)? onIncomingCall;
  Function(dynamic)? onCallAnswered;
  Function(dynamic)? onIceCandidate;
  Function(dynamic)? onCallRejected;
  Function(dynamic)? onCallEnded;
  Function(dynamic)? onUserOffline;
  Function()? onConnected;
  Function()? onDisconnected;

  void connect(String serverUrl, String userId) {
    socket = IO.io(
      serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setReconnectionAttempts(10)
          .build(),
    );

    socket.connect();

    socket.onConnect((_) {
      print('Connected to signaling server');
      isConnected = true;
      socket.emit('register', userId);
      onConnected?.call();
    });

    socket.on('incoming-call', (data) {
      onIncomingCall?.call(data);
    });

    socket.on('call-answered', (data) {
      onCallAnswered?.call(data);
    });

    socket.on('ice-candidate', (data) {
      onIceCandidate?.call(data);
    });

    socket.on('call-rejected', (data) {
      onCallRejected?.call(data);
    });

    socket.on('call-ended', (data) {
      onCallEnded?.call(data);
    });

    socket.on('user-offline', (data) {
      onUserOffline?.call(data);
    });

    socket.onDisconnect((_) {
      print('Disconnected from signaling server');
      isConnected = false;
      onDisconnected?.call();
    });

    socket.onReconnect((_) {
      print('Reconnected to signaling server');
      isConnected = true;
      socket.emit('register', userId);
      onConnected?.call();
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
