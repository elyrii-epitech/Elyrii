import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass/liquid_glass_kit.dart';
import '../../../../core/design_system/haptics/elyrii_haptics.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Bouton principal d'écriture libre
        LiquidGlassButton(
          label: 'Écrire librement',
          icon: Icons.edit_rounded,
          onPressed: () {
            ElyriiHaptics.light();
            onCreateFirst();
          },
        ),
        const SizedBox(height: 20),

        // Séparateur d'inspirations
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
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                'Inspirations pour commencer',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
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
        ),
        const SizedBox(height: 14),

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
                delay: (40 * index).ms,
                curve: Curves.easeOutCubic,
              )
              .slideY(
                begin: 0.05,
                duration: 350.ms,
                delay: (40 * index).ms,
                curve: Curves.easeOutCubic,
              );
        }),
      ],
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
          ElyriiHaptics.light();
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
