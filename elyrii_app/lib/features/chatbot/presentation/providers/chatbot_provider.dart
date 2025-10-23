import 'package:flutter/foundation.dart';
import '../../data/models/chat_message_model.dart';
import '../../data/repositories/chatbot_repository.dart';
import '../../../../core/errors/exceptions.dart';

/// État du chatbot
enum ChatbotState {
  initial,
  loading,
  loaded,
  error,
}

/// Provider pour gérer le chatbot
class ChatbotProvider extends ChangeNotifier {
  final ChatbotRepository _chatbotRepository;

  ChatbotProvider({required ChatbotRepository chatbotRepository})
      : _chatbotRepository = chatbotRepository;

  ChatbotState _state = ChatbotState.initial;
  List<ChatMessage> _messages = [];
  String? _errorMessage;
  bool _isTyping = false;

  ChatbotState get state => _state;
  List<ChatMessage> get messages => _messages;
  String? get errorMessage => _errorMessage;
  bool get isTyping => _isTyping;

  /// Charger l'historique des messages
  Future<void> loadChatHistory() async {
    _setState(ChatbotState.loading);
    
    try {
      _messages = await _chatbotRepository.getChatHistory();
      _setState(ChatbotState.loaded);
    } on AppException catch (e) {
      _errorMessage = e.message;
      _setState(ChatbotState.error);
    } catch (e) {
      _errorMessage = 'Erreur lors du chargement de l\'historique';
      _setState(ChatbotState.error);
    }
  }

  /// Envoyer un message
  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;

    // Ajouter le message de l'utilisateur immédiatement
    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      isUser: true,
      timestamp: DateTime.now(),
    );
    
    _messages.add(userMessage);
    _isTyping = true;
    notifyListeners();

    try {
      // Envoyer au backend et recevoir la réponse
      final aiResponse = await _chatbotRepository.sendMessage(content);
      _messages.add(aiResponse);
      _isTyping = false;
      notifyListeners();
    } on AppException catch (e) {
      _errorMessage = e.message;
      _isTyping = false;
      _setState(ChatbotState.error);
    } catch (e) {
      _errorMessage = 'Erreur lors de l\'envoi du message';
      _isTyping = false;
      _setState(ChatbotState.error);
    }
  }

  /// Analyser l'émotion d'un message
  Future<String?> analyzeEmotion(String message) async {
    try {
      return await _chatbotRepository.analyzeEmotion(message);
    } catch (e) {
      return null;
    }
  }

  /// Supprimer l'historique
  Future<void> clearHistory() async {
    try {
      await _chatbotRepository.clearHistory();
      _messages.clear();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Erreur lors de la suppression de l\'historique';
    }
  }

  void _setState(ChatbotState newState) {
    _state = newState;
    notifyListeners();
  }
}
