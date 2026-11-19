import 'package:uuid/uuid.dart';

const _uuid = Uuid();

enum MessageDelivery { pending, delivered, failed }

class ChatMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final MessageDelivery delivery;

  ChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.delivery = MessageDelivery.delivered,
  });

  factory ChatMessage.user(String content) {
    return ChatMessage(
      id: _uuid.v4(),
      content: content,
      isUser: true,
      delivery: MessageDelivery.pending,
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

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      content: json['content'] as String,
      isUser: json['isUser'] as bool,
      timestamp: DateTime.parse(json['timestamp'] as String),
      delivery: json['delivery'] == 'pending'
          ? MessageDelivery.failed
          : MessageDelivery.values.firstWhere(
              (value) => value.name == json['delivery'],
              orElse: () => MessageDelivery.delivered,
            ),
    );
  }

  ChatMessage withDelivery(MessageDelivery value) => ChatMessage(
    id: id,
    content: content,
    isUser: isUser,
    timestamp: timestamp,
    delivery: value,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'content': content,
    'isUser': isUser,
    'timestamp': timestamp.toIso8601String(),
    'delivery': delivery.name,
  };
}
