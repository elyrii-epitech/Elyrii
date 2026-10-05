import 'package:flutter/material.dart';

class AppSettings {
  final String id;
  final String userId;
  final String themeMode;
  final bool notificationsEnabled;
  final bool hapticsEnabled;
  final String privacyMode;
  final String language;
  final String mascotAppearance;
  final Map<String, dynamic> mascotPersonality;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AppSettings({
    required this.id,
    required this.userId,
    required this.themeMode,
    required this.notificationsEnabled,
    required this.hapticsEnabled,
    required this.privacyMode,
    required this.language,
    required this.mascotAppearance,
    required this.mascotPersonality,
    this.createdAt,
    this.updatedAt,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? json['user_id'] as String? ?? '',
      themeMode:
          json['themeMode'] as String? ??
          json['theme_mode'] as String? ??
          'SYSTEM',
      notificationsEnabled:
          json['notificationsEnabled'] as bool? ??
          json['notifications_enabled'] as bool? ??
          true,
      hapticsEnabled:
          json['hapticsEnabled'] as bool? ??
          json['haptics_enabled'] as bool? ??
          true,
      privacyMode:
          json['privacyMode'] as String? ??
          json['privacy_mode'] as String? ??
          'STANDARD',
      language: json['language'] as String? ?? 'fr',
      mascotAppearance:
          json['mascotAppearance'] as String? ??
          json['mascot_appearance'] as String? ??
          'nature',
      mascotPersonality: Map<String, dynamic>.from(
        json['mascotPersonality'] as Map? ??
            json['mascot_personality'] as Map? ??
            const <String, dynamic>{},
      ),
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: _parseDate(json['updatedAt'] ?? json['updated_at']),
    );
  }

  ThemeMode get themeModeValue {
    switch (themeMode.toUpperCase()) {
      case 'LIGHT':
        return ThemeMode.light;
      case 'DARK':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  AppSettings copyWith({
    String? themeMode,
    bool? notificationsEnabled,
    bool? hapticsEnabled,
    String? privacyMode,
    String? language,
    String? mascotAppearance,
    Map<String, dynamic>? mascotPersonality,
  }) {
    return AppSettings(
      id: id,
      userId: userId,
      themeMode: themeMode ?? this.themeMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      privacyMode: privacyMode ?? this.privacyMode,
      language: language ?? this.language,
      mascotAppearance: mascotAppearance ?? this.mascotAppearance,
      mascotPersonality: mascotPersonality ?? this.mascotPersonality,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
