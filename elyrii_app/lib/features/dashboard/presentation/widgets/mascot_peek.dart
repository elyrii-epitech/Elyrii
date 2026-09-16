import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import '../../../../core/config/mascot_3d_config.dart';
import '../../../../core/config/mascot_animations.dart';
import '../../../../core/widgets/mascot_with_accessories.dart';
import '../providers/dashboard_provider.dart';
import '../../../../core/design_system/haptics/elyrii_haptics.dart';

/// Mascotte « peek » du Dashboard : elle flotte librement au-dessus du
/// contenu, ancrée au sol par une ombre de contact dynamique (aucune cage
/// circulaire, aucun halo néon).
///
/// Interactions organiques :
/// - **Tap** : impulsion haptique légère, micro-rebond élastique
///   (squash-and-stretch 0.96 → 1.05 → 1.0) et clip de réaction joyeux.
/// - **Parallaxe** : les micro-mouvements du doigt orientent subtilement
///   l'orbite caméra (±4° theta/phi) avant un retour au neutre amorti
///   ([Curves.easeOutBack]).
/// - **Mood** : humeur joyeuse → `celebrate`, neutre/apaisée → `breathe`,
///   triste → `attentive` (écoute empathique).
class MascotPeek extends StatefulWidget {
  final MoodType? selectedMood;
  final VoidCallback? onTap;
  final bool isDark;

  const MascotPeek({
    super.key,
    this.selectedMood,
    this.onTap,
    this.isDark = false,
  });

  @override
  State<MascotPeek> createState() => _MascotPeekState();
}

class _MascotPeekState extends State<MascotPeek> with TickerProviderStateMixin {
  /// Orbite de base = cadrage auto de model-viewer (theta 0°, phi 75° par
  /// défaut ; rayon exprimé en pourcentage du cadrage auto par le package).
  static const double _baseOrbitTheta = 0;
  static const double _baseOrbitPhi = 75;
  static const double _baseOrbitRadius = 100;

  /// Amplitude maximale de la parallaxe caméra (degrés).
  static const double _parallaxRange = 4;

  late AnimationController _squashController;
  late Animation<double> _squashAnimation;
  late AnimationController _orbitReturnController;
  late CurvedAnimation _orbitReturnAnimation;

  late final Flutter3DController _modelController;

  /// Clip joué actuellement par le modèle (le salut d'arrivée, puis les
  /// réactions au tap et au mood).
  MascotAnimation _clipAnimation = MascotAnimations.greet;

  // Offsets de parallaxe courants (degrés) et point de départ du retour.
  double _orbitTheta = 0;
  double _orbitPhi = 0;
  double _returnStartTheta = 0;
  double _returnStartPhi = 0;
  DateTime _lastOrbitApply = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();

    // Micro-rebond élastique au tap : 1.0 → 0.96 → 1.05 → 1.0.
    _squashController = AnimationController(
      duration: const Duration(milliseconds: 550),
      vsync: this,
    );

    _squashAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.96,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.96,
          end: 1.05,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.05,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 35,
      ),
    ]).animate(_squashController);

    // Retour amorti de la parallaxe vers le neutre (avec léger dépassement).
    _orbitReturnController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _orbitReturnAnimation = CurvedAnimation(
      parent: _orbitReturnController,
      curve: Curves.easeOutBack,
    );
    _orbitReturnController.addListener(_tickOrbitReturn);

    _modelController = Flutter3DController();
  }

  @override
  void didUpdateWidget(MascotPeek oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedMood != oldWidget.selectedMood &&
        widget.selectedMood != null) {
      _reactToMood(widget.selectedMood!);
    }
  }

  @override
  void dispose() {
    _orbitReturnController.removeListener(_tickOrbitReturn);
    _orbitReturnAnimation.dispose();
    _squashController.dispose();
    _orbitReturnController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ //
  // Réactions émotionnelles
  // ------------------------------------------------------------------ //

  void _reactToMood(MoodType mood) {
    final MascotAnimation reaction;
    switch (mood) {
      case MoodType.happy:
      case MoodType.veryHappy:
        // Bras ouverts + haptique de succès. Si `celebrate` est déjà le
        // clip courant, on salue : le viewer ne rejoue pas un clip identique.
        reaction = _clipAnimation == MascotAnimations.celebrate
            ? MascotAnimations.greet
            : MascotAnimations.celebrate;
        ElyriiHaptics.success();
      case MoodType.neutral:
        // Humeur posée : respiration lente.
        reaction = MascotAnimations.breathe;
        ElyriiHaptics.light();
      case MoodType.sad:
      case MoodType.verySad:
        // Écoute empathique : inclinaison bienveillante de la tête.
        reaction = _clipAnimation == MascotAnimations.attentive
            ? MascotAnimations.greet
            : MascotAnimations.attentive;
        ElyriiHaptics.light();
    }

    setState(() => _clipAnimation = reaction);
    _triggerReaction();
  }

  void _triggerReaction() {
    _squashController.forward(from: 0);
  }

  void _onMascotTapped() {
    ElyriiHaptics.light();
    widget.onTap?.call();

    // Réaction joyeuse alternée pour garantir la relecture du clip.
    final reactions = <MascotAnimation>[
      MascotAnimations.greet,
      MascotAnimations.celebrate,
    ]..removeWhere((a) => a == _clipAnimation);
    setState(
      () => _clipAnimation =
          reactions[DateTime.now().microsecond % reactions.length],
    );

    _triggerReaction();
  }

  // ------------------------------------------------------------------ //
  // Parallaxe caméra (±4°, retour amorti easeOutBack)
  // ------------------------------------------------------------------ //

  void _updateParallaxTarget(Offset localPosition) {
    final size = context.size;
    if (size == null || size.width <= 0 || size.height <= 0) return;

    final dx = (localPosition.dx / size.width * 2 - 1).clamp(-1.0, 1.0);
    final dy = (localPosition.dy / size.height * 2 - 1).clamp(-1.0, 1.0);

    _orbitReturnController.stop();
    _orbitTheta = lerpDouble(_orbitTheta, dx * _parallaxRange, 0.35)!;
    _orbitPhi = lerpDouble(_orbitPhi, -dy * _parallaxRange, 0.35)!;
    _applyOrbit();
  }

  void _startOrbitReturn() {
    if (_orbitTheta == 0 && _orbitPhi == 0) return;
    _returnStartTheta = _orbitTheta;
    _returnStartPhi = _orbitPhi;
    _orbitReturnController.forward(from: 0);
  }

  void _tickOrbitReturn() {
    final t = _orbitReturnAnimation.value;
    _orbitTheta = lerpDouble(_returnStartTheta, 0, t)!;
    _orbitPhi = lerpDouble(_returnStartPhi, 0, t)!;
    _applyOrbit();
  }

  /// Applique l'orbite caméra, throttulé (~30 fps) pour ne pas saturer le
  /// canal JavaScript de la webview ; sans effet avant le chargement.
  void _applyOrbit() {
    final now = DateTime.now();
    if (now.difference(_lastOrbitApply).inMilliseconds < 32) return;
    _lastOrbitApply = now;

    try {
      _modelController.setCameraOrbit(
        _baseOrbitTheta + _orbitTheta,
        _baseOrbitPhi + _orbitPhi,
        _baseOrbitRadius,
      );
    } catch (_) {
      // Le modèle n'a pas encore fini de charger : les micro-mouvements
      // de parallaxe sont ignorés silencieusement jusqu'à stabilisation.
    }
  }

  // ------------------------------------------------------------------ //
  // Construction
  // ------------------------------------------------------------------ //

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onMascotTapped,
      child: Listener(
        onPointerDown: (event) => _updateParallaxTarget(event.localPosition),
        onPointerMove: (event) => _updateParallaxTarget(event.localPosition),
        onPointerUp: (_) => _startOrbitReturn(),
        onPointerCancel: (_) => _startOrbitReturn(),
        behavior: HitTestBehavior.deferToChild,
        child: AnimatedBuilder(
          animation: _squashAnimation,
          builder: (context, _) {
            return SizedBox(
              width: 220,
              height: 220,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Transform.scale(
                    scaleX: 1.0 + (1.0 - _squashAnimation.value) * 0.6,
                    scaleY: _squashAnimation.value,
                    alignment: Alignment.bottomCenter,
                    child: MascotWithAccessories(
                      controller: _modelController,
                      config: const Mascot3DConfig(
                        autoRotate: false,
                        interactionEnabled: false,
                        showLoadingIndicator: true,
                        useCameraOrbit: false,
                      ),
                      animation: _clipAnimation,
                      width: 220,
                      height: 220,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
