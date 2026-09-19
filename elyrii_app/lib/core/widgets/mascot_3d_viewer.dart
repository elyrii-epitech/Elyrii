import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../services/mascot_motion_controller.dart';
import 'mascot_model_surface.dart';
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
  final MascotModelController? controller;

  /// Matrice de couleur optionnelle (20 valeurs) pour recolorer le modèle.
  /// Si null, aucune transformation n'est appliquée.
  /// Utilisée par le système de thèmes (voir [MascotThemes]).
  final List<double>? colorMatrix;

  /// Animation à jouer maintenant. Null → [Mascot3DConfig.initialAnimation].
  ///
  /// Les clips `once` retournent automatiquement à idle à leur fin.
  /// [MascotAnimations.holdPose] fige la pose courante (pauseAnimation).
  final MascotAnimation? animation;

  /// Incrémenter pour rejouer un même geste après une nouvelle interaction.
  final int animationTrigger;

  /// Progression du souffle 0 → 1, partagée avec le cercle de guidage.
  final ValueListenable<double>? breathProgress;

  /// Faux pour les accessoires statiques sans clips natifs.
  final bool animated;

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
    this.animationTrigger = 0,
    this.breathProgress,
    this.animated = true,
    this.onModelLoaded,
    this.onError,
  });

  @override
  State<Mascot3DViewer> createState() => _Mascot3DViewerState();
}

class _Mascot3DViewerState extends State<Mascot3DViewer>
    with WidgetsBindingObserver {
  late MascotModelController _controller;
  late MascotMotionController _motion;
  bool _hasError = false;
  bool _modelLoaded = false;
  bool _modelReady = false;
  bool _active = true;
  bool _tickerEnabled = true;
  bool _reducedMotion = false;
  bool _visible = true;
  bool _released = false;
  Timer? _releaseTimer;
  Timer? _loadTimeoutTimer;
  Timer? _stabilizeTimer;
  final Stopwatch _seekClock = Stopwatch()..start();
  int _lastSeek = -100;

  bool get _isWidgetTest =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');
  bool get _canMove =>
      _active && _tickerEnabled && _visible && !_reducedMotion && !_released;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _active =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _controller = widget.controller ?? MascotModelController();
    _createMotion();
    widget.breathProgress?.addListener(_seekBreath);
    _startLoadTimeout();
  }

  void _createMotion() {
    _motion = MascotMotionController()..addListener(_playCurrent);
    _motion.setAnimation(
      widget.animation ?? widget.config.initialAnimation,
      trigger: widget.animationTrigger,
    );
  }

  void _startLoadTimeout() {
    _loadTimeoutTimer?.cancel();
    if (_isWidgetTest) return;
    _loadTimeoutTimer = Timer(const Duration(seconds: 20), () {
      if (mounted && !_modelLoaded) {
        _onModelError('Délai de chargement dépassé');
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    _updateRetention();
    _syncPlayback();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    _updateRetention();
    _syncPlayback();
  }

  @override
  void didUpdateWidget(Mascot3DViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.breathProgress != oldWidget.breathProgress) {
      oldWidget.breathProgress?.removeListener(_seekBreath);
      widget.breathProgress?.addListener(_seekBreath);
    }
    if (widget.config.assetPath != oldWidget.config.assetPath ||
        widget.controller != oldWidget.controller) {
      _stabilizeTimer?.cancel();
      _motion.dispose();
      if (oldWidget.controller == null) _controller.onModelLoaded.dispose();
      _controller = widget.controller ?? MascotModelController();
      _modelLoaded = false;
      _modelReady = false;
      _hasError = false;
      _createMotion();
      _startLoadTimeout();
    }
    _motion.setAnimation(
      widget.animation ?? widget.config.initialAnimation,
      trigger: widget.animationTrigger,
    );
    _syncPlayback();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.breathProgress?.removeListener(_seekBreath);
    _loadTimeoutTimer?.cancel();
    _stabilizeTimer?.cancel();
    _releaseTimer?.cancel();
    _motion.dispose();
    if (widget.controller == null) _controller.onModelLoaded.dispose();
    super.dispose();
  }

  void _onModelLoaded(String modelAddress) {
    if (!mounted || _released) return;
    final hadError = _hasError;
    // Un dépassement du délai de garde n'est pas définitif : si le modèle
    // finit par charger (démarrage à froid du webview), on quitte le
    // fallback PNG pour le rendu 3D.
    _loadTimeoutTimer?.cancel();
    _stabilizeTimer?.cancel();
    _modelLoaded = true;
    _stabilizeTimer = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      if (widget.config.useCameraOrbit) {
        _controller.setCameraOrbit(
          widget.config.cameraOrbitTheta,
          widget.config.cameraOrbitPhi,
          widget.config.cameraOrbitRadius,
        );
      }
      final targetY = widget.config.cameraTargetY;
      if (targetY != null) _controller.setCameraTarget(0, targetY, 0);
      _applyRotationConfig();
      setState(() {
        _hasError = false;
        _modelReady = true;
      });
      if (hadError) {
        debugPrint(
          'Mascot3DViewer: modèle 3D chargé après le délai — retour au rendu 3D',
        );
      }
      _syncPlayback();
      _playCurrent();
      widget.onModelLoaded?.call();
    });
  }

  void _syncPlayback() {
    _motion.setPlaybackEnabled(
      _canMove && _modelReady && widget.breathProgress == null,
    );
    if (!_modelReady || _hasError || !widget.animated) return;
    if (widget.breathProgress != null) {
      _motion.setPlaybackEnabled(false);
      if (_reducedMotion) {
        _controller.restPose();
      } else if (_canMove) {
        _seekBreath();
      } else {
        _controller.pauseAnimation();
      }
    } else {
      _motion.setPlaybackEnabled(_canMove);
      if (_reducedMotion) {
        _controller.restPose();
      } else if (!_canMove) {
        _controller.pauseAnimation();
      }
    }
  }

  void _seekBreath() {
    if (!_modelReady || !_canMove || _hasError) return;
    final progress = widget.breathProgress?.value;
    if (progress == null) return;
    final now = _seekClock.elapsedMilliseconds;
    // Au plus 30 messages/s vers WebKit. Les extrémités restent exactes.
    if (now - _lastSeek < 33 && progress > 0 && progress < 1) return;
    _lastSeek = now;
    _controller.seekBreath(progress);
  }

  void _playCurrent() {
    if (!_modelLoaded ||
        _hasError ||
        !_canMove ||
        widget.breathProgress != null) {
      return;
    }
    final animation = _motion.current;
    try {
      if (animation.mode == MascotAnimationMode.hold) {
        _controller.pauseAnimation();
      } else {
        _controller.playAnimation(
          animationName: animation.clipName,
          loopCount: animation.mode == MascotAnimationMode.once ? 1 : 0,
        );
      }
    } catch (error) {
      debugPrint('Mascot3DViewer: lecture ${animation.clipName}: $error');
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

    _loadTimeoutTimer?.cancel();
    _stabilizeTimer?.cancel();
    _motion.setPlaybackEnabled(false);
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
          child: _hasError || _isWidgetTest || _released
              ? _buildFallback()
              : _buildViewer(),
        ),
      ),
    );

    final tinted = widget.colorMatrix != null
        ? ColorFiltered(
            colorFilter: ColorFilter.matrix(widget.colorMatrix!),
            child: child,
          )
        : child;
    if (_isWidgetTest) return tinted;
    return VisibilityDetector(
      key: ValueKey(('mascot-visibility', this)),
      onVisibilityChanged: (info) {
        final visible = info.visibleFraction > 0;
        if (!mounted || visible == _visible) return;
        _visible = visible;
        _updateRetention();
        _syncPlayback();
      },
      child: tinted,
    );
  }

  /// Keep rapid tab switches warm, but release native/WebGL resources when
  /// a mascot stays offscreen. Pausing alone does not release its memory.
  void _updateRetention() {
    if (_isWidgetTest) return;
    if (_active && _tickerEnabled && _visible) {
      _releaseTimer?.cancel();
      _releaseTimer = null;
      if (_released) {
        _released = false;
        _hasError = false;
        _startLoadTimeout();
        setState(() {});
      }
    } else {
      _releaseTimer ??= Timer(const Duration(seconds: 15), () {
        _releaseTimer = null;
        if (!mounted) return;
        _loadTimeoutTimer?.cancel();
        _stabilizeTimer?.cancel();
        _controller.onModelLoaded.value = false;
        setState(() {
          _released = true;
          _modelLoaded = false;
          _modelReady = false;
        });
      });
    }
  }

  Widget _buildViewer() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Le viewer reste toujours à opacité 1.0 : sur iOS (WebKit), une vue
        // native à opacité 0.0 suspend le rendu WebGL et bloque l'évènement
        // onLoad de model-viewer.
        MascotModelSurface(
          key: ValueKey((widget.config.assetPath, _controller)),
          controller: _controller,
          src: widget.config.assetPath,
          interactive: widget.config.interactionEnabled,
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
