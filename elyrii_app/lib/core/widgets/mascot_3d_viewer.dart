import '../diagnostics/app_diagnostics.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../services/mascot_motion_controller.dart';
import 'mascot_model_surface.dart';
import '../config/mascot_3d_config.dart';
import '../config/mascot_animations.dart';
import 'mascot_look.dart';
import 'mascot_poster.dart';
import '../../features/mascot/data/models/mascot_appearance.dart';

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
  /// Conservée pour les consommateurs historiques ; l'atelier utilise
  /// [appearance] pour recolorer les matériaux.
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

  /// Accessory variant inside the shared rigged wardrobe GLB. Null removes it.
  final String? accessoryVariant;
  final MascotAppearance appearance;
  final String posterScope;

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
    this.accessoryVariant,
    this.appearance = MascotAppearance.defaults,
    this.posterScope = 'guest',
    this.onModelLoaded,
    this.onError,
  });

  @override
  State<Mascot3DViewer> createState() => _Mascot3DViewerState();
}

enum _MascotPresence { preparing, revealing, visible, failed, released }

class _Mascot3DViewerState extends State<Mascot3DViewer>
    with WidgetsBindingObserver {
  late MascotModelController _controller;
  late MascotMotionController _motion;
  _MascotPresence _presence = _MascotPresence.preparing;
  bool _active = true;
  bool _tickerEnabled = true;
  bool _reducedMotion = false;
  bool _visible = true;
  bool get _hasError => _presence == _MascotPresence.failed;
  bool get _modelReady => _presence == _MascotPresence.visible;
  bool get _released => _presence == _MascotPresence.released;
  bool get _posterHidden =>
      _modelReady || _presence == _MascotPresence.revealing;
  Timer? _releaseTimer;
  Timer? _loadTimeoutTimer;
  final Stopwatch _seekClock = Stopwatch()..start();
  int _lastSeek = -100;

  MascotLook get _look => MascotLook.framed(
    widget.config,
    appearance: widget.appearance,
    accessoryVariant: widget.accessoryVariant,
  );
  String get _posterKey => MascotPosterStore.key(
    scope: widget.posterScope,
    assetPath: widget.config.assetPath,
    look: _look,
    aspect: widget.width / widget.height,
  );

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
    _loadTimeoutTimer = Timer(MascotModelController.prepareTimeout, () {
      if (mounted && !_posterHidden) {
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
      _motion.dispose();
      if (oldWidget.controller == null) _controller.onModelLoaded.dispose();
      _controller = widget.controller ?? MascotModelController();
      _presence = _MascotPresence.preparing;
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
    _releaseTimer?.cancel();
    _motion.dispose();
    if (widget.controller == null) _controller.onModelLoaded.dispose();
    super.dispose();
  }

  Future<void> _onModelLoaded(MascotPosterFrame frame) async {
    if (!mounted || _released) return;
    final key = _posterKey;
    unawaited(MascotPosterStore.save(key, frame));
    await precacheImage(MemoryImage(frame.bytes), context);
    if (!mounted || _released || key != _posterKey) return;
    _loadTimeoutTimer?.cancel();
    if (_posterHidden) return;
    _applyRotationConfig();
    if (_reducedMotion) {
      setState(() => _presence = _MascotPresence.visible);
      _syncPlayback();
      widget.onModelLoaded?.call();
    } else {
      setState(() => _presence = _MascotPresence.revealing);
    }
  }

  void _finishReveal() {
    if (_presence != _MascotPresence.revealing) return;
    setState(() => _presence = _MascotPresence.visible);
    _syncPlayback();
    widget.onModelLoaded?.call();
  }

  void _syncPlayback() {
    if (!_modelReady) return;
    _motion.setPlaybackEnabled(
      _canMove && _modelReady && widget.breathProgress == null,
    );
    if (!_modelReady || _hasError || !widget.animated) return;
    if (widget.breathProgress != null) {
      _motion.setPlaybackEnabled(false);
      if (_reducedMotion) {
        _controller.pauseAnimation();
      } else if (_canMove) {
        _seekBreath();
      } else {
        _controller.pauseAnimation();
      }
    } else {
      _motion.setPlaybackEnabled(_canMove);
      if (_reducedMotion) {
        _controller.pauseAnimation();
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
    if (!_modelReady ||
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
      AppDiagnostics.record('mascot_animation_failed', error);
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
      AppDiagnostics.record('mascot_rotation_failed', error);
    }
  }

  void _onModelError(String error) {
    if (!mounted) return;

    _loadTimeoutTimer?.cancel();
    _motion.setPlaybackEnabled(false);
    AppDiagnostics.record(
      'mascot_model_failed',
      StateError('model unavailable'),
    );

    setState(() => _presence = _MascotPresence.failed);

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
        _presence = _MascotPresence.preparing;
        _startLoadTimeout();
        setState(() {});
      }
    } else {
      _releaseTimer ??= Timer(const Duration(seconds: 15), () {
        _releaseTimer = null;
        if (!mounted) return;
        _loadTimeoutTimer?.cancel();
        _controller.onModelLoaded.value = false;
        setState(() {
          _presence = _MascotPresence.released;
        });
      });
    }
  }

  Widget _buildViewer() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // WebKit must remain visible to produce the frame behind this poster.
        MascotModelSurface(
          key: ValueKey((widget.config.assetPath, _controller)),
          controller: _controller,
          src: widget.config.assetPath,
          look: _look,
          initialPoster: MascotPosterStore.read(_posterKey),
          interactive: widget.config.interactionEnabled,
          onLoad: _onModelLoaded,
          onError: _onModelError,
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: _posterHidden ? 0 : 1,
              duration: _reducedMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              onEnd: _finishReveal,
              child: _buildFallback(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFallback() => MascotPoster(
    width: widget.width,
    height: widget.height,
    frame: MascotPosterStore.read(_posterKey),
  );
}
