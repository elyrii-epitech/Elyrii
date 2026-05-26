import 'package:flutter/material.dart';

/// Challenge template from the backend (source: SYSTEM or AI)
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

  /// Icône déduite du premier type de condition
  IconData get icon {
    final condList = conditions as List?;
    final firstType = condList != null && condList.isNotEmpty
        ? ((condList[0] as Map?)?['type'] as String?) ?? ''
        : '';
    if (firstType.startsWith('mood_streak') ||
        firstType.startsWith('journal_streak')) {
      return Icons.local_fire_department_rounded;
    }
    if (firstType.startsWith('mood')) return Icons.mood_rounded;
    if (firstType.startsWith('journal')) return Icons.menu_book_rounded;
    if (firstType == 'mood_and_journal_same_day') {
      return Icons.self_improvement_rounded;
    }
    return Icons.star_rounded;
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

  String get displayTitle => template?.title ?? 'Défi';
  String get displayDescription => template?.description ?? '';
  IconData get displayIcon => template?.icon ?? Icons.star_rounded;

  bool get isActive => status == 'ACTIVE';
  bool get isCompleted => status == 'COMPLETED';
  bool get isPending => status == 'PENDING';

  /// Fraction de progression globale entre 0.0 et 1.0
  double get progressFraction {
    final p = progress;
    if (p == null || p is! Map) return 0.0;
    final map = p as Map<String, dynamic>;
    if (map.isEmpty) return 0.0;

    double sum = 0;
    int count = 0;
    for (final val in map.values) {
      if (val is Map) {
        final current = (val['current'] as num? ?? 0).toDouble();
        final target = (val['target'] as num? ?? 1).toDouble();
        sum += target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
        count++;
      }
    }
    return count > 0 ? (sum / count).clamp(0.0, 1.0) : 0.0;
  }

  /// Texte de progression lisible, ex: "3 / 7" pour une condition unique
  String get progressText {
    final p = progress;
    if (p == null || p is! Map) return '';
    final map = p as Map<String, dynamic>;
    if (map.length == 1) {
      final val = map.values.first;
      if (val is Map) {
        final current = val['current'] as num? ?? 0;
        final target = val['target'] as num? ?? 1;
        return '$current / $target';
      }
    }
    // Plusieurs conditions : compter combien sont complètes
    final completed =
        map.values.whereType<Map>().where((v) => v['completed'] == true).length;
    return '$completed / ${map.length}';
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
