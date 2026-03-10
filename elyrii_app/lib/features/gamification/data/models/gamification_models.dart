/// Challenge template from the backend
class ChallengeTemplate {
  final String id;
  final String title;
  final String? description;
  final String source;
  final dynamic conditions;
  final String aggregator;
  final dynamic constraints;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChallengeTemplate({
    required this.id,
    required this.title,
    this.description,
    required this.source,
    this.conditions,
    required this.aggregator,
    this.constraints,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChallengeTemplate.fromJson(Map<String, dynamic> json) {
    return ChallengeTemplate(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      source: json['source'] as String? ?? 'SYSTEM',
      conditions: json['conditions'],
      aggregator: json['aggregator'] as String? ?? 'ALL',
      constraints: json['constraints'],
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: _parseDate(json['updatedAt'] ?? json['updated_at']),
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}

/// User-assigned challenge with status and progress
class UserChallenge {
  final String id;
  final String userId;
  final String challengeId;
  final String status;
  final dynamic progress;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  // Joined template data (when returned by backend)
  final ChallengeTemplate? template;

  const UserChallenge({
    required this.id,
    required this.userId,
    required this.challengeId,
    required this.status,
    this.progress,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    this.template,
  });

  factory UserChallenge.fromJson(Map<String, dynamic> json) {
    // The backend may return nested challenge data or flat data
    ChallengeTemplate? tpl;
    if (json['challenge'] is Map<String, dynamic>) {
      tpl = ChallengeTemplate.fromJson(
        json['challenge'] as Map<String, dynamic>,
      );
    }
    return UserChallenge(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? json['user_id'] as String? ?? '',
      challengeId: json['challengeId'] as String? ??
          json['challenge_id'] as String? ??
          '',
      status: json['status'] as String? ?? 'PENDING',
      progress: json['progress'],
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: _parseDate(json['updatedAt'] ?? json['updated_at']),
      completedAt: json['completedAt'] != null || json['completed_at'] != null
          ? _parseDate(json['completedAt'] ?? json['completed_at'])
          : null,
      template: tpl,
    );
  }

  /// Display title from template or fallback
  String get displayTitle => template?.title ?? 'Challenge $challengeId';
  String get displayDescription => template?.description ?? '';

  bool get isActive => status == 'ACTIVE';
  bool get isCompleted => status == 'COMPLETED';
  bool get isPending => status == 'PENDING';

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
