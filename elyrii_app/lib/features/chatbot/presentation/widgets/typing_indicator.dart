import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'chat_message_bubble.dart' show ChatBubbleStyles;

/// Indicateur de frappe intégré à une bulle assistante, façon iMessage :
/// trois points pulsants décalés de 200 ms chacun, montée/descente avec
/// une inertie `easeInOutSine` et un léger déplacement vertical.
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  static const _period = 1200;
  static const _stagger = 200;
  static const _pulse = 600;

  late final AnimationController _controller;
  late final List<Animation<double>> _dots;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: _period),
      vsync: this,
    )..repeat();

    // Chaque point monte puis redescend sur 600 ms, décalé de 200 ms
    // par rapport au précédent — jamais synchrones, jamais mécaniques.
    _dots = List.generate(3, (index) {
      final start = (index * _stagger) / _period;
      const span = _pulse / _period;
      return TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween(
            begin: 0.0,
            end: 1.0,
          ).chain(CurveTween(curve: Curves.easeInOutSine)),
          weight: 50,
        ),
        TweenSequenceItem(
          tween: Tween(
            begin: 1.0,
            end: 0.0,
          ).chain(CurveTween(curve: Curves.easeInOutSine)),
          weight: 50,
        ),
      ]).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(start, start + span),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(
                    alpha: isDark ? 0.18 : 0.10,
                  ),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const ImageIcon(
                  AssetImage('assets/brand/navbar_app_icon.png'),
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 11),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                decoration: ChatBubbleStyles.assistant(isDark),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(
                    3,
                    (index) => _buildDot(index, isDark),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDot(int index, bool isDark) {
    return AnimatedBuilder(
      animation: _dots[index],
      builder: (context, child) {
        final t = _dots[index].value;
        return Transform.translate(
          offset: Offset(0, -3.0 * t),
          child: Container(
            margin: EdgeInsets.only(right: index < 2 ? 6 : 0),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (isDark ? Colors.white : AppColors.primary).withValues(
                alpha: 0.3 + 0.7 * t,
              ),
            ),
          ),
        );
      },
    );
  }
}
