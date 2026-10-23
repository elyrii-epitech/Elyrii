import 'package:flutter/material.dart';

/// Rebond élastique « squash & stretch » rejoué à chaque incrémentation de
/// [trigger] : léger écrasement vers les pieds, overshoot, puis repos.
///
/// Pivot en bas-centre : les pieds de la mascotte restent ancrés au sol.
/// Désactivé quand les animations sont réduites (accessibilité).
class MascotBounce extends StatefulWidget {
  final Widget child;

  /// Incrémente pour rejouer le rebond.
  final int trigger;

  const MascotBounce({super.key, required this.child, this.trigger = 0});

  @override
  State<MascotBounce> createState() => _MascotBounceState();
}

class _MascotBounceState extends State<MascotBounce>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.92), weight: 30),
    TweenSequenceItem(
      tween: Tween(
        begin: 0.92,
        end: 1.06,
      ).chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 40,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.06,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 30,
    ),
  ]).animate(_controller);

  @override
  void didUpdateWidget(MascotBounce oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger > oldWidget.trigger &&
        !MediaQuery.maybeDisableAnimationsOf(context)!) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      alignment: Alignment.bottomCenter,
      child: widget.child,
    );
  }
}
