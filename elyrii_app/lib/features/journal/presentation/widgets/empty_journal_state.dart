import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/liquid_glass_kit.dart';

/// Donnees d'une inspiration de journal.
class JournalPrompt {
  final IconData icon;
  final String title;
  final String subtitle;

  const JournalPrompt({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

class EmptyJournalState extends StatelessWidget {
  /// Callback appelle quand on clique sur "Ecrire librement".
  final VoidCallback onCreateFirst;

  /// Callback appelle quand on clique sur une inspiration specifique.
  /// Recoit le prompt pour pre-remplir l'editeur.
  final void Function(JournalPrompt prompt)? onPromptSelected;

  final bool isDark;

  const EmptyJournalState({
    super.key,
    required this.onCreateFirst,
    this.onPromptSelected,
    this.isDark = false,
  });

  static const List<JournalPrompt> prompts = [
    JournalPrompt(
      icon: Icons.wb_sunny_rounded,
      title: 'Comment s\'est passée ta journée ?',
      subtitle: 'Décris un moment qui t\'a marqué',
    ),
    JournalPrompt(
      icon: Icons.psychology_rounded,
      title: 'Qu\'est-ce qui occupe tes pensées ?',
      subtitle: 'Libère ton esprit en écrivant',
    ),
    JournalPrompt(
      icon: Icons.favorite_rounded,
      title: 'De quoi es-tu reconnaissant(e) ?',
      subtitle: 'Note 3 choses positives aujourd\'hui',
    ),
    JournalPrompt(
      icon: Icons.auto_awesome_rounded,
      title: 'Qu\'est-ce que tu aimerais améliorer ?',
      subtitle: 'Sans jugement, juste observer',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final textColor = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final subtitleColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.paddingXl,
        AppDimensions.spacingXl,
        AppDimensions.paddingXl,
        bottomPadding + 120,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Mascotte / icone
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.2),
                  AppColors.primaryLight.withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_stories_rounded,
              size: 48,
              color: AppColors.primary,
            ),
          ).animate().fadeIn(duration: 400.ms).scale(curve: Curves.easeOutBack),

          const SizedBox(height: AppDimensions.spacingLg),

          Text(
                'Commence ton journal',
                style: AppTextStyles.headlineSmall(color: textColor),
                textAlign: TextAlign.center,
              )
              .animate()
              .fadeIn(duration: 400.ms, delay: 100.ms)
              .slideY(begin: 0.1),

          const SizedBox(height: AppDimensions.spacingSm),

          Text(
            'Écrire aide à clarifier tes pensées\net à mieux comprendre tes émotions.',
            style: AppTextStyles.bodyMedium(color: subtitleColor),
            textAlign: TextAlign.center,
          ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideY(begin: 0.1),

          const SizedBox(height: AppDimensions.spacingXl),

          // Section "Ecrire librement" en premier (visible au-dessus de la navbar)
          LiquidGlassButton(
                label: 'Écrire librement',
                icon: Icons.edit_rounded,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onCreateFirst();
                },
              )
              .animate()
              .fadeIn(duration: 400.ms, delay: 300.ms)
              .slideY(begin: 0.1),

          const SizedBox(height: AppDimensions.spacingXxl),

          // Divider
          Row(
            children: [
              Expanded(
                child: Divider(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.08),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Besoin d\'inspiration ?',
                  style: AppTextStyles.titleSmall(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.08),
                ),
              ),
            ],
          ).animate().fadeIn(duration: 400.ms, delay: 350.ms),

          const SizedBox(height: AppDimensions.spacingMd),

          // Cartes d'inspiration
          ...prompts.asMap().entries.map((entry) {
            final index = entry.key;
            final prompt = entry.value;
            return _PromptCard(
                  prompt: prompt,
                  isDark: isDark,
                  onTap: () {
                    if (onPromptSelected != null) {
                      onPromptSelected!(prompt);
                    } else {
                      onCreateFirst();
                    }
                  },
                )
                .animate()
                .fadeIn(
                  duration: 350.ms,
                  delay: (400 + index * 80).ms,
                  curve: Curves.easeOutCubic,
                )
                .slideY(
                  begin: 0.05,
                  duration: 350.ms,
                  delay: (400 + index * 80).ms,
                  curve: Curves.easeOutCubic,
                );
          }),
        ],
      ),
    );
  }
}

class _PromptCard extends StatefulWidget {
  final JournalPrompt prompt;
  final bool isDark;
  final VoidCallback onTap;

  const _PromptCard({
    required this.prompt,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_PromptCard> createState() => _PromptCardState();
}

class _PromptCardState extends State<_PromptCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          HapticFeedback.lightImpact();
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: LiquidGlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      widget.prompt.icon,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.prompt.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: widget.isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.prompt.subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.isDark
                              ? AppColors.textTertiaryDark
                              : AppColors.textTertiaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: widget.isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
