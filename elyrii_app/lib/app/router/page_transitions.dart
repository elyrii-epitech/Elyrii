import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_motion.dart';

abstract final class ElyriiPageTransitions {
  /// Full-screen page entering from the right, with native iOS back swiping
  /// from the left edge.
  static Page<T> slideFromRight<T>({
    required Widget child,
    required LocalKey key,
    String? name,
  }) {
    return CupertinoPage<T>(key: key, name: name, child: child);
  }

  static Page<T> slideFromLeft<T>({
    required Widget child,
    required LocalKey key,
    required bool reduced,
    String? name,
  }) {
    return CustomTransitionPage<T>(
      key: key,
      name: name,
      transitionDuration: reduced ? AppMotion.modalFade : AppMotion.pageSlide,
      reverseTransitionDuration: reduced
          ? AppMotion.modalFade
          : AppMotion.pageSlide,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (reduced) return FadeTransition(opacity: animation, child: child);
        return SlideTransition(
          position: Tween(begin: Offset.zero, end: const Offset(-1 / 3, 0))
              .animate(
                CurvedAnimation(
                  parent: secondaryAnimation,
                  curve: Curves.linearToEaseOut,
                  reverseCurve: Curves.easeInToLinear,
                ),
              ),
          child: SlideTransition(
            position: Tween(begin: const Offset(-1, 0), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.fastEaseInToSlowEaseOut,
                    reverseCurve: Curves.fastEaseInToSlowEaseOut.flipped,
                  ),
                ),
            child: child,
          ),
        );
      },
    );
  }
}
