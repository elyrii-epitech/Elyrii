import 'package:flutter/foundation.dart';

/// Modèle de données représentant l'état et la configuration de la mascotte.
///
/// Immutable pour s'aligner sur les architectures propres et permettre une
/// gestion d'état prédictible.
@immutable
class MascotModel {
  /// Chemin vers le modèle 3D de base (.glb)
  final String baseModelPath;

  /// Liste des identifiants de détails visuels sélectionnés.
  final List<String> equippedCosmetics;

  /// État actuel de l'animation (ex: 'idle', 'wave', 'jump')
  final String animationState;

  const MascotModel({
    required this.baseModelPath,
    this.equippedCosmetics = const [],
    this.animationState = 'idle',
  });

  /// Crée un modèle par défaut de la mascotte.
  factory MascotModel.defaultMascot() {
    return const MascotModel(
      baseModelPath: 'assets/base_basic_shaded_v3.glb',
      equippedCosmetics: [],
      animationState: 'idle',
    );
  }

  /// Crée une copie de ce modèle avec des attributs modifiés.
  MascotModel copyWith({
    String? baseModelPath,
    List<String>? equippedCosmetics,
    String? animationState,
  }) {
    return MascotModel(
      baseModelPath: baseModelPath ?? this.baseModelPath,
      equippedCosmetics: equippedCosmetics ?? this.equippedCosmetics,
      animationState: animationState ?? this.animationState,
    );
  }

  /// Désérialise depuis une map JSON.
  factory MascotModel.fromJson(Map<String, dynamic> json) {
    return MascotModel(
      baseModelPath:
          json['baseModelPath'] as String? ?? 'assets/base_basic_shaded_v3.glb',
      equippedCosmetics: (json['equippedCosmetics'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      animationState: json['animationState'] as String? ?? 'idle',
    );
  }

  /// Sérialise en map JSON.
  Map<String, dynamic> toJson() {
    return {
      'baseModelPath': baseModelPath,
      'equippedCosmetics': equippedCosmetics,
      'animationState': animationState,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MascotModel &&
          runtimeType == other.runtimeType &&
          baseModelPath == other.baseModelPath &&
          listEquals(equippedCosmetics, other.equippedCosmetics) &&
          animationState == other.animationState;

  @override
  int get hashCode => Object.hash(
        baseModelPath,
        Object.hashAll(equippedCosmetics),
        animationState,
      );

  @override
  String toString() {
    return 'MascotModel(baseModelPath: $baseModelPath, equippedCosmetics: $equippedCosmetics, animationState: $animationState)';
  }
}
