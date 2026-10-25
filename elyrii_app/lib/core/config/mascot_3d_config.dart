import 'mascot_animations.dart';

/// Immutable configuration for the Elyrii mascot's 3D viewer.
class Mascot3DConfig {
  /// Path to the 3D model's .glb file.
  final String assetPath;

  /// Animation played once the model loads; defaults to idle.
  final MascotAnimation initialAnimation;

  /// Camera theta angle: horizontal rotation in degrees.
  final double cameraOrbitTheta;

  /// Camera phi angle: vertical rotation in degrees.
  final double cameraOrbitPhi;

  /// Camera distance as a percentage of model-viewer's automatic framing.
  final double cameraOrbitRadius;

  /// Whether automatic model rotation is enabled.
  final bool autoRotate;

  /// Automatic rotation speed in degrees per second.
  final double autoRotateSpeed;

  /// Allows orbiting in the studio; other mascot contexts remain passive.
  final bool interactionEnabled;

  /// When true, configures the camera with the supplied orbit values. Otherwise
  /// uses model-viewer's default automatic framing without zooming out.
  final bool useCameraOrbit;

  /// Vertical camera target in meters along glTF's Y axis, framing the model's
  /// visible body without a layout offset. Null selects automatic targeting.
  final double? cameraTargetY;

  static const MascotAnimation _defaultAnimation = MascotAnimations.idle;
  static const String _defaultAsset = 'assets/optimized/mascot.glb';

  const Mascot3DConfig({
    this.assetPath = _defaultAsset,
    this.initialAnimation = _defaultAnimation,
    this.cameraOrbitTheta = 0,
    this.cameraOrbitPhi = 75,
    this.cameraOrbitRadius = 5.0,
    this.autoRotate = false,
    this.autoRotateSpeed = 20,
    this.interactionEnabled = false,
    this.useCameraOrbit = false,
    this.cameraTargetY,
  });

  const Mascot3DConfig.authPage()
    : assetPath = _defaultAsset,
      initialAnimation = _defaultAnimation,
      cameraOrbitTheta = 0,
      cameraOrbitPhi = 60,
      cameraOrbitRadius =
          14.0, // Valeur par défaut (ignorée car useCameraOrbit = false)
      autoRotate = false,
      autoRotateSpeed = 15,
      interactionEnabled = false,
      useCameraOrbit = false,
      // Cible posée sur le corps de l'ourson : la mascotte est centrée
      // par la caméra, sans Transform.translate de rattrapage.
      cameraTargetY = 0.35;

  /// Full-screen chatbot configuration.
  const Mascot3DConfig.chatbotFull()
    : assetPath = _defaultAsset,
      initialAnimation = _defaultAnimation,
      cameraOrbitTheta = 0,
      cameraOrbitPhi = 75,
      cameraOrbitRadius =
          5.0, // Valeur par défaut (ignorée car useCameraOrbit = false)
      autoRotate = false,
      autoRotateSpeed = 20,
      interactionEnabled = false, // Désactiver les interactions tactiles
      useCameraOrbit = false,
      cameraTargetY = null;

  /// Minimized chatbot banner configuration, using the model's built-in idle
  /// animation without touch interaction.
  const Mascot3DConfig.chatbotMinimized()
    : assetPath = _defaultAsset,
      initialAnimation = _defaultAnimation,
      cameraOrbitTheta = 0,
      cameraOrbitPhi = 75,
      cameraOrbitRadius =
          5.0, // Valeur par défaut (ignorée car useCameraOrbit = false)
      autoRotate = false,
      autoRotateSpeed = 10,
      interactionEnabled = false,
      useCameraOrbit = false,
      cameraTargetY = null;

  Mascot3DConfig copyWith({
    String? assetPath,
    MascotAnimation? initialAnimation,
    double? cameraOrbitTheta,
    double? cameraOrbitPhi,
    double? cameraOrbitRadius,
    bool? autoRotate,
    double? autoRotateSpeed,
    bool? interactionEnabled,
    bool? useCameraOrbit,
    double? cameraTargetY,
  }) {
    return Mascot3DConfig(
      assetPath: assetPath ?? this.assetPath,
      initialAnimation: initialAnimation ?? this.initialAnimation,
      cameraOrbitTheta: cameraOrbitTheta ?? this.cameraOrbitTheta,
      cameraOrbitPhi: cameraOrbitPhi ?? this.cameraOrbitPhi,
      cameraOrbitRadius: cameraOrbitRadius ?? this.cameraOrbitRadius,
      autoRotate: autoRotate ?? this.autoRotate,
      autoRotateSpeed: autoRotateSpeed ?? this.autoRotateSpeed,
      interactionEnabled: interactionEnabled ?? this.interactionEnabled,
      useCameraOrbit: useCameraOrbit ?? this.useCameraOrbit,
      cameraTargetY: cameraTargetY ?? this.cameraTargetY,
    );
  }
}
