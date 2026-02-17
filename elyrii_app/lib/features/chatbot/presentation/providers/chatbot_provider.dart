import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../../core/config/api_config.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../../data/entities/chat_message.dart';

/// Provider managing chatbot state with real WebSocket connection
class ChatbotProvider extends ChangeNotifier {
  final SecureStorageService _storage;

  final List<ChatMessage> _messages = [];
  bool _isMascotMinimized = false;
  bool _isTyping = false;
  bool _isConnected = false;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isMascotMinimized => _isMascotMinimized;
  bool get isTyping => _isTyping;
  bool get isConnected => _isConnected;

  ChatbotProvider({required SecureStorageService storage}) : _storage = storage;

  /// Connect to the chat WebSocket via the gateway
  Future<void> connect() async {
    if (_isConnected) return;
    final userId = await _storage.getUserId();
    if (userId == null || userId.isEmpty) {
      debugPrint('[ChatbotProvider] No userId, cannot connect to WebSocket');
      return;
    }
    try {
      final wsUrl = ApiConfig.chatWsUrl(userId);
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _isConnected = true;
      notifyListeners();
      _subscription = _channel!.stream.listen(
        (data) {
          final aiResponse = data.toString();
          _messages.add(ChatMessage.ai(aiResponse));
          _isTyping = false;
          notifyListeners();
        },
        onError: (error) {
          debugPrint('[ChatbotProvider] WebSocket error: $error');
          _isConnected = false;
          _isTyping = false;
          notifyListeners();
        },
        onDone: () {
          debugPrint('[ChatbotProvider] WebSocket closed');
          _isConnected = false;
          notifyListeners();
        },
      );
    } catch (e) {
      debugPrint('[ChatbotProvider] Failed to connect: $e');
      _isConnected = false;
      notifyListeners();
    }
  }

  /// Send a message through the WebSocket
  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;
    final userMessage = ChatMessage.user(content);
    _messages.add(userMessage);
    _isTyping = true;
    notifyListeners();
    if (_channel != null && _isConnected) {
      _channel!.sink.add(content);
    } else {
      // Attempt reconnect and retry
      await connect();
      if (_channel != null && _isConnected) {
        _channel!.sink.add(content);
      } else {
        _messages.add(ChatMessage.ai(
          'Impossible de se connecter au service. Veuillez réessayer.',
        ));
        _isTyping = false;
        notifyListeners();
      }
    }
  }

  /// Disconnect from the WebSocket
  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    notifyListeners();
  }

  void toggleMascotSize(bool minimize) {
    if (!_isMascotMinimized || minimize) {
      _isMascotMinimized = minimize;
      notifyListeners();
    }
  }

  void resetMascot() {
    _isMascotMinimized = false;
    notifyListeners();
  }

  void clearHistory() {
    _messages.clear();
    _isMascotMinimized = false;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
