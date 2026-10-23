import '../../../../core/data/json_contract.dart';

import 'package:flutter/material.dart';

/// Challenge template from the backend (source: SYSTEM or AI)
class ChallengeTemplate {
  final String id;
  final String title;
  final String? description;
  final String source;
  final int rewardPoints;
  final Object? conditions;
  final String aggregator;
  final Object? constraints;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChallengeTemplate({
    required this.id,
    required this.title,
    this.description,
    required this.source,
    required this.rewardPoints,
    Object? conditions,
    required this.aggregator,
    Object? constraints,
    required this.createdAt,
    required this.updatedAt,
  }) : conditions = freezeJson(conditions),
       constraints = freezeJson(constraints);

  factory ChallengeTemplate.fromJson(Map<String, dynamic> json) {
    return ChallengeTemplate(
      id: requiredJsonString(json['id'], 'id'),
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      source: json['source'] as String? ?? 'SYSTEM',
      rewardPoints: _parseInt(json['rewardPoints'] ?? json['reward_points']),
      conditions: json['conditions'],
      aggregator: json['aggregator'] as String? ?? 'ALL',
      constraints: json['constraints'],
      createdAt: requiredJsonDate(
        json['createdAt'] ?? json['created_at'],
        'createdAt',
      ),
      updatedAt: requiredJsonDate(
        json['updatedAt'] ?? json['updated_at'],
        'updatedAt',
      ),
    );
  }

  /// Icône déduite du premier type de condition
  IconData get icon {
    final firstType = switch (conditions) {
      [{'type': final String type}, ...] => type,
      _ => '',
    };
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

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 50;
    return 50;
  }
}

/// User-assigned challenge with status and progress
enum ChallengeStatus { pending, active, completed, rejected, unknown }

class UserChallenge {
  final String id;
  final String userId;
  final String challengeId;
  final String status;
  final Object? progress;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  // Joined template data (when returned by backend)
  final ChallengeTemplate? template;

  UserChallenge({
    required this.id,
    required this.userId,
    required this.challengeId,
    required this.status,
    Object? progress,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    this.template,
  }) : progress = freezeJson(progress);

  factory UserChallenge.fromJson(Map<String, dynamic> json) {
    ChallengeTemplate? tpl;
    if (json['challenge'] is Map<String, dynamic>) {
      tpl = ChallengeTemplate.fromJson(
        json['challenge'] as Map<String, dynamic>,
      );
    }
    return UserChallenge(
      id: requiredJsonString(json['id'], 'id'),
      userId: requiredJsonString(json['userId'] ?? json['user_id'], 'userId'),
      challengeId: requiredJsonString(
        json['challengeId'] ?? json['challenge_id'],
        'challengeId',
      ),
      status: json['status'] as String? ?? 'PENDING',
      progress: json['progress'],
      createdAt: requiredJsonDate(
        json['createdAt'] ?? json['created_at'],
        'createdAt',
      ),
      updatedAt: requiredJsonDate(
        json['updatedAt'] ?? json['updated_at'],
        'updatedAt',
      ),
      completedAt: json['completedAt'] != null || json['completed_at'] != null
          ? requiredJsonDate(
              json['completedAt'] ?? json['completed_at'],
              'completedAt',
            )
          : null,
      template: tpl,
    );
  }

  String get displayTitle => template?.title ?? 'Défi';
  String get displayDescription => template?.description ?? '';
  IconData get displayIcon => template?.icon ?? Icons.star_rounded;

  ChallengeStatus get state => ChallengeStatus.values.firstWhere(
    (value) => value.name.toUpperCase() == status,
    orElse: () => ChallengeStatus.unknown,
  );

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
        final current = (val['current'] is num ? val['current'] as num : 0)
            .toDouble();
        final target = (val['target'] is num ? val['target'] as num : 1)
            .toDouble();
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
        final current = val['current'] is num ? val['current'] as num : 0;
        final target = val['target'] is num ? val['target'] as num : 1;
        return '$current / $target';
      }
    }
    // Plusieurs conditions : compter combien sont complètes
    final completed = map.values
        .whereType<Map>()
        .where((v) => v['completed'] == true)
        .length;
    return '$completed / ${map.length}';
  }
}
