import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass/liquid_glass_card.dart';

class MeditationPage extends StatefulWidget {
  const MeditationPage({super.key});

  @override
  State<MeditationPage> createState() => _MeditationPageState();
}

class _MeditationPageState extends State<MeditationPage>
    with SingleTickerProviderStateMixin {
  bool _isMeditating = false;
  String _instruction = 'Prends un moment pour toi';
  Timer? _timer;
  bool _isInhaling = true;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController =
        AnimationController(vsync: this, duration: 4.seconds);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _toggleMeditation() {
    setState(() {
      _isMeditating = !_isMeditating;
      if (_isMeditating) {
        _isInhaling = true;
        _instruction = 'Inspirez...';
        _animationController.repeat(reverse: true);
        _startTimer();
      } else {
        _timer?.cancel();
        _instruction = 'Prends un moment pour toi';
        _animationController.stop();
        _animationController.reset();
      }
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      setState(() {
        _isInhaling = !_isInhaling;
        _instruction = _isInhaling ? 'Inspirez...' : 'Expirez...';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.scaffoldDark : AppColors.scaffoldLight,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Breathing Visual Metaphor
            SizedBox(
              width: 200,
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer Glow
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.2),
                          AppColors.primary.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  )
                      .animate(
                        controller: _animationController,
                        autoPlay: false,
                      )
                      .scale(
                        begin: const Offset(0.8, 0.8),
                        end: const Offset(1.2, 1.2),
                        duration: 4.seconds,
                        curve: Curves.easeInOut,
                      ),

                  // Glass Circle
                  LiquidGlassCard(
                    padding: EdgeInsets.zero,
                    borderRadius: 100,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.spa_rounded,
                        size: 48,
                        color: AppColors.primary,
                      ),
                    ),
                  )
                      .animate(
                        controller: _animationController,
                        autoPlay: false,
                      )
                      .scale(
                        begin: const Offset(0.95, 0.95),
                        end: const Offset(1.05, 1.05),
                        duration: 4.seconds,
                        curve: Curves.easeInOut,
                      ),
                ],
              ),
            ),

            const SizedBox(height: 48),

            Text(
              'Respire',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ).animate().fadeIn(duration: 1.seconds, delay: 500.ms),

            const SizedBox(height: 8),

            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: Text(
                _instruction,
                key: ValueKey<String>(_instruction),
                style: TextStyle(
                  fontSize: 16,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ),

            const SizedBox(height: 48),

            // Start Button
            LiquidGlassCard(
              onTap: _toggleMeditation,
              borderRadius: 30,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              color: AppColors.primary.withValues(alpha: 0.2),
              child: Text(
                _isMeditating ? 'Arrêter' : 'Commencer',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ).animate().slideY(begin: 0.2, end: 0, delay: 1.seconds).fadeIn(),
          ],
        ),
      ),
    );
  }
}
