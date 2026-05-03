import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'api_service.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  bool _isConnected = false;

  final String wsUrl = ApiService.baseUrl.replaceFirst('http', 'ws') + '/ws';

  void connect(Function(Map<String, dynamic>) onMessage) {
    if (_isConnected) return;

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _isConnected = true;

      _channel!.stream.listen(
        (message) {
          final data = json.decode(message);
          onMessage(data);
        },
        onDone: () {
          _isConnected = false;
          // Reconnect after a delay
          Future.delayed(const Duration(seconds: 5), () => connect(onMessage));
        },
        onError: (error) {
          _isConnected = false;
        },
      );
    } catch (e) {
      _isConnected = false;
    }
  }

  void disconnect() {
    _channel?.sink.close(status.goingAway);
    _isConnected = false;
  }
}
