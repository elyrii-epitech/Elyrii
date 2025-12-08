import 'package:flutter/foundation.dart';
import '../../data/entities/chat_message.dart';
import '../../data/mock_responses.dart';

class ChatbotProvider extends ChangeNotifier {
  final List<ChatMessage> _messages = [];
  bool _isMascotMinimized = false;
  bool _isTyping = false;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isMascotMinimized => _isMascotMinimized;
  bool get isTyping => _isTyping;

  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;

    final userMessage = ChatMessage.user(content);
    _messages.add(userMessage);
    notifyListeners();

    _isTyping = true;
    notifyListeners();

    await Future.delayed(const Duration(seconds: 1));

    final aiResponse = _generateMockResponse(content);
    _messages.add(ChatMessage.ai(aiResponse));
    _isTyping = false;
    notifyListeners();
  }

  String _generateMockResponse(String userMessage) {
    return mockChatbotResponses[
        userMessage.length % mockChatbotResponses.length];
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
}
