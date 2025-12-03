import 'package:flutter/foundation.dart';


class ChatbotProvider extends ChangeNotifier {
  // final List<ChatMessage> _messages = [];
  bool _isMascotMinimized = false;
  bool _isTyping = false;

  // List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isMascotMinimized => _isMascotMinimized;
  bool get isTyping => _isTyping;

  /// Ajoute un message utilisateur et génère une réponse IA (factice pour l'instant)
  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;

    // Ajouter le message utilisateur
    // final userMessage = ChatMessage.user(content);
    // _messages.add(userMessage);
    notifyListeners();

    _isTyping = true;
    notifyListeners();

    await Future.delayed(const Duration(seconds: 1));

    // Ajouter une réponse factice de l'IA
    // final aiResponse = _generateMockResponse(content);
    // _messages.add(ChatMessage.ai(aiResponse));
    _isTyping = false;
    notifyListeners();
  }



  /// Minimise ou agrandit la mascotte
  void toggleMascotSize(bool minimize) {
    _isMascotMinimized = minimize;
    notifyListeners();
  }

  /// Efface l'historique des messages
  void clearHistory() {
    // _messages.clear();
    _isMascotMinimized = false;
    notifyListeners();
  }
}
