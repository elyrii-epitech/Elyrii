import 'package:flutter/material.dart';
import '../services/glass_performance_service.dart';

/// Widget qui écoute les notifications de scroll et fournit une vélocité normalisée
/// pour réduire les effets de blur pendant le défilement rapide (iOS 26)
///
/// Exemple d'utilisation:
/// ```dart
/// ScrollVelocityListener(
///   child: ListView.builder(...),
///   onVelocityChanged: (velocity) {
///     setState(() => _scrollVelocity = velocity);
///   },
/// )
/// ```
class ScrollVelocityListener extends StatefulWidget {
  final Widget child;
  final ValueChanged<double>? onVelocityChanged;

  const ScrollVelocityListener({
    super.key,
    required this.child,
    this.onVelocityChanged,
  });

  @override
  State<ScrollVelocityListener> createState() => _ScrollVelocityListenerState();
}

class _ScrollVelocityListenerState extends State<ScrollVelocityListener> {
  double _lastScrollPosition = 0;
  DateTime _lastScrollTime = DateTime.now();
  double _currentVelocity = 0;

  /// Vélocité maximale considérée (pixels par seconde)
  static const double _maxVelocity = 3000.0;

  @override
  Widget build(BuildContext context) {
    final performanceService = GlassPerformanceService();

    if (!performanceService.adaptiveBlurOnScroll) {
      return widget.child;
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          _handleScrollUpdate(notification);
        } else if (notification is ScrollEndNotification) {
          _handleScrollEnd();
        }
        return false; // Ne pas bloquer la propagation
      },
      child: widget.child,
    );
  }

  void _handleScrollUpdate(ScrollUpdateNotification notification) {
    final now = DateTime.now();
    final timeDelta = now.difference(_lastScrollTime).inMilliseconds;

    if (timeDelta > 0) {
      final positionDelta =
          (notification.metrics.pixels - _lastScrollPosition).abs();
      final velocityPxPerMs = positionDelta / timeDelta;
      final velocityPxPerSec = velocityPxPerMs * 1000;

      // Normaliser la vélocité entre 0 et 1
      final normalizedVelocity = (velocityPxPerSec / _maxVelocity).clamp(0.0, 1.0);

      if (normalizedVelocity != _currentVelocity) {
        _currentVelocity = normalizedVelocity;
        widget.onVelocityChanged?.call(_currentVelocity);
      }
    }

    _lastScrollPosition = notification.metrics.pixels;
    _lastScrollTime = now;
  }

  void _handleScrollEnd() {
    // Réinitialiser la vélocité quand le scroll s'arrête
    if (_currentVelocity > 0) {
      _currentVelocity = 0;
      widget.onVelocityChanged?.call(0);
    }
  }
}

/// Mixin pour facilement intégrer la détection de vélocité de scroll
/// dans un StatefulWidget
mixin ScrollVelocityMixin<T extends StatefulWidget> on State<T> {
  double scrollVelocity = 0.0;

  /// Callback à passer à ScrollVelocityListener
  void onScrollVelocityChanged(double velocity) {
    if (mounted && velocity != scrollVelocity) {
      setState(() {
        scrollVelocity = velocity;
      });
    }
  }
}

/// Extension pour envelopper un scrollable avec le listener de vélocité
extension ScrollVelocityX on Widget {
  /// Enveloppe ce widget dans un ScrollVelocityListener
  Widget withScrollVelocityListener({
    required ValueChanged<double> onVelocityChanged,
  }) {
    return ScrollVelocityListener(
      onVelocityChanged: onVelocityChanged,
      child: this,
    );
  }
}
