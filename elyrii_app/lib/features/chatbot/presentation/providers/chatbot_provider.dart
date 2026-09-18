import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../../../core/config/api_config.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../../data/entities/chat_message.dart';
import '../../data/entities/chat_session.dart';
import '../../data/repositories/chat_history_service.dart';

/// Provider managing chatbot state with real WebSocket connection.
///
/// L'historique est local-first : chaque message met à jour la session
/// courante et persiste sur l'appareil, pour retrouver la conversation
/// au redémarrage même sans backend.
class ChatbotProvider extends ChangeNotifier {
  final SecureStorageService _storage;

  /// Messages de la session courante (miroir plat pour la liste).
  final List<ChatMessage> _messages = [];

  /// Toutes les sessions persistées, triées par [ChatSession.updatedAt] desc.
  List<ChatSession> _sessions = [];

  /// Session en cours d'écriture (celle affichée dans `_messages`).
  ChatSession? _activeSession;

  bool _isTyping = false;
  bool _isConnected = false;

  WebSocket? _socket;
  bool _disposed = false;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  List<ChatSession> get conversations => List.unmodifiable(_sessions);
  String? get activeSessionId => _activeSession?.id;
  bool get isTyping => _isTyping;
  bool get isConnected => _isConnected;

  ChatbotProvider({required SecureStorageService storage})
    : _storage = storage {
    _restoreHistory();
  }

  /// Restaure la dernière conversation au démarrage : l'utilisateur
  /// retrouve son fil sans action. Aucune erreur de stockage ne casse
  /// le chat (le fil repart simplement vide).
  Future<void> _restoreHistory() async {
    try {
      _sessions = await ChatHistoryService.loadAll();
      final latest = _sessions.firstOrNull;
      if (latest != null && latest.messages.isNotEmpty) {
        _activeSession = latest;
        _messages.addAll(latest.messages);
      } else {
        _activeSession = latest ?? ChatSession.create();
      }
    } catch (_) {
      _activeSession = ChatSession.create();
    }
    if (!_disposed) notifyListeners();
  }

  /// Connect to the chat WebSocket via the gateway
  Future<void> connect() async {
    if (_isConnected) return;
    final token = await _storage.getAccessToken();
    final userId = await _storage.getUserId();
    if ((token == null || token.isEmpty) &&
        (userId == null || userId.isEmpty)) {
      debugPrint('[ChatbotProvider] No auth token or userId for WebSocket');
      return;
    }
    try {
      final wsUrl = ApiConfig.chatWsUrl(
        userId: token == null || token.isEmpty ? userId : null,
      );
      _socket = await WebSocket.connect(
        wsUrl,
        headers: token != null && token.isNotEmpty
            ? {'Authorization': 'Bearer $token'}
            : null,
      );
      _isConnected = true;
      notifyListeners();
      _socket!.listen(
        (data) {
          _appendMessage(ChatMessage.ai(data.toString()));
          _isTyping = false;
          notifyListeners();
        },
        onError: (Object error) {
          debugPrint('[ChatbotProvider] WebSocket error: $error');
          _isConnected = false;
          _isTyping = false;
          notifyListeners();
        },
        onDone: () {
          debugPrint('[ChatbotProvider] WebSocket closed');
          _isConnected = false;
          _isTyping = false;
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
    _appendMessage(ChatMessage.user(content));
    _isTyping = true;
    notifyListeners();
    if (_socket != null && _isConnected) {
      _socket!.add(content);
    } else {
      await connect();
      if (_socket != null && _isConnected) {
        _socket!.add(content);
      } else {
        _appendMessage(
          ChatMessage.ai(
            'Impossible de se connecter au service. Veuillez réessayer.',
          ),
        );
        _isTyping = false;
        notifyListeners();
      }
    }
  }

  /// Ajoute un message au fil courant, met à jour la session (titre,
  /// horodatage) et persiste l'historique local.
  void _appendMessage(ChatMessage message) {
    _messages.add(message);
    _activeSession ??= ChatSession.create();
    final isFirstUserMessage =
        message.isUser && _activeSession!.title == 'Nouvelle conversation';
    _activeSession = _activeSession!.copyWith(
      title: isFirstUserMessage && message.content.trim().isNotEmpty
          ? _deriveTitle(message.content)
          : null,
      updatedAt: DateTime.now(),
      messages: List.of(_activeSession!.messages)..add(message),
    );
    _upsertSession(_activeSession!);
  }

  /// Titre de conversation : début du premier message utilisateur.
  String _deriveTitle(String content) {
    final clean = content.trim().replaceAll(RegExp(r'\s+'), ' ');
    return clean.length <= 42 ? clean : '${clean.substring(0, 42)}…';
  }

  void _upsertSession(ChatSession session) {
    _sessions
      ..removeWhere((s) => s.id == session.id)
      ..add(session)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    ChatHistoryService.saveAll(_sessions).catchError(
      (Object e) => debugPrint('[ChatbotProvider] history save failed: $e'),
    );
  }

  /// Ouvre une nouvelle conversation vide (l'actuelle est déjà persistée).
  void startNewConversation() {
    _activeSession = ChatSession.create();
    _messages.clear();
    _sessions.insert(0, _activeSession!);
    notifyListeners();
  }

  /// Charge une conversation passée dans le fil courant.
  void loadSession(String sessionId) {
    final session = _sessions.firstWhere(
      (s) => s.id == sessionId,
      orElse: () => _activeSession!,
    );
    if (session.id != sessionId) return;
    _activeSession = session;
    _messages
      ..clear()
      ..addAll(session.messages);
    notifyListeners();
  }

  /// Supprime définitivement une conversation. Si c'était la session
  /// affichée, le fil repart sur une conversation vierge.
  Future<void> deleteSession(String sessionId) async {
    _sessions.removeWhere((s) => s.id == sessionId);
    await ChatHistoryService.saveAll(_sessions);
    if (_activeSession?.id == sessionId) {
      _activeSession = ChatSession.create();
      _messages.clear();
      notifyListeners();
    }
  }

  /// Disconnect from the WebSocket
  Future<void> disconnect() async {
    await _socket?.close();
    _socket = null;
    _isConnected = false;
    notifyListeners();
  }

  /// Efface les messages de la conversation courante (la session reste,
  /// vide, dans l'historique).
  void clearHistory() {
    _messages.clear();
    if (_activeSession != null) {
      _activeSession = _activeSession!.copyWith(
        updatedAt: DateTime.now(),
        messages: const [],
      );
      _upsertSession(_activeSession!);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    disconnect();
    super.dispose();
  }
}
