import '../../../../core/data/json_contract.dart';

/// Journal entry model matching the backend journal_entries table
class JournalEntryModel {
  final String id;
  final String userId;
  final String title;
  final String? content;
  final String? mood;
  final DateTime createdAt;
  final DateTime updatedAt;

  const JournalEntryModel({
    required this.id,
    required this.userId,
    required this.title,
    this.content,
    this.mood,
    required this.createdAt,
    required this.updatedAt,
  });

  factory JournalEntryModel.fromJson(Map<String, dynamic> json) {
    return JournalEntryModel(
      id: requiredJsonString(json['id'], 'id'),
      userId: requiredJsonString(json['userId'] ?? json['user_id'], 'userId'),
      title: json['title'] as String? ?? '',
      content: json['content'] as String?,
      mood: json['mood'] as String?,
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: _parseDate(json['updatedAt'] ?? json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'content': content,
    'mood': mood,
  };

  Map<String, dynamic> toCacheJson() => {
    'id': id,
    'userId': userId,
    'title': title,
    'content': content,
    'mood': mood,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  static DateTime _parseDate(dynamic value) =>
      requiredJsonDate(value, 'journal date');

  JournalEntryModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? content,
    String? mood,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return JournalEntryModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      content: content ?? this.content,
      mood: mood ?? this.mood,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class JournalMediaModel {
  final String id;
  final String entryId;
  final String url;
  final String? type;
  final DateTime createdAt;

  const JournalMediaModel({
    required this.id,
    required this.entryId,
    required this.url,
    this.type,
    required this.createdAt,
  });

  factory JournalMediaModel.fromJson(Map<String, dynamic> json) {
    return JournalMediaModel(
      id: requiredJsonString(json['id'], 'id'),
      entryId: requiredJsonString(
        json['entryId'] ?? json['entry_id'],
        'entryId',
      ),
      url: requiredJsonString(json['url'], 'url'),
      type: json['type'] as String?,
      createdAt: JournalEntryModel._parseDate(
        json['createdAt'] ?? json['created_at'],
      ),
    );
  }
}
