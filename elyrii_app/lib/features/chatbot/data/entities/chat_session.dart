import 'package:uuid/uuid.dart';

import 'chat_message.dart';

const _uuid = Uuid();

/// Une conversation persistée localement : messages horodatés, titre
/// dérivé du premier message utilisateur, bornes de mise à jour.
class ChatSession {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ChatMessage> messages;
  final int? _messageCount;
  int get messageCount => _messageCount ?? messages.length;

  const ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
    int? messageCount,
  }) : _messageCount = messageCount;

  factory ChatSession.create() {
    final now = DateTime.now();
    return ChatSession(
      id: _uuid.v4(),
      title: 'Nouvelle conversation',
      createdAt: now,
      updatedAt: now,
      messages: const [],
    );
  }

  ChatSession copyWith({
    String? title,
    DateTime? updatedAt,
    List<ChatMessage>? messages,
    int? messageCount,
  }) {
    return ChatSession(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
      messageCount: messageCount ?? _messageCount,
    );
  }

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'] as String,
      messageCount: json['messageCount'] as int?,
      title: json['title'] as String? ?? 'Conversation',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      messages: ((json['messages'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ChatMessage.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'messages': messages.map((m) => m.toJson()).toList(),
  };
}
