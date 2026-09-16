import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import '../config/mascot_3d_config.dart';
import '../config/mascot_animations.dart';
import '../theme/app_colors.dart';
import 'mascot_warm_placeholder.dart';

/// Widget réutilisable pour afficher la mascotte 3D Elyrii.
///
/// Encapsule [Flutter3DViewer] avec gestion du loading, du fallback PNG,
/// et de la configuration via [Mascot3DConfig].
///
/// Usage:
/// ```dart
/// Mascot3DViewer(
///   config: const Mascot3DConfig.authPage(),
///   width: 150,
///   height: 150,
/// )
/// ```
class Mascot3DViewer extends StatefulWidget {
  /// Configuration du viewer 3D (caméra, rotation, interaction).
  final Mascot3DConfig config;

  /// Largeur du viewer.
  final double width;

  /// Hauteur du viewer.
  final double height;

  /// Contrôleur externe optionnel pour piloter le modèle 3D.
  /// Si non fourni, un contrôleur interne est créé automatiquement.
  final Flutter3DController? controller;

  /// Matrice de couleur optionnelle (20 valeurs) pour recolorer le modèle.
  /// Si null, aucune transformation n'est appliquée.
  /// Utilisée par le système de thèmes (voir [MascotThemes]).
  final List<double>? colorMatrix;

  /// Animation à jouer maintenant. Null → [Mascot3DConfig.initialAnimation].
  ///
  /// Les clips `once` retournent automatiquement à idle à leur fin.
  /// [MascotAnimations.holdPose] fige la pose courante (pauseAnimation).
  final MascotAnimation? animation;

  /// Callback appelé quand le modèle est chargé avec succès.
  final VoidCallback? onModelLoaded;

  /// Callback appelé en cas d'erreur de chargement.
  final ValueChanged<String>? onError;

  const Mascot3DViewer({
    super.key,
    required this.config,
    this.width = 150,
    this.height = 150,
    this.controller,
    this.colorMatrix,
    this.animation,
    this.onModelLoaded,
    this.onError,
  });

  @override
  State<Mascot3DViewer> createState() => _Mascot3DViewerState();
}

class _Mascot3DViewerState extends State<Mascot3DViewer> {
  late Flutter3DController _controller;
  bool _hasError = false;
  bool _modelLoaded = false;

  /// Passe à vrai après le délai de stabilisation post-chargement : le
  /// modèle apparaît alors en fondu (400 ms) depuis le placeholder respirant.
  bool _modelReady = false;
  Timer? _onceTimer;
  Timer? _loadTimeoutTimer;

  bool get _isWidgetTest {
    return WidgetsBinding.instance.runtimeType.toString().contains('Test');
  }

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? Flutter3DController();
    // Sécurité : si WebGL ou model-viewer tarde ou échoue à émettre onLoad,
    // le placeholder s'efface après 3.5s pour ne jamais bloquer l'affichage.
    _loadTimeoutTimer = Timer(const Duration(milliseconds: 3500), () {
      if (mounted && !_modelReady) {
        debugPrint('Mascot3DViewer: Timeout chargement -> affichage modèle');
        setState(() => _modelReady = true);
      }
    });
  }

  @override
  void didUpdateWidget(Mascot3DViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != null &&
        widget.controller != oldWidget.controller) {
      _controller = widget.controller!;
    }
    if (widget.config.assetPath != oldWidget.config.assetPath) {
      setState(() {
        _hasError = false;
        _modelLoaded = false;
        _modelReady = false;
      });
    }
    if (widget.animation != oldWidget.animation && _modelLoaded) {
      _applyAnimation(widget.animation ?? widget.config.initialAnimation);
    }
  }

  @override
  void dispose() {
    _loadTimeoutTimer?.cancel();
    _onceTimer?.cancel();
    super.dispose();
  }

  void _onModelLoaded(String modelAddress) {
    if (!mounted) return;
    _loadTimeoutTimer?.cancel();

    setState(() {
      _modelLoaded = true;
    });

    // Stabilisation post-chargement (cadrage caméra, rotation, clip initial)
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      try {
        if (widget.config.useCameraOrbit) {
          _controller.setCameraOrbit(
            widget.config.cameraOrbitTheta,
            widget.config.cameraOrbitPhi,
            widget.config.cameraOrbitRadius,
          );
        }
        final targetY = widget.config.cameraTargetY;
        if (targetY != null) {
          _controller.setCameraTarget(0, targetY, 0);
        }
        _applyRotationConfig();
        _applyAnimation(widget.animation ?? widget.config.initialAnimation);
      } catch (error) {
        debugPrint('Mascot3DViewer: Configuration post-load ignorée: $error');
      } finally {
        if (mounted) {
          setState(() => _modelReady = true);
        }
      }
    });

    widget.onModelLoaded?.call();
  }

  /// Joue un clip du GLB selon son mode : boucle infinie, une seule fois
  /// (retour automatique à idle) ou gel de la pose courante.
  void _applyAnimation(MascotAnimation animation) {
    _onceTimer?.cancel();

    try {
      switch (animation.mode) {
        case MascotAnimationMode.hold:
          _controller.pauseAnimation();
        case MascotAnimationMode.loop:
          _controller.playAnimation(
            animationName: animation.clipName,
            loopCount: 0,
          );
        case MascotAnimationMode.once:
          _controller.playAnimation(
            animationName: animation.clipName,
            loopCount: 1,
          );
          // flutter_3d_controller n'expose pas l'évènement « finished » :
          // le retour au calme est programmé sur la durée exacte du clip.
          _onceTimer = Timer(animation.duration, () {
            if (!mounted) return;
            _applyAnimation(MascotAnimations.idle);
          });
      }
    } catch (error) {
      debugPrint(
        'Mascot3DViewer: Erreur lecture animation ${animation.clipName}: $error',
      );
    }
  }

  void _applyRotationConfig() {
    try {
      if (widget.config.autoRotate) {
        final speed = widget.config.autoRotateSpeed.round();
        _controller.startRotation(rotationSpeed: speed <= 0 ? 1 : speed);
      } else {
        _controller.stopRotation();
      }
    } catch (error) {
      debugPrint('Mascot3DViewer: Erreur configuration rotation: $error');
    }
  }

  void _onModelError(String error) {
    if (!mounted) return;

    debugPrint('Mascot3DViewer: Erreur chargement modèle 3D: $error');

    setState(() {
      _hasError = true;
    });

    widget.onError?.call(error);
  }

  @override
  Widget build(BuildContext context) {
    final child = RepaintBoundary(
      child: IgnorePointer(
        ignoring: !widget.config.interactionEnabled,
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: _hasError || _isWidgetTest ? _buildFallback() : _buildViewer(),
        ),
      ),
    );

    if (widget.colorMatrix != null) {
      return ColorFiltered(
        colorFilter: ColorFilter.matrix(widget.colorMatrix!),
        child: child,
      );
    }
    return child;
  }

  Widget _buildViewer() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Le viewer reste toujours à opacité 1.0 : sur iOS (WebKit), une vue
        // native à opacité 0.0 suspend le rendu WebGL et bloque l'évènement
        // onLoad de model-viewer.
        Flutter3DViewer(
          controller: _controller,
          src: widget.config.assetPath,
          activeGestureInterceptor: widget.config.interactionEnabled,
          enableTouch: widget.config.interactionEnabled,
          progressBarColor: Colors.transparent,
          onProgress: (_) {},
          onLoad: _onModelLoaded,
          onError: _onModelError,
        ),
        if (widget.config.showLoadingIndicator)
          // Placeholder organique respirant superposé : il s'efface en
          // fondu doux dès que le modèle est prêt.
          Positioned.fill(
            child: IgnorePointer(
              ignoring: _modelReady,
              child: AnimatedOpacity(
                opacity: _modelReady ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                child: TickerMode(
                  enabled: !_modelReady,
                  child: MascotWarmPlaceholder(
                    width: widget.width,
                    height: widget.height,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Fallback sur le PNG statique si le modèle 3D ne charge pas.
  Widget _buildFallback() {
    return Image.asset(
      'assets/mascotte.png',
      width: widget.width,
      height: widget.height,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Icon(
          Icons.pets_rounded,
          size: widget.width * 0.5,
          color: AppColors.primary.withValues(alpha: 0.5),
        );
      },
    );
  }
}
