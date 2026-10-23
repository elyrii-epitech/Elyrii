import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../../core/network/chat/chat_connection.dart';
import '../../../../core/diagnostics/app_diagnostics.dart';

import 'package:flutter/foundation.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../../data/entities/chat_message.dart';
import '../../data/entities/chat_session.dart';
import '../../data/repositories/chat_history_service.dart';

/// Account-scoped, paged chat state. Rendering does not copy collections.
class ChatbotProvider extends ChangeNotifier {
  ChatbotProvider({
    required this._storage,
    ChatHistoryService? history,
    String? initialOwner,
    ChatConnector? connector,
    this._replyTimeout = const Duration(seconds: 60),
  }) : _history = history ?? ChatHistoryService(),
       _ownsHistory = history == null,
       _connector = connector ?? openChatConnection {
    ready = initialOwner == null
        ? synchronizeAccount()
        : _synchronizeAccount(ownerOverride: initialOwner);
  }
  final SecureStorageService _storage;
  final ChatHistoryService _history;
  final bool _ownsHistory;
  final ChatConnector _connector;
  final Duration _replyTimeout;
  Future<bool> _lastMessageWrite = Future.value(true);
  final List<ChatMessage> _messages = [];
  final List<ChatSession> _sessions = [];
  late final List<ChatMessage> _messageView = UnmodifiableListView(_messages);
  late final List<ChatSession> _sessionView = UnmodifiableListView(_sessions);
  final Map<String, _PendingReply> _pendingReplies = {};
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
  ChatConnection? _socket;
  Future<void>? _connecting;
  int _connectionRevision = 0;
  Future<void> _writes = Future.value();
  Future<void> _accountSync = Future.value();
  late Future<void> ready;

  List<ChatMessage> get messages => _messageView;
  List<ChatSession> get conversations => _sessionView;
  String? get activeSessionId => _activeSession?.id;
  bool get isTyping => _pendingReplies.values.any(
    (pending) => pending.session.id == activeSessionId,
  );
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

  Future<void> onUserChanged(String? owner) {
    return ready = _synchronizeAccount(ownerOverride: owner ?? 'local-guest');
  }

  Future<void> _synchronizeAccount({String? ownerOverride}) async {
    final owner = ownerOverride ?? await _storage.getUserId() ?? 'local-guest';
    if (_disposed || owner == _owner) return;
    final generation = ++_generation;
    _selection++;
    _loadingSession = false;
    _owner = owner;
    _messages.clear();
    _sessions.clear();
    _clearPending();
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
      AppDiagnostics.record('chat_history_load_failed', e);
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

  Future<void> connect() {
    if (_connecting != null) return _connecting!;
    late final Future<void> request;
    final revision = ++_connectionRevision;
    request = _connect(revision)
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            if (!_disposed && revision == _connectionRevision) {
              _connectionRevision++;
              _error = 'La connexion au chat a expiré. Réessaie.';
              _notify();
            }
          },
        )
        .whenComplete(() {
          if (identical(_connecting, request)) _connecting = null;
        });
    return _connecting = request;
  }

  Future<void> _connect(int revision) async {
    if (_isConnected || _disposed) return;
    final generation = _generation;
    try {
      final token = await _storage.getAccessToken();
      if (_disposed ||
          generation != _generation ||
          revision != _connectionRevision) {
        return;
      }
      final socket = await _connector(
        Uri.parse(ApiConfig.chatWsUrl()),
        token: token,
      );
      if (_disposed ||
          generation != _generation ||
          revision != _connectionRevision) {
        await socket.close();
        return;
      }
      _socket = socket;
      _isConnected = true;
      _notify();
      socket.frames.listen(
        (data) {
          if (_disposed || generation != _generation || _socket != socket) {
            return;
          }
          Object? frame;
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
            _failAll(
              'Réponse incompatible du service. Réessaie après sa mise à jour.',
            );
            return;
          }
          final requestId = frame['requestId'] as String;
          final pending = _pendingReplies[requestId];
          if (pending == null ||
              pending.session.id != frame['conversationId']) {
            return;
          }
          if (frame['type'] == 'error') {
            _fail(
              requestId,
              'La réponse a échoué. Tu peux réessayer ce message.',
            );
            return;
          }
          _pendingReplies.remove(requestId);
          pending.timer.cancel();
          if (!_deleted.contains(pending.session.id)) {
            _setDelivery(
              pending.message,
              pending.session,
              MessageDelivery.delivered,
            );
            _appendMessage(
              ChatMessage.ai(frame['message'] as String),
              pending.session,
            );
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
    } catch (error) {
      if (!_disposed &&
          generation == _generation &&
          revision == _connectionRevision) {
        _error = error is ChatTransportException
            ? error.message
            : 'Impossible de se connecter au chat. Tu peux réessayer.';
        _isConnected = false;
        _notify();
      }
    }
  }

  void _clearPending() {
    for (final pending in _pendingReplies.values) {
      pending.timer.cancel();
    }
    _pendingReplies.clear();
  }

  void _setDelivery(
    ChatMessage message,
    ChatSession session,
    MessageDelivery delivery,
  ) {
    final index = _messages.indexWhere((value) => value.id == message.id);
    if (index >= 0) _messages[index] = message.withDelivery(delivery);
    final owner = _owner!;
    _queue(() => _history.updateDelivery(owner, message.id, delivery));
  }

  void _fail(String requestId, String reason) {
    final pending = _pendingReplies.remove(requestId);
    if (pending == null) return;
    pending.timer.cancel();
    if (!_deleted.contains(pending.session.id)) {
      _setDelivery(pending.message, pending.session, MessageDelivery.failed);
    }
    _error = reason;
    _notify();
  }

  void _failAll(String reason) {
    for (final id in _pendingReplies.keys.toList()) {
      _fail(id, reason);
    }
    _error = reason;
    _notify();
  }

  void _connectionEnded() {
    _isConnected = false;
    _socket = null;
    _failAll('Connexion interrompue. Tu peux réessayer.');
  }

  /// True means accepted into the local conversation, not answered by the AI.
  /// Delivery state on the bubble distinguishes pending, delivered and failed.
  Future<bool> sendMessage(String content) async {
    if (_loadingSession) return false;
    final generation = _generation;
    await ready;
    if (_disposed ||
        generation != _generation ||
        _loadingSession ||
        content.trim().isEmpty) {
      return false;
    }
    _error = null;
    final message = ChatMessage.user(content.trim());
    final origin = _appendMessage(
      message,
      _activeSession ?? ChatSession.create(),
    );
    final saved = _lastMessageWrite;
    _notify();
    if (!await saved) {
      if (generation == _generation) {
        _messages.removeWhere((value) => value.id == message.id);
        final index = _sessions.indexWhere((value) => value.id == origin.id);
        if (index >= 0) {
          final reverted = _sessions[index].copyWith(
            messageCount: origin.messageCount - 1,
          );
          _sessions[index] = reverted;
          if (activeSessionId == origin.id) _activeSession = reverted;
        }
        _notify();
      }
      return false;
    }
    if (_disposed || generation != _generation) return true;
    await _dispatch(message, origin, message.id, generation);
    return true;
  }

  Future<void> retryMessage(String id) async {
    final message = _messages.where((value) => value.id == id).firstOrNull;
    final session = _activeSession;
    if (message == null ||
        session == null ||
        !message.isUser ||
        message.delivery != MessageDelivery.failed ||
        _loadingSession) {
      return;
    }
    _error = null;
    _setDelivery(message, session, MessageDelivery.pending);
    _notify();
    // A fresh attempt ID rejects any late reply from the timed-out attempt.
    await _dispatch(message, session, const Uuid().v4(), _generation);
  }

  Future<void> _dispatch(
    ChatMessage message,
    ChatSession session,
    String requestId,
    int generation,
  ) async {
    final timer = Timer(_replyTimeout, () {
      if (!_disposed && generation == _generation) {
        _fail(
          requestId,
          'La réponse prend trop de temps. Tu peux réessayer ce message.',
        );
      }
    });
    _pendingReplies[requestId] = _PendingReply(message, session, timer);
    _notify();
    await connect();
    if (_disposed ||
        generation != _generation ||
        !_pendingReplies.containsKey(requestId)) {
      return;
    }
    try {
      if (_socket == null || !_isConnected) {
        _fail(
          requestId,
          _error ?? 'Impossible de se connecter au chat. Réessaie.',
        );
        return;
      }
      _socket!.send(
        jsonEncode({
          'message': message.content,
          'requestId': requestId,
          'conversationId': session.id,
        }),
      );
    } catch (_) {
      _fail(requestId, 'L’envoi a échoué. Tu peux réessayer.');
    }
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
    _lastMessageWrite = _queue(() => _history.append(owner, session, message));
    return session;
  }

  String _deriveTitle(String content) {
    final clean = content.trim().replaceAll(RegExp(r'\s+'), ' ');
    return clean.length <= 42 ? clean : '${clean.substring(0, 42)}…';
  }

  Future<bool> _queue(Future<void> Function() write) {
    final generation = _generation;
    final task = _writes
        .then((_) => write())
        .then(
          (_) => true,
          onError: (Object error) {
            if (!_disposed && generation == _generation) {
              _error = 'La sauvegarde locale a échoué. Garde cette conversation ouverte.';
              AppDiagnostics.record('chat_history_save_failed', error);
              _notify();
            }
            return false;
          },
        );
    _writes = task.then<void>((_) {});
    return task;
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
    for (final id
        in _pendingReplies.entries
            .where((entry) => entry.value.session.id == sessionId)
            .map((entry) => entry.key)
            .toList()) {
      _pendingReplies.remove(id)?.timer.cancel();
    }
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
    _connecting = null;
    _connectionRevision++;
    if (_pendingReplies.isNotEmpty) {
      _failAll('Connexion interrompue. Tu peux réessayer.');
    }
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
    for (final id
        in _pendingReplies.entries
            .where((entry) => entry.value.session.id == session.id)
            .map((entry) => entry.key)
            .toList()) {
      _pendingReplies.remove(id)?.timer.cancel();
    }
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
    _clearPending();
    unawaited(_socket?.close());
    _socket = null;
    if (_ownsHistory) unawaited(_writes.then((_) => _history.close()));
    super.dispose();
  }
}

class _PendingReply {
  const _PendingReply(this.message, this.session, this.timer);
  final ChatMessage message;
  final ChatSession session;
  final Timer timer;
}
