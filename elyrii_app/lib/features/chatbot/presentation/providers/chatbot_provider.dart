import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../../../core/config/api_config.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../../data/entities/chat_message.dart';
import '../../data/entities/chat_session.dart';
import '../../data/repositories/chat_history_service.dart';

/// Account-scoped, paged chat state. Rendering does not copy collections.
class ChatbotProvider extends ChangeNotifier {
  ChatbotProvider({
    required SecureStorageService storage,
    ChatHistoryService? history,
  }) : _storage = storage,
       _history = history ?? ChatHistoryService(),
       _ownsHistory = history == null {
    ready = synchronizeAccount();
  }
  final SecureStorageService _storage;
  final ChatHistoryService _history;
  final bool _ownsHistory;
  final List<ChatMessage> _messages = [];
  final List<ChatSession> _sessions = [];
  late final List<ChatMessage> _messageView = UnmodifiableListView(_messages);
  late final List<ChatSession> _sessionView = UnmodifiableListView(_sessions);
  final Map<String, ChatSession> _pendingReplies = {};
  final Set<String> _deleted = {};
  ChatSession? _activeSession;
  String? _owner;
  int _generation = 0;
  int _selection = 0;
  ChatSession? _sessionCursor;
  bool _disposed = false;
  bool _isConnected = false;
  bool _loadingOlder = false;
  bool _loadingSessions = false;
  bool _loadingSession = false;
  bool _hasMoreMessages = false;
  bool _hasMoreSessions = false;
  bool _hasLegacyHistory = false;
  String? _error;
  WebSocket? _socket;
  Future<void>? _connecting;
  Future<void> _writes = Future.value();
  Future<void> _accountSync = Future.value();
  late Future<void> ready;

  List<ChatMessage> get messages => _messageView;
  List<ChatSession> get conversations => _sessionView;
  String? get activeSessionId => _activeSession?.id;
  bool get isTyping =>
      _pendingReplies.values.any((s) => s.id == activeSessionId);
  bool get loadingSession => _loadingSession;
  bool get isConnected => _isConnected;
  bool get hasMoreMessages => _hasMoreMessages;
  bool get hasMoreSessions => _hasMoreSessions;
  bool get loadingOlder => _loadingOlder;
  bool get hasLegacyHistory => _hasLegacyHistory;
  String? get error => _error;
  Future<void> get flushed => _writes;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> synchronizeAccount() =>
      ready = _accountSync = _accountSync.then((_) => _synchronizeAccount());

  Future<void> _synchronizeAccount() async {
    final owner = await _storage.getUserId() ?? 'local-guest';
    if (_disposed || owner == _owner) return;
    final generation = ++_generation;
    _selection++;
    _loadingSession = false;
    _owner = owner;
    _messages.clear();
    _sessions.clear();
    _pendingReplies.clear();
    _deleted.clear();
    _activeSession = ChatSession.create();
    _hasMoreMessages = false;
    _hasMoreSessions = false;
    _sessionCursor = null;
    _error = null;
    await disconnect();
    try {
      await _writes;
      final sessions = await _history.sessions(owner);
      final legacy = await _history.hasLegacyHistory();
      if (_disposed || generation != _generation) return;
      _sessions.addAll(sessions);
      _sessionCursor = sessions.lastOrNull;
      _hasMoreSessions = sessions.length == ChatHistoryService.pageSize;
      _hasLegacyHistory = legacy;
      if (sessions.isNotEmpty) await _selectSession(sessions.first);
    } catch (e) {
      if (generation == _generation) {
        _error = 'Impossible de charger l’historique local.';
      }
      debugPrint('[ChatbotProvider] history load failed: $e');
    }
    _notify();
  }

  Future<void> loadMoreSessions() async {
    await ready;
    if (_loadingSessions || !_hasMoreSessions) return;
    _loadingSessions = true;
    final generation = _generation;
    try {
      await _writes;
      final page = await _history.sessions(_owner!, before: _sessionCursor);
      if (_disposed || generation != _generation) return;
      if (page.isNotEmpty) _sessionCursor = page.last;
      final ids = _sessions.map((s) => s.id).toSet();
      _sessions.addAll(page.where((s) => !ids.contains(s.id)));
      _hasMoreSessions = page.length == ChatHistoryService.pageSize;
    } catch (_) {
      _error = 'Impossible de charger les conversations.';
    } finally {
      _loadingSessions = false;
      _notify();
    }
  }

  Future<void> _selectSession(ChatSession session) async {
    final selection = ++_selection;
    final generation = _generation;
    final owner = _owner!;
    _loadingSession = true;
    _notify();
    try {
      List<ChatMessage> page;
      // A reply may land during the database read. Re-read after that write
      // instead of replacing a newer in-memory message with an older snapshot.
      while (true) {
        final writes = _writes;
        await writes;
        page = await _history.messages(owner, session.id);
        if (_disposed || selection != _selection || generation != _generation) {
          return;
        }
        if (identical(writes, _writes)) break;
      }
      _activeSession =
          _sessions.where((s) => s.id == session.id).firstOrNull ?? session;
      _messages
        ..clear()
        ..addAll(page);
      _hasMoreMessages = page.length < _activeSession!.messageCount;
    } finally {
      if (selection == _selection && generation == _generation) {
        _loadingSession = false;
        _notify();
      }
    }
  }

  Future<bool> loadSession(String sessionId) async {
    await ready;
    final session = _sessions.where((s) => s.id == sessionId).firstOrNull;
    if (session == null) return false;
    try {
      await _selectSession(session);
      return !_disposed && !_loadingSession && activeSessionId == sessionId;
    } catch (_) {
      _error = 'Impossible de charger cette conversation.';
      _notify();
      return false;
    }
  }

  Future<void> loadOlderMessages() async {
    if (_loadingOlder || !_hasMoreMessages || _messages.isEmpty) return;
    _loadingOlder = true;
    _notify();
    final selection = _selection;
    final generation = _generation;
    try {
      final page = await _history.messages(
        _owner!,
        _activeSession!.id,
        beforeId: _messages.first.id,
      );
      if (_disposed || generation != _generation || selection != _selection) {
        return;
      }
      _messages.insertAll(0, page);
      _hasMoreMessages =
          page.length == ChatHistoryService.pageSize &&
          _messages.length < _activeSession!.messageCount;
    } catch (_) {
      _error = 'Impossible de charger les messages précédents.';
    } finally {
      _loadingOlder = false;
      _notify();
    }
  }

  Future<void> connect() =>
      _connecting ??= _connect().whenComplete(() => _connecting = null);

  Future<void> _connect() async {
    if (_isConnected || _disposed) return;
    final generation = _generation;
    final token = await _storage.getAccessToken();
    final userId = await _storage.getUserId();
    if (_disposed || generation != _generation) return;
    if ((token == null || token.isEmpty) &&
        (userId == null || userId.isEmpty)) {
      return;
    }
    try {
      final socket = await WebSocket.connect(
        ApiConfig.chatWsUrl(
          userId: token == null || token.isEmpty ? userId : null,
        ),
        headers: token != null && token.isNotEmpty
            ? {'Authorization': 'Bearer $token'}
            : null,
      ).timeout(const Duration(seconds: 15));
      if (_disposed || generation != _generation) {
        await socket.close();
        return;
      }
      _socket = socket;
      _isConnected = true;
      _notify();
      socket.listen(
        (data) {
          if (_disposed || generation != _generation || _socket != socket) {
            return;
          }
          // Plain-text or uncorrelated frames must never consume a request:
          // the server can finish requests out of order or send late replies.
          dynamic frame;
          try {
            frame = jsonDecode(data.toString());
          } catch (_) {
            frame = null;
          }
          if (frame is! Map ||
              (frame['type'] != 'reply' && frame['type'] != 'error') ||
              frame['requestId'] is! String ||
              frame['conversationId'] is! String ||
              frame['message'] is! String) {
            _error =
                'Réponse incompatible du service. Réessaie après sa mise à jour.';
            _pendingReplies.clear();
            _notify();
            return;
          }
          final requestId = frame['requestId'] as String;
          final origin = _pendingReplies[requestId];
          if (origin == null || origin.id != frame['conversationId']) return;
          _pendingReplies.remove(requestId);
          if (!_deleted.contains(origin.id)) {
            _appendMessage(ChatMessage.ai(frame['message'] as String), origin);
          }
          _notify();
        },
        onError: (Object error) {
          if (_socket == socket) _connectionEnded();
        },
        onDone: () {
          if (_socket == socket) _connectionEnded();
        },
      );
    } catch (_) {
      if (generation == _generation) {
        _isConnected = false;
        _notify();
      }
    }
  }

  void _connectionEnded() {
    _isConnected = false;
    _socket = null;
    if (_pendingReplies.isNotEmpty) {
      _error = 'Connexion interrompue. Tu peux réessayer.';
    }
    _pendingReplies.clear();
    _notify();
  }

  Future<bool> sendMessage(String content) async {
    if (_loadingSession) return false;
    await ready;
    if (_disposed || _loadingSession || content.trim().isEmpty) return false;
    final generation = _generation;
    final message = ChatMessage.user(content.trim());
    final origin = _appendMessage(
      message,
      _activeSession ?? ChatSession.create(),
    );
    _pendingReplies[message.id] = origin;
    _notify();
    await connect();
    if (_disposed || generation != _generation) return true;
    if (_socket != null && _isConnected) {
      _socket!.add(
        jsonEncode({
          'message': message.content,
          'requestId': message.id,
          'conversationId': origin.id,
        }),
      );
    } else {
      _pendingReplies.remove(message.id);
      if (!_deleted.contains(origin.id)) {
        _appendMessage(
          ChatMessage.ai(
            'Impossible de se connecter au service. Veuillez réessayer.',
          ),
          origin,
        );
      }
      _notify();
    }
    return true;
  }

  ChatSession _appendMessage(ChatMessage message, ChatSession origin) {
    final current =
        _sessions.where((s) => s.id == origin.id).firstOrNull ?? origin;
    final active = _activeSession == null || _activeSession!.id == origin.id;
    if (active) _messages.add(message);
    final session = current.copyWith(
      title: message.isUser && current.title == 'Nouvelle conversation'
          ? _deriveTitle(message.content)
          : null,
      updatedAt: DateTime.now(),
      messageCount: current.messageCount + 1,
      messages: const [],
    );
    if (active) _activeSession = session;
    _sessions.removeWhere((s) => s.id == session.id);
    _sessions.insert(0, session);
    final owner = _owner!;
    _queue(() => _history.append(owner, session, message));
    return session;
  }

  String _deriveTitle(String content) {
    final clean = content.trim().replaceAll(RegExp(r'\s+'), ' ');
    return clean.length <= 42 ? clean : '${clean.substring(0, 42)}…';
  }

  void _queue(Future<void> Function() write) {
    _writes = _writes.then((_) => write()).catchError((Object e) {
      _error =
          'La sauvegarde locale a échoué. Garde cette conversation ouverte.';
      debugPrint('[ChatbotProvider] history save failed: $e');
      _notify();
    });
  }

  Future<void> startNewConversation() async {
    await ready;
    if (_disposed) return;
    _selection++;
    _loadingSession = false;
    _activeSession = ChatSession.create();
    _messages.clear();
    _hasMoreMessages = false;
    _notify();
  }

  Future<void> deleteSession(String sessionId) async {
    await ready;
    final owner = _owner!;
    final generation = _generation;
    // Block late socket replies before waiting for the database. Otherwise a
    // queued append could recreate the session immediately after deletion.
    _deleted.add(sessionId);
    _selection++;
    _loadingSession = false;
    await _writes;
    try {
      await _history.delete(owner, sessionId);
      if (_disposed || generation != _generation) return;
      _sessions.removeWhere((s) => s.id == sessionId);
      if (_activeSession?.id == sessionId) await startNewConversation();
    } catch (_) {
      if (generation == _generation) {
        _deleted.remove(sessionId);
        _error = 'La suppression a échoué. Réessaie.';
      }
    }
    _notify();
  }

  Future<void> importLegacyHistory() async {
    await ready;
    final owner = _owner!;
    final generation = _generation;
    try {
      await _writes;
      await _history.importLegacy(owner);
      final sessions = await _history.sessions(owner);
      if (_disposed || generation != _generation) return;
      _sessions
        ..clear()
        ..addAll(sessions);
      _sessionCursor = sessions.lastOrNull;
      _hasMoreSessions = sessions.length == ChatHistoryService.pageSize;
      _hasLegacyHistory = false;
      _error = null;
    } catch (_) {
      _error = 'Import impossible. L’ancien historique a été conservé.';
    }
    _notify();
  }

  Future<void> disconnect() async {
    final socket = _socket;
    _socket = null;
    _isConnected = false;
    _pendingReplies.clear();
    if (socket != null) unawaited(socket.close());
    _notify();
  }

  Future<void> clearHistory() async {
    await ready;
    final session = _activeSession;
    if (session == null) return;
    final owner = _owner!;
    _selection++;
    _loadingSession = false;
    _messages.clear();
    _hasMoreMessages = false;
    _activeSession = session.copyWith(
      messages: const [],
      messageCount: 0,
      updatedAt: DateTime.now(),
    );
    final index = _sessions.indexWhere((s) => s.id == session.id);
    if (index >= 0) _sessions[index] = _activeSession!;
    final empty = _activeSession!;
    _queue(() => _history.clearMessages(owner, empty));
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    unawaited(_socket?.close());
    _socket = null;
    if (_ownsHistory) unawaited(_writes.then((_) => _history.close()));
    super.dispose();
  }
}
