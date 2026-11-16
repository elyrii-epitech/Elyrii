import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Reduced motion displays the final content and never starts a repeat loop.
extension AccessibleAnimation on Widget {
  Animate animateRespectingMotion(
    BuildContext context, {
    Key? key,
    List<Effect>? effects,
    AnimateCallback? onInit,
    AnimateCallback? onPlay,
    AnimateCallback? onComplete,
    bool? autoPlay,
    Duration? delay,
    AnimationController? controller,
    Adapter? adapter,
    double? target,
    double? value,
  }) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Animate(
      key: key,
      effects: effects,
      onInit: onInit,
      onPlay: reduce ? null : onPlay,
      onComplete: reduce ? null : onComplete,
      autoPlay: reduce ? false : autoPlay,
      delay: reduce ? Duration.zero : delay,
      controller: controller,
      adapter: reduce ? null : adapter,
      target: reduce ? null : target,
      value: reduce ? 1 : value,
      child: this,
    );
  }
}
