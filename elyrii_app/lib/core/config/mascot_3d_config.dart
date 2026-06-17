/// Configuration immutable pour le viewer 3D de la mascotte Elyrii.
///
/// Fournit des configurations prédéfinies pour chaque contexte d'utilisation
/// (auth, chatbot full, chatbot minimisé) et est extensible pour la
/// personnalisation future (cosmétiques, animations, etc.)
class Mascot3DConfig {
  /// Chemin vers le fichier .glb du modèle 3D
  final String assetPath;

  /// Position de la caméra : angle theta (rotation horizontale en degrés)
  final double cameraOrbitTheta;

  /// Position de la caméra : angle phi (rotation verticale en degrés)
  final double cameraOrbitPhi;

  /// Position de la caméra : distance (rayon)
  final double cameraOrbitRadius;

  /// Active/désactive la rotation automatique du modèle
  final bool autoRotate;

  /// Vitesse de la rotation automatique (degrés/seconde)
  final double autoRotateSpeed;

  /// Conservé pour compatibilité, mais la mascotte Elyrii reste non
  /// manipulable par l'utilisateur dans le viewer.
  final bool interactionEnabled;

  /// Afficher la barre de progression pendant le chargement
  final bool showLoadingIndicator;

  /// Si vrai, configure la caméra avec les valeurs d'orbite fournies.
  /// Si faux, utilise l'auto-cadrage par défaut de model-viewer (pas d'effet de zoom arrière).
  final bool useCameraOrbit;

  const Mascot3DConfig({
    this.assetPath = 'assets/base_basic_shaded_v3.glb',
    this.cameraOrbitTheta = 0,
    this.cameraOrbitPhi = 75,
    this.cameraOrbitRadius = 5.0,
    this.autoRotate = false,
    this.autoRotateSpeed = 20,
    this.interactionEnabled = false,
    this.showLoadingIndicator = true,
    this.useCameraOrbit = false,
  });

  /// Configuration pour les pages d'authentification (login/register).
  /// Animation idle intégrée au modèle, pas d'interaction tactile.
  const Mascot3DConfig.authPage()
      : assetPath = 'assets/base_basic_shaded_v3.glb',
        cameraOrbitTheta = 0,
        cameraOrbitPhi = 60,
        cameraOrbitRadius =
            14.0, // Valeur par défaut (ignorée car useCameraOrbit = false)
        autoRotate = false,
        autoRotateSpeed = 15,
        interactionEnabled = false,
        showLoadingIndicator = false,
        useCameraOrbit = false;

  /// Configuration pour le chatbot en mode plein écran.
  /// Animation idle intégrée au modèle, sans interaction tactile.
  const Mascot3DConfig.chatbotFull()
      : assetPath = 'assets/base_basic_shaded_v3.glb',
        cameraOrbitTheta = 0,
        cameraOrbitPhi = 75,
        cameraOrbitRadius =
            5.0, // Valeur par défaut (ignorée car useCameraOrbit = false)
        autoRotate = false,
        autoRotateSpeed = 20,
        interactionEnabled = false, // Désactiver les interactions tactiles
        showLoadingIndicator = true,
        useCameraOrbit = false;

  /// Configuration pour le chatbot en mode minimisé (banner).
  /// Animation idle intégrée au modèle, pas d'interaction tactile.
  const Mascot3DConfig.chatbotMinimized()
      : assetPath = 'assets/base_basic_shaded_v3.glb',
        cameraOrbitTheta = 0,
        cameraOrbitPhi = 75,
        cameraOrbitRadius =
            5.0, // Valeur par défaut (ignorée car useCameraOrbit = false)
        autoRotate = false,
        autoRotateSpeed = 10,
        interactionEnabled = false,
        showLoadingIndicator = false,
        useCameraOrbit = false;

  /// Crée une copie de cette configuration avec les champs modifiés.
  /// Utile pour la personnalisation future (changer le modèle, la caméra, etc.)
  Mascot3DConfig copyWith({
    String? assetPath,
    double? cameraOrbitTheta,
    double? cameraOrbitPhi,
    double? cameraOrbitRadius,
    bool? autoRotate,
    double? autoRotateSpeed,
    bool? interactionEnabled,
    bool? showLoadingIndicator,
    bool? useCameraOrbit,
  }) {
    return Mascot3DConfig(
      assetPath: assetPath ?? this.assetPath,
      cameraOrbitTheta: cameraOrbitTheta ?? this.cameraOrbitTheta,
      cameraOrbitPhi: cameraOrbitPhi ?? this.cameraOrbitPhi,
      cameraOrbitRadius: cameraOrbitRadius ?? this.cameraOrbitRadius,
      autoRotate: autoRotate ?? this.autoRotate,
      autoRotateSpeed: autoRotateSpeed ?? this.autoRotateSpeed,
      interactionEnabled: interactionEnabled ?? this.interactionEnabled,
      showLoadingIndicator: showLoadingIndicator ?? this.showLoadingIndicator,
      useCameraOrbit: useCameraOrbit ?? this.useCameraOrbit,
    );
  }
}
