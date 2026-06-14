import 'package:flutter/material.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import 'package:shimmer/shimmer.dart';
import '../config/mascot_3d_config.dart';
import '../theme/app_colors.dart';

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
    this.onModelLoaded,
    this.onError,
  });

  @override
  State<Mascot3DViewer> createState() => _Mascot3DViewerState();
}

class _Mascot3DViewerState extends State<Mascot3DViewer> {
  late Flutter3DController _controller;
  bool _isLoading = true;
  bool _hasError = false;

  bool get _isWidgetTest {
    return WidgetsBinding.instance.runtimeType.toString().contains('Test');
  }

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? Flutter3DController();
  }

  @override
  void didUpdateWidget(Mascot3DViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si un nouveau contrôleur externe est fourni, l'utiliser
    if (widget.controller != null &&
        widget.controller != oldWidget.controller) {
      _controller = widget.controller!;
    }
    if (widget.config.assetPath != oldWidget.config.assetPath) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }
  }

  void _onModelLoaded(String modelAddress) {
    if (!mounted) return;

    // Configurer la caméra après un court délai pour laisser la plateforme s'initialiser
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        if (widget.config.useCameraOrbit) {
          _controller.setCameraOrbit(
            widget.config.cameraOrbitTheta,
            widget.config.cameraOrbitPhi,
            widget.config.cameraOrbitRadius,
          );
        }
        _applyRotationConfig();
      }
    });

    setState(() {
      _isLoading = false;
      _hasError = false;
    });

    widget.onModelLoaded?.call();
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
      _isLoading = false;
      _hasError = true;
    });

    widget.onError?.call(error);
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: IgnorePointer(
        ignoring: !widget.config.interactionEnabled,
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: _hasError || _isWidgetTest ? _buildFallback() : _buildViewer(),
        ),
      ),
    );
  }

  Widget _buildViewer() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Le viewer 3D
        Flutter3DViewer(
          controller: _controller,
          src: widget.config.assetPath,
          activeGestureInterceptor: widget.config.interactionEnabled,
          enableTouch: widget.config.interactionEnabled,
          progressBarColor: widget.config.showLoadingIndicator
              ? AppColors.primary
              : Colors.transparent,
          onProgress: (double progressValue) {
            // Progression du chargement disponible si besoin
          },
          onLoad: _onModelLoaded,
          onError: _onModelError,
        ),

        // Shimmer loading overlay
        if (_isLoading && widget.config.showLoadingIndicator)
          Positioned.fill(
            child: _buildLoadingShimmer(),
          ),
      ],
    );
  }

  /// Shimmer animé pendant le chargement du modèle 3D.
  Widget _buildLoadingShimmer() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
      highlightColor: isDark ? Colors.grey.shade600 : Colors.grey.shade100,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
          shape: BoxShape.circle,
        ),
      ),
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
        // Si même le PNG échoue, afficher un placeholder
        return Icon(
          Icons.pets_rounded,
          size: widget.width * 0.5,
          color: AppColors.primary.withValues(alpha: 0.5),
        );
      },
    );
  }
}
