import 'package:flutter/material.dart';

import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass/liquid_glass_card.dart';

class LevelProgressHeader extends StatelessWidget {
  final int level;
  final int currentXp;
  final int maxXp;
  final String title;

  const LevelProgressHeader({
    super.key,
    required this.level,
    required this.currentXp,
    required this.maxXp,
    required this.title,
  });

  static const List<Map<String, dynamic>> _states = [
    {'label': 'Éveil', 'emoji': '🌱', 'desc': 'Le début du chemin'},
    {'label': 'Épanouissement', 'emoji': '🌿', 'desc': 'Tu grandis doucement'},
    {'label': 'Sérénité', 'emoji': '🌸', 'desc': 'La paix s\'installe'},
    {'label': 'Harmonie', 'emoji': '🦋', 'desc': 'Tout s\'aligne'},
    {'label': 'Lumière intérieure', 'emoji': '✨', 'desc': 'Tu rayonnes'},
  ];

  String get _stateLabel =>
      _states[(level - 1).clamp(0, _states.length - 1)]['label'] as String;
  String get _stateEmoji =>
      _states[(level - 1).clamp(0, _states.length - 1)]['emoji'] as String;
  String get _stateDesc =>
      _states[(level - 1).clamp(0, _states.length - 1)]['desc'] as String;

  @override
  Widget build(BuildContext context) {
    final progress = (currentXp / maxXp).clamp(0.0, 1.0);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LiquidGlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.2),
                      AppColors.accent.withValues(alpha: 0.15),
                    ],
                  ),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    _stateEmoji,
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
              ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isNotEmpty ? title : _stateLabel,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _stateDesc,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Stack(
            children: [
              Container(
                height: 4,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: progress),
                duration: const Duration(seconds: 2),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return FractionallySizedBox(
                    widthFactor: value,
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.accent],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            progress >= 1.0
                ? 'Une nouvelle étape s\'ouvre à toi...'
                : 'Ton chemin continue, à ton rythme',
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: isDark
                  ? AppColors.textTertiaryDark
                  : AppColors.textTertiaryLight,
            ),
          ),
        ],
      ),
    );
  }
}
