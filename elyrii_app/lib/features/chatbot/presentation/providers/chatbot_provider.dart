import 'package:flutter/foundation.dart';
import '../../data/entities/chat_message.dart';

class ChatbotProvider extends ChangeNotifier {
  final List<ChatMessage> _messages = [];
  List<ChatMessage>? _cachedUnmodifiableMessages;
  bool _isMascotMinimized = false;
  bool _isTyping = false;

  List<ChatMessage> get messages {
    _cachedUnmodifiableMessages ??= List.unmodifiable(_messages);
    return _cachedUnmodifiableMessages!;
  }

  bool get isMascotMinimized => _isMascotMinimized;
  bool get isTyping => _isTyping;

  /// Ajoute un message utilisateur et génère une réponse IA (factice pour l'instant)
  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;

    final userMessage = ChatMessage.user(content);
    _messages.add(userMessage);
    _cachedUnmodifiableMessages = null;
    notifyListeners();

    _isTyping = true;
    notifyListeners();

    await Future.delayed(const Duration(seconds: 1));

    final aiResponse = _generateMockResponse(content);
    _messages.add(ChatMessage.ai(aiResponse));
    _cachedUnmodifiableMessages = null;
    _isTyping = false;
    notifyListeners();
  }

  /// Génère une réponse factice de l'IA
  String _generateMockResponse(String userMessage) {
    final responses = [
      "Je comprends ce que tu ressens. Tes émotions sont valides et importantes. 💜",
      "C'est courageux de ta part de partager cela. Je suis là, à ton écoute, sans jugement.",
      "Merci de me faire confiance. Tu n'es pas seul(e), nous allons avancer ensemble, à ton rythme.",
      "Tes sentiments comptent vraiment. Prends tout le temps dont tu as besoin pour t'exprimer.",
      "Je suis là pour toi, aujourd'hui et chaque jour. Tu peux tout me dire, je t'écoute avec bienveillance.",
      "C'est un pas important que tu fais en te confiant. Je suis fier(e) de toi. ✨",
      "Tu traverses quelque chose de difficile, et c'est normal de le ressentir. Je reste à tes côtés.",
    ];

    return responses[userMessage.length % responses.length];
  }

  /// Minimise ou agrandit la mascotte
  void toggleMascotSize(bool minimize) {
    _isMascotMinimized = minimize;
    notifyListeners();
  }

  /// Efface l'historique des messages
  void clearHistory() {
    _messages.clear();
    _cachedUnmodifiableMessages = null;
    _isMascotMinimized = false;
    notifyListeners();
  }
}
