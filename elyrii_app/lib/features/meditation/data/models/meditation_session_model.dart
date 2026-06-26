class MeditationProgram {
  final String id;
  final String title;
  final String description;
  final int durationMinutes;
  final String audioUrl;
  final List<String> tags;

  const MeditationProgram({
    required this.id,
    required this.title,
    required this.description,
    required this.durationMinutes,
    required this.audioUrl,
    required this.tags,
  });

  factory MeditationProgram.fromJson(Map<String, dynamic> json) {
    return MeditationProgram(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      durationMinutes: _parseInt(json['durationMinutes'] ?? json['duration_minutes']),
      audioUrl: json['audioUrl'] as String? ?? json['audio_url'] as String? ?? '',
      tags: (json['tags'] as List<dynamic>?)
              ?.map((tag) => tag.toString())
              .toList() ??
          const [],
    );
  }
}

class MeditationSessionModel {
  final String id;
  final String type;
  final int durationMinutes;
  final String status;
  final String? notes;
  final String? moodBefore;
  final String? moodAfter;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final DateTime createdAt;

  const MeditationSessionModel({
    required this.id,
    required this.type,
    required this.durationMinutes,
    required this.status,
    this.notes,
    this.moodBefore,
    this.moodAfter,
    this.startedAt,
    this.endedAt,
    required this.createdAt,
  });

  factory MeditationSessionModel.fromJson(Map<String, dynamic> json) {
    return MeditationSessionModel(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      durationMinutes: _parseInt(json['durationMinutes'] ?? json['duration_minutes']),
      status: json['status'] as String? ?? 'STARTED',
      notes: json['notes'] as String?,
      moodBefore: json['moodBefore'] as String? ?? json['mood_before'] as String?,
      moodAfter: json['moodAfter'] as String? ?? json['mood_after'] as String?,
      startedAt: _parseDate(json['startedAt'] ?? json['started_at']),
      endedAt: _parseDate(json['endedAt'] ?? json['ended_at']),
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']) ??
          DateTime.now(),
    );
  }
}

int _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
