import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/json_response.dart';
import '../entities/chat_message.dart';
import '../entities/chat_session.dart';
import 'chat_history_service.dart';

/// HTTP history with an encrypted, bounded local copy. Transport failures may
/// use that copy; authentication and malformed responses remain errors.
class ConnectedChatHistory extends ChatHistoryService {
  ConnectedChatHistory({required this.client, super.cipher});
  final ApiClient client;
  Future<bool> _connectedOwner(String owner) async =>
      owner == await client.currentUserId &&
      RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(owner);

  @override
  Future<List<ChatSession>> sessions(
    String owner, {
    ChatSession? before,
  }) async {
    final generation = client.sessionGeneration;
    if (!await _connectedOwner(owner)) {
      return super.sessions(owner, before: before);
    }
    try {
      client.ensureSession(generation);
      final page = decodeListResponse(
        await client.get(
          '${ApiConfig.baseUrl}/chat/conversations',
          queryParams: {
            'limit': '${ChatHistoryService.pageSize}',
            if (before != null)
              'beforeDate': before.updatedAt.toUtc().toIso8601String(),
            if (before != null) 'beforeId': before.id,
          },
        ),
        (json) {
          final session = ChatSession.fromJson(json);
          if (json['userId'] != owner ||
              session.id.isEmpty ||
              session.messageCount < 1) {
            throw const FormatException('Invalid conversation');
          }
          return session;
        },
      );
      client.ensureSession(generation);
      await cacheRemoteSessions(owner, page, before: before);
      // Include local-only failed drafts without uploading their private text.
      return await super.sessions(owner, before: before);
    } on ApiException catch (error) {
      if (!error.canUseOfflineData) rethrow;
      return super.sessions(owner, before: before);
    }
  }

  @override
  Future<List<ChatMessage>> messages(
    String owner,
    String sessionId, {
    String? beforeId,
  }) async {
    final generation = client.sessionGeneration;
    if (!await _connectedOwner(owner)) {
      return super.messages(owner, sessionId, beforeId: beforeId);
    }
    try {
      client.ensureSession(generation);
      final page = decodeListResponse(
        await client.get(
          '${ApiConfig.baseUrl}/chat/history',
          queryParams: {
            'conversationId': sessionId,
            'limit': '${ChatHistoryService.pageSize}',
            'beforeId': ?beforeId,
          },
        ),
        (json) {
          if (json['userId'] != owner ||
              json['conversationId'] != sessionId ||
              (json['role'] != 'user' &&
                  json['role'] != 'ai' &&
                  json['role'] != 'system')) {
            throw const FormatException('Chat identity mismatch');
          }
          return ChatMessage(
            id: json['id'] as String,
            content: json['message'] as String,
            isUser: json['role'] == 'user',
            timestamp: DateTime.parse(json['createdAt'] as String),
            delivery: json['role'] == 'user' && json['delivery'] == 'failed'
                ? MessageDelivery.failed
                : MessageDelivery.delivered,
          );
        },
      );
      client.ensureSession(generation);
      await cacheRemoteMessages(
        owner,
        sessionId,
        page,
        older: beforeId != null,
      );
      return await super.messages(owner, sessionId, beforeId: beforeId);
    } on ApiException catch (error) {
      if (!error.canUseOfflineData) rethrow;
      return super.messages(owner, sessionId, beforeId: beforeId);
    }
  }

  @override
  Future<void> delete(String owner, String sessionId) async {
    if (await _connectedOwner(owner)) {
      await client.delete(
        '${ApiConfig.baseUrl}/chat/conversations/${Uri.encodeComponent(sessionId)}',
      );
    }
    await super.delete(owner, sessionId);
  }
}
