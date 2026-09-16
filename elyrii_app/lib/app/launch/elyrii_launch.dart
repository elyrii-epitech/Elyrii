import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A short brand reveal over the live router, independent of network readiness.
/// Keeping the routed child in the same slot preserves navigation and page state.
class ElyriiLaunch extends StatefulWidget {
  const ElyriiLaunch({super.key, required this.child});

  final Widget child;

  @override
  State<ElyriiLaunch> createState() => _ElyriiLaunchState();
}

class _ElyriiLaunchState extends State<ElyriiLaunch>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..addStatusListener(_onStatus);
  bool _started = false;
  bool _finished = false;
  bool _reduceMotion = false;
  bool _frameDeferred = false;

  @override
  void initState() {
    super.initState();
    // Keep the OS launch artwork visible until its Flutter counterpart is decoded.
    WidgetsBinding.instance.deferFirstFrame();
    _frameDeferred = true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion && _started && !_finished) {
      // Also respect an accessibility change made during the reveal.
      _controller.stop();
      _finished = true;
    }
    if (_started) return;
    _started = true;
    _start();
  }

  Future<void> _start() async {
    try {
      await precacheImage(
        const AssetImage(ElyriiLaunchScene.markAsset),
        context,
        onError: (error, stackTrace) {},
      );
    } finally {
      // A missing asset must never prevent entry into the app.
      _releaseFirstFrame();
    }
    if (!mounted || _finished) return;
    if (_reduceMotion) {
      setState(() => _finished = true);
    } else {
      _controller.forward();
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() => _finished = true);
    }
  }

  void _releaseFirstFrame() {
    if (!_frameDeferred) return;
    _frameDeferred = false;
    WidgetsBinding.instance.allowFirstFrame();
  }

  @override
  void dispose() {
    _releaseFirstFrame();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeFocus(
          excluding: !_finished,
          child: ExcludeSemantics(
            excluding: !_finished,
            child: IgnorePointer(ignoring: !_finished, child: widget.child),
          ),
        ),
        if (!_finished)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final exit = const Interval(
                  0.72,
                  1,
                  curve: Curves.easeInOutCubic,
                ).transform(_controller.value);
                return Opacity(
                  opacity: 1 - exit,
                  child: ElyriiLaunchScene(progress: _controller.value),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// The same transparent emblem and background are used by iOS and Android.
/// [progress] is explicit so the artwork can also be rendered deterministically.
class ElyriiLaunchScene extends StatelessWidget {
  const ElyriiLaunchScene({super.key, this.progress = 0.5});

  static const markAsset = 'assets/splash_icon.png';
  static const background = Color(0xFF141314);
  final double progress;

  @override
  Widget build(BuildContext context) {
    final reveal = const Interval(
      0.04,
      0.5,
      curve: Curves.easeOutCubic,
    ).transform(progress);
    final breath = math.sin(progress * math.pi);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: background,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Semantics(
        label: 'Elyrii. Un instant pour toi.',
        child: ExcludeSemantics(
          child: ColoredBox(
            color: background,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxHeight < 680;
                final markSize = math.min(
                  288.0,
                  math.min(
                    constraints.maxWidth * 0.8,
                    constraints.maxHeight * 0.44,
                  ),
                );
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    RepaintBoundary(
                      child: CustomPaint(
                        painter: _AtmospherePainter(
                          intensity: reveal,
                          breath: breath,
                        ),
                      ),
                    ),
                    Center(
                      child: Transform.scale(
                        scale: 1 + breath * 0.025,
                        child: Image.asset(
                          markAsset,
                          width: markSize,
                          height: markSize,
                          filterQuality: FilterQuality.high,
                          errorBuilder: (context, error, stackTrace) =>
                              const SizedBox.shrink(),
                        ),
                      ),
                    ),
                    Positioned(
                      top: constraints.maxHeight / 2 + markSize * 0.43,
                      left: 24,
                      right: 24,
                      child: Opacity(
                        opacity: reveal,
                        child: Transform.translate(
                          offset: Offset(0, 8 * (1 - reveal)),
                          child: Column(
                            children: [
                              const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'elyrii',
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 38,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 3,
                                    height: 1.25,
                                    color: Color(0xFFF8F2EE),
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ),
                              if (!compact) ...[
                                const SizedBox(height: 14),
                                const Text(
                                  'Un instant pour toi.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: 0.5,
                                    height: 1.5,
                                    color: Color(0xFFC7BFCF),
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _AtmospherePainter extends CustomPainter {
  const _AtmospherePainter({required this.intensity, required this.breath});

  final double intensity;
  final double breath;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width * 0.85, 420.0);

    void glow(Offset position, double radius, Color color, double opacity) {
      canvas.drawCircle(
        position,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: opacity * intensity),
              color.withValues(alpha: 0),
            ],
            stops: const [0, 1],
          ).createShader(Rect.fromCircle(center: position, radius: radius)),
      );
    }

    glow(
      center.translate(-size.width * 0.1, -38 - breath * 8),
      radius * (1 + breath * 0.06),
      const Color(0xFF7E6AD8),
      0.32,
    );
    glow(
      center.translate(size.width * 0.27, 80),
      radius * 0.75,
      const Color(0xFFB97969),
      0.10,
    );

    // A fine, broken halo creates depth without competing with the face.
    final halo = Rect.fromCenter(
      center: center,
      width: 222 + breath * 8,
      height: 222 + breath * 8,
    );
    canvas.drawOval(
      halo,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..shader = SweepGradient(
          colors: [
            const Color(0xFFC7B9EE).withValues(alpha: 0),
            const Color(0xFFC7B9EE).withValues(alpha: intensity * 0.2),
            const Color(0xFFC7B9EE).withValues(alpha: 0),
            const Color(0xFFE6B9A5).withValues(alpha: intensity * 0.16),
            const Color(0xFFC7B9EE).withValues(alpha: 0),
          ],
          transform: GradientRotation(-0.4 + breath * 0.06),
        ).createShader(halo),
    );
  }

  @override
  bool shouldRepaint(_AtmospherePainter oldDelegate) =>
      oldDelegate.intensity != intensity || oldDelegate.breath != breath;
}
