import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
  /// Nom de la variante glTF KHR_materials_variants (ex: 'Elyrii', 'Astral', 'Zen'...).
  /// Si null, la variante par défaut du modèle est utilisée.
  final String? variantName;

  /// Teinte de pelage appliquée au PNG de secours (WebGL indisponible).
  final Color? colorTint;


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

  /// Si vrai, affiche l'image de fallback 2D en cas d'erreur.
  /// Faux pour les accessoires afin de ne jamais afficher la mascotte 2D sur le corps 3D.
  final bool showFallbackImage;

  /// Callback appelé quand le modèle est chargé avec succès.
  final VoidCallback? onModelLoaded;

  /// Identifiants des accessoires équipés visibles dans la scène 3D unifiée.
  final List<String>? visibleAccessories;

  /// Callback appelé en cas d'erreur de chargement.
  final ValueChanged<String>? onError;

  const Mascot3DViewer({
    super.key,
    required this.config,
    this.width = 150,
    this.height = 150,
    this.controller,
    this.colorMatrix,
    this.variantName,
    this.colorTint,
    this.animation,
    this.animationTrigger = 0,
    this.breathProgress,
    this.animated = true,
    this.showFallbackImage = true,
    this.visibleAccessories,
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
  Timer? _loadTimeoutTimer;
  Timer? _stabilizeTimer;
  final Stopwatch _seekClock = Stopwatch()..start();
  int _lastSeek = -100;

  bool get _isWidgetTest =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');
  bool get _canMove => _active && _tickerEnabled && !_reducedMotion;

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
    // Sur les émulateurs et devices sous contrainte GPU (chargement WebView + shader compiling),
    // laisser le temps au WebGL de compiler sans basculer prématurément en fallback.
    _loadTimeoutTimer = Timer(const Duration(seconds: 90), () {
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
    _syncPlayback();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    _syncPlayback();
  }

  @override
  void didUpdateWidget(Mascot3DViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.breathProgress != oldWidget.breathProgress) {
      oldWidget.breathProgress?.removeListener(_seekBreath);
      widget.breathProgress?.addListener(_seekBreath);
    }
    if (widget.variantName != oldWidget.variantName &&
        widget.variantName != null) {
      _controller.setVariant(widget.variantName!);
    }
    if (widget.visibleAccessories != oldWidget.visibleAccessories &&
        widget.visibleAccessories != null) {
      _controller.setVisibleAccessories(widget.visibleAccessories!);
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
    _motion.dispose();
    if (widget.controller == null) _controller.onModelLoaded.dispose();
    super.dispose();
  }

  void _onModelLoaded(String modelAddress) {
    if (!mounted) return;
    final hadError = _hasError;
    // Un dépassement du délai de garde n'est pas définitif : si le modèle
    // finit par charger (démarrage à froid du webview), on quitte le
    // fallback PNG pour le rendu 3D.
    _loadTimeoutTimer?.cancel();
    _stabilizeTimer?.cancel();
    _modelLoaded = true;
    _stabilizeTimer = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      final orbitPercent = widget.config.cameraOrbitPercent;
      if (orbitPercent != null) {
        _controller.setCameraOrbitPercent(
          widget.config.cameraOrbitTheta,
          widget.config.cameraOrbitPhi,
          orbitPercent,
        );
      } else if (widget.config.useCameraOrbit) {
        _controller.setCameraOrbit(
          widget.config.cameraOrbitTheta,
          widget.config.cameraOrbitPhi,
          widget.config.cameraOrbitRadius,
        );
      }
      final targetY = widget.config.cameraTargetY;
      if (targetY != null) _controller.setCameraTarget(0, targetY, 0);
      if (widget.variantName != null) {
        _controller.setVariant(widget.variantName!);
      }
      if (widget.visibleAccessories != null) {
        _controller.setVisibleAccessories(widget.visibleAccessories!);
      }
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
    if (!_modelLoaded || _hasError) return;
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
          child: _hasError || _isWidgetTest ? _buildFallback() : _buildViewer(),
        ),
      ),
    );

    // Sur iOS, ColorFiltered autour d'un PlatformView rend la texture
    // transparente. Sur Android, c'est le teint d'origine des Esprits.
    final matrix = widget.colorMatrix;
    final skipPlatformViewFilter =
        !kIsWeb && Platform.isIOS || _hasError || _isWidgetTest;
    if (!skipPlatformViewFilter && matrix != null && matrix.length == 20) {
      const identity = <double>[
        1, 0, 0, 0, 0, //
        0, 1, 0, 0, 0, //
        0, 0, 1, 0, 0, //
        0, 0, 0, 1, 0, //
      ];
      final isIdentity = List.generate(
        20,
        (i) => matrix[i] == identity[i],
      ).every((v) => v);
      if (!isIdentity) {
        return ColorFiltered(
          colorFilter: ColorFilter.matrix(matrix),
          child: child,
        );
      }
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
        MascotModelSurface(
          key: ValueKey((widget.config.assetPath, widget.variantName, _controller)),
          controller: _controller,
          src: widget.config.assetPath,
          interactive: widget.config.interactionEnabled,
          variantName: widget.variantName,
          animated: widget.animated,
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
    if (!widget.showFallbackImage) {
      return const SizedBox.shrink();
    }
    Widget image = Image.asset(
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
    final tint = widget.colorTint;
    if (tint != null) {
      image = ColorFiltered(
        colorFilter: ColorFilter.mode(tint, BlendMode.modulate),
        child: image,
      );
    } else {
      final matrix = widget.colorMatrix;
      if (matrix != null && matrix.length == 20) {
        const identity = <double>[
          1, 0, 0, 0, 0, //
          0, 1, 0, 0, 0, //
          0, 0, 1, 0, 0, //
          0, 0, 0, 1, 0, //
        ];
        final isIdentity = List.generate(
          20,
          (i) => matrix[i] == identity[i],
        ).every((v) => v);
        if (!isIdentity) {
          image = ColorFiltered(
            colorFilter: ColorFilter.matrix(matrix),
            child: image,
          );
        }
      }
    }
    return image;
  }
}
