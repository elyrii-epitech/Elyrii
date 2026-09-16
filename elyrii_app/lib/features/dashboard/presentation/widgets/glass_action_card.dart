import 'package:flutter/material.dart';
import '../../../../core/design_system/haptics/elyrii_haptics.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/glass/elyrii_glass_surface.dart';

/// Widget carte d'action avec effet glassmorphism
class GlassActionCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDark;
  final Color? accentColor;

  const GlassActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDark = false,
    this.accentColor,
  });

  @override
  State<GlassActionCard> createState() => _GlassActionCardState();
}

class _GlassActionCardState extends State<GlassActionCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.accentColor ?? AppColors.primary;

    return Expanded(
      child: GestureDetector(
        onTapDown: (_) {
          setState(() => _isPressed = true);
          ElyriiHaptics.light();
        },
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeInOut,
          child: ElyriiGlassSurface(
            role: GlassRole.floatingControl,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            padding: const EdgeInsets.all(AppDimensions.paddingMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icône dans un cercle
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accentColor.withValues(alpha: 0.2),
                        accentColor.withValues(alpha: 0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Icon(widget.icon, color: accentColor, size: 24),
                ),
                const SizedBox(height: AppDimensions.spacingMd),
                // Titre
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: widget.isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingXxs),
                // Sous-titre
                Text(
                  widget.subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: widget.isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget pour afficher les deux cartes d'action côte à côte
class ActionCardsRow extends StatelessWidget {
  final bool isDark;
  final VoidCallback onJournalTap;
  final VoidCallback onChatTap;

  const ActionCardsRow({
    super.key,
    this.isDark = false,
    required this.onJournalTap,
    required this.onChatTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GlassActionCard(
          icon: Icons.menu_book_rounded,
          title: 'Écrire',
          subtitle: 'dans ton journal',
          onTap: onJournalTap,
          isDark: isDark,
          accentColor: AppColors.accent,
        ),
        const SizedBox(width: AppDimensions.spacingMd),
        GlassActionCard(
          icon: Icons.chat_bubble_rounded,
          title: 'Parler',
          subtitle: 'à Elyrii',
          onTap: onChatTap,
          isDark: isDark,
          accentColor: AppColors.primary,
        ),
      ],
    );
  }
}
