import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import '../config/mascot_3d_config.dart';

/// Service centralisé pour la gestion du modèle 3D de la mascotte.
///
/// Singleton qui gère la configuration par défaut, l'état du modèle,
/// et prépare l'architecture pour la personnalisation future
/// (cosmétiques, changement de modèle, etc.)
class Mascot3DService {
  Mascot3DService._();

  static final Mascot3DService _instance = Mascot3DService._();

  /// Instance singleton du service.
  static Mascot3DService get instance => _instance;

  /// Configuration par défaut de la mascotte 3D.
  Mascot3DConfig _defaultConfig = const Mascot3DConfig();

  /// Indique si le modèle a été chargé au moins une fois avec succès.
  bool _hasLoadedSuccessfully = false;

  // ==================== GETTERS ====================

  /// Configuration par défaut actuelle.
  Mascot3DConfig get defaultConfig => _defaultConfig;

  /// Indique si le modèle 3D a déjà été chargé avec succès au moins une fois.
  bool get hasLoadedSuccessfully => _hasLoadedSuccessfully;

  /// Chemin vers le modèle 3D actuel.
  String get currentModelPath => _defaultConfig.assetPath;

  // ==================== CONFIGURATION ====================

  /// Retourne la configuration adaptée pour un contexte donné.
  Mascot3DConfig getConfig(Mascot3DContext context) {
    switch (context) {
      case Mascot3DContext.authPage:
        return const Mascot3DConfig.authPage();
      case Mascot3DContext.chatbotFull:
        return const Mascot3DConfig.chatbotFull();
      case Mascot3DContext.chatbotMinimized:
        return const Mascot3DConfig.chatbotMinimized();
    }
  }

  /// Met à jour la configuration par défaut.
  /// Utilisé pour appliquer des changements globaux (ex: nouveau modèle).
  void updateDefaultConfig(Mascot3DConfig config) {
    _defaultConfig = config;
  }

  // ==================== ÉTAT ====================

  /// Marque le modèle comme chargé avec succès.
  void markAsLoaded() {
    _hasLoadedSuccessfully = true;
  }

  /// Reset l'état du service.
  void reset() {
    _defaultConfig = const Mascot3DConfig();
    _hasLoadedSuccessfully = false;
  }

  // ==================== FUTUR : PERSONNALISATION ====================

  /// Placeholder pour le futur système de personnalisation.
  /// Retournera un path de modèle personnalisé avec les cosmétiques appliqués.
  ///
  /// Pour l'instant, retourne simplement le path par défaut.
  String getCustomizedModelPath({List<String>? equippedCosmetics}) {
    // TODO: Implémenter la logique de personnalisation
    // ex: assembler un modèle avec les cosmétiques sélectionnés
    return _defaultConfig.assetPath;
  }

  // ==================== HELPERS ====================

  /// Configure un [Flutter3DController] avec les paramètres de rotation.
  void applyRotationConfig(
    Flutter3DController controller,
    Mascot3DConfig config,
  ) {
    if (config.autoRotate) {
      controller.setCameraOrbit(
        config.cameraOrbitTheta,
        config.cameraOrbitPhi,
        config.cameraOrbitRadius,
      );
    }
  }
}

/// Contextes d'utilisation de la mascotte 3D.
enum Mascot3DContext {
  /// Pages d'authentification (login, register).
  authPage,

  /// Chatbot en mode plein écran.
  chatbotFull,

  /// Chatbot en mode minimisé (banner).
  chatbotMinimized,
}
