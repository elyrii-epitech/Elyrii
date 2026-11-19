import 'package:flutter/foundation.dart';

import 'mascot_appearance.dart';

/// Immutable data model representing mascot state and configuration, supporting
/// clean architecture and predictable state management.
@immutable
class MascotModel {
  /// Path to the base 3D model (.glb).
  final String baseModelPath;

  /// IDs of selected visual details.
  final List<String> equippedCosmetics;

  /// Current animation state, such as 'idle', 'wave', or 'jump'.
  final String animationState;

  /// Applied visual theme ID, such as 'nature' or 'halloween'. See
  /// [MascotThemes] for the full catalog.
  final String themeId;

  final MascotAppearance appearance;

  MascotModel({
    required this.baseModelPath,
    List<String> equippedCosmetics = const [],
    this.animationState = 'idle',
    this.themeId = 'nature',
    this.appearance = MascotAppearance.defaults,
  }) : equippedCosmetics = List.unmodifiable(equippedCosmetics);

  /// Creates the default mascot model.
  factory MascotModel.defaultMascot() {
    return MascotModel(
      baseModelPath: 'assets/optimized/mascot.glb',
      equippedCosmetics: const [],
      animationState: 'idle',
      themeId: 'nature',
    );
  }

  /// Creates a copy with updated attributes.
  MascotModel copyWith({
    String? baseModelPath,
    List<String>? equippedCosmetics,
    String? animationState,
    String? themeId,
    MascotAppearance? appearance,
  }) {
    return MascotModel(
      baseModelPath: baseModelPath ?? this.baseModelPath,
      equippedCosmetics: equippedCosmetics ?? this.equippedCosmetics,
      animationState: animationState ?? this.animationState,
      themeId: themeId ?? this.themeId,
      appearance: appearance ?? this.appearance,
    );
  }

  /// Deserializes from a JSON map.
  factory MascotModel.fromJson(Map<String, dynamic> json) {
    return MascotModel(
      baseModelPath:
          json['baseModelPath'] as String? ?? 'assets/optimized/mascot.glb',
      equippedCosmetics:
          (json['equippedCosmetics'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      animationState: json['animationState'] as String? ?? 'idle',
      themeId: json['themeId'] as String? ?? 'nature',
      appearance: MascotAppearance.fromJson(
        Map<String, dynamic>.from(json['customization'] as Map? ?? const {}),
      ),
    );
  }

  /// Serializes to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'baseModelPath': baseModelPath,
      'equippedCosmetics': equippedCosmetics,
      'animationState': animationState,
      'themeId': themeId,
      'customization': appearance.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MascotModel &&
          runtimeType == other.runtimeType &&
          baseModelPath == other.baseModelPath &&
          listEquals(equippedCosmetics, other.equippedCosmetics) &&
          animationState == other.animationState &&
          themeId == other.themeId &&
          appearance == other.appearance;

  @override
  int get hashCode => Object.hash(
    baseModelPath,
    Object.hashAll(equippedCosmetics),
    animationState,
    themeId,
    appearance,
  );

  @override
  String toString() {
    return 'MascotModel(baseModelPath: $baseModelPath, equippedCosmetics: $equippedCosmetics, animationState: $animationState, themeId: $themeId)';
  }
}
