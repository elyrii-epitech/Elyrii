import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass/liquid_glass_card.dart';

class MeditationPage extends StatelessWidget {
  const MeditationPage({super.key});

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
                      .animate(onPlay: (controller) => controller.repeat(reverse: true))
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
                      .animate(onPlay: (controller) => controller.repeat(reverse: true))
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
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ).animate().fadeIn(duration: 1.seconds, delay: 500.ms),
            
            const SizedBox(height: 8),
            
            Text(
              'Prends un moment pour toi',
              style: TextStyle(
                fontSize: 16,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ).animate().fadeIn(duration: 1.seconds, delay: 800.ms),
            
            const SizedBox(height: 48),
            
            // Start Button Placeholder
            LiquidGlassCard(
              onTap: () {},
              borderRadius: 30,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              color: AppColors.primary.withValues(alpha: 0.2),
              child: const Text(
                'Commencer',
                style: TextStyle(
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
