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
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? json['user_id'] as String? ?? '',
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

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

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
      id: json['id'] as String? ?? '',
      entryId: json['entryId'] as String? ?? json['entry_id'] as String? ?? '',
      url: json['url'] as String? ?? '',
      type: json['type'] as String?,
      createdAt: JournalEntryModel._parseDate(
        json['createdAt'] ?? json['created_at'],
      ),
    );
  }
}
