import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class ChatMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
  });

  factory ChatMessage.user(String content) {
    return ChatMessage(
      id: _uuid.v4(),
      content: content,
      isUser: true,
      timestamp: DateTime.now(),
    );
  }

  factory ChatMessage.ai(String content) {
    return ChatMessage(
      id: _uuid.v4(),
      content: content,
      isUser: false,
      timestamp: DateTime.now(),
    );
  }
}
