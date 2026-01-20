import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../config/mascot_animations.dart';

class MascotAnimationCache {
  MascotAnimationCache._();

  static final Map<String, LottieComposition> _cache = {};

  static Future<void> preload(List<MascotAnimation> animations) async {
    for (final animation in animations) {
      if (!_cache.containsKey(animation.assetPath)) {
        try {
          final composition = await AssetLottie(animation.assetPath).load();
          _cache[animation.assetPath] = composition;
        } catch (e) {
          debugPrint('Erreur préchargement ${animation.id}: $e');
        }
      }
    }
  }

  static Future<void> preloadAll() async {
    await preload(
        [MascotAnimations.idle, ...MascotAnimations.specialAnimations]);
  }

  static LottieComposition? get(String assetPath) => _cache[assetPath];

  static bool contains(String assetPath) => _cache.containsKey(assetPath);

  static void put(String assetPath, LottieComposition composition) {
    _cache[assetPath] = composition;
  }

  static void clear() {
    _cache.clear();
  }
}

class MascotAnimationPlayer extends StatefulWidget {
  final MascotAnimation animation;
  final double size;
  final VoidCallback? onAnimationComplete;

  const MascotAnimationPlayer({
    super.key,
    required this.animation,
    required this.size,
    this.onAnimationComplete,
  });

  @override
  State<MascotAnimationPlayer> createState() => _MascotAnimationPlayerState();
}

class _MascotAnimationPlayerState extends State<MascotAnimationPlayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _loadAnimation();
  }

  @override
  void didUpdateWidget(MascotAnimationPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation.id != widget.animation.id) {
      _loadAnimation();
    }
  }

  Future<void> _loadAnimation() async {
    final assetPath = widget.animation.assetPath;

    if (MascotAnimationCache.contains(assetPath)) {
      _setupController(MascotAnimationCache.get(assetPath)!);
      return;
    }

    try {
      final composition = await AssetLottie(assetPath).load();
      MascotAnimationCache.put(assetPath, composition);
      if (mounted) {
        _setupController(composition);
      }
    } catch (e) {
      debugPrint('Erreur chargement animation: $e');
    }
  }

  void _setupController(LottieComposition composition) {
    _controller.duration = composition.duration;

    if (widget.animation.loop) {
      _controller.repeat();
    } else {
      _controller.forward(from: 0).then((_) {
        widget.onAnimationComplete?.call();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Lottie.asset(
        widget.animation.assetPath,
        controller: _controller,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
        addRepaintBoundary: true,
      ),
    );
  }
}
