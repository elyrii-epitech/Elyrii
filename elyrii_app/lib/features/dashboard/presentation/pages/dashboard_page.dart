import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/liquid_glass_kit.dart';
import '../../../../routes/app_routes.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/glass_settings_button.dart';
import '../widgets/last_journal_card.dart';
import '../../../mascot/presentation/widgets/mascot_widget.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top;

    return ChangeNotifierProvider(
      create: (_) => DashboardProvider(),
      child: Consumer<DashboardProvider>(
        builder: (context, provider, child) {
          return Scaffold(
            backgroundColor:
                isDark ? AppColors.scaffoldDark : AppColors.scaffoldLight,
            body: Stack(
              clipBehavior: Clip.none,
              children: [
                // Contenu principal avec scroll
                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      // Safe area + espace pour le bouton settings
                      SizedBox(height: topPadding + 24),

                      // Container principal avec le contenu
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.pageHorizontalPadding,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Greeting avec animation
                            _buildGreeting(provider, isDark)
                                .animate()
                                .fadeIn(duration: 400.ms)
                                .slideY(begin: 0.1, end: 0),

                            const SizedBox(height: 28),

                            // Section "Comment te sens-tu ?"
                            _buildMoodSection(isDark, provider)
                                .animate()
                                .fadeIn(duration: 400.ms, delay: 100.ms)
                                .slideY(begin: 0.1, end: 0),

                            const SizedBox(height: 24),

                            // NOUVEAUTÉ : Section Mascotte 3D
                            _buildMascotSection(context, isDark)
                                .animate()
                                .fadeIn(duration: 400.ms, delay: 150.ms)
                                .slideY(begin: 0.1, end: 0),

                            const SizedBox(height: 32),

                            // Section Stats
                            _buildStatsSection(provider, isDark)
                                .animate()
                                .fadeIn(duration: 400.ms, delay: 200.ms)
                                .slideY(begin: 0.1, end: 0),

                            const SizedBox(height: 24),

                            // Section "Ton activité"
                            _buildActivitySection(isDark)
                                .animate()
                                .fadeIn(duration: 400.ms, delay: 300.ms)
                                .slideY(begin: 0.1, end: 0),

                            // Espace pour la navbar
                            const SizedBox(height: 140),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Bouton Settings (liquid glass)
                Positioned(
                  top: topPadding + 12,
                  right: 16,
                  child: GlassSettingsButton(
                    isDark: isDark,
                    onTap: () {
                      Navigator.pushNamed(context, AppRoutes.settings);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGreeting(DashboardProvider provider, bool isDark) {
    return Column(
      children: [
        Text(
          '${provider.getGreeting()} ${provider.userName}',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color:
                isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          _getMotivationalMessage(),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _getMotivationalMessage() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Comment vas-tu commencer cette journée ?';
    } else if (hour < 18) {
      return 'Comment se passe ta journée ?';
    } else {
      return 'Comment s\'est passée ta journée ?';
    }
  }

  Widget _buildMoodSection(bool isDark, DashboardProvider provider) {
    return LiquidGlassCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('💭', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mon humeur',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                    Text(
                      provider.getMoodMessage(),
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Mood buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: MoodType.values.map((mood) {
              final isSelected = provider.selectedMood == mood;
              return _MoodChip(
                mood: mood,
                isSelected: isSelected,
                isDark: isDark,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  provider.selectMood(mood);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(DashboardProvider provider, bool isDark) {
    return Row(
      children: [
        _StatChip(
          icon: '📝',
          value: '7',
          label: 'entrées',
          color: AppColors.primary,
          isDark: isDark,
        ),
        const SizedBox(width: 12),
        _StatChip(
          icon: '🔥',
          value: '${provider.currentStreak}',
          label: 'jours',
          color: AppColors.secondary,
          isDark: isDark,
        ),
        const SizedBox(width: 12),
        _StatChip(
          icon: '⭐',
          value: '3',
          label: 'objectifs',
          color: AppColors.accent,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildActivitySection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Activité récente',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
        ),
        // Last Journal Entry
        LastJournalCard(
          title: 'Une journée productive',
          content:
              'Aujourd\'hui j\'ai réussi à finir mon projet et je me sens vraiment accompli...',
          mood: MoodType.happy,
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          isDark: isDark,
          onTap: () {
            // Navigate to journal
          },
        ),
        const SizedBox(height: 16),
        // Quick actions
        _QuickActionsRow(isDark: isDark),
      ],
    );
  }

  Widget _buildMascotSection(BuildContext context, bool isDark) {
    return LiquidGlassCard(
      onTap: () {
        Navigator.pushNamed(context, AppRoutes.mascotCustom);
      },
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Left Info
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, color: AppColors.primary, size: 12),
                      SizedBox(width: 4),
                      Text(
                        'NOUVEAUTÉ 3D',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Mon compagnon',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Habille et interagis avec ta mascotte en 3D temps réel !',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.accent],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.checkroom_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Cabine d\'essayage',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Right 3D mascot preview
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Glow in background
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 30,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  // Mascot Widget
                  const Mascot3DWidget(
                    width: 130,
                    height: 130,
                    autoRotate: false,
                    cameraControls: false,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip de mood amélioré
class _MoodChip extends StatefulWidget {
  final MoodType mood;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _MoodChip({
    required this.mood,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_MoodChip> createState() => _MoodChipState();
}

class _MoodChipState extends State<_MoodChip> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.9 : (widget.isSelected ? 1.1 : 1.0),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppColors.primary.withValues(alpha: 0.2)
                : (widget.isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.03)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isSelected
                  ? AppColors.primary.withValues(alpha: 0.5)
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: Text(
            widget.mood.emoji,
            style: TextStyle(fontSize: widget.isSelected ? 28 : 24),
          ),
        ),
      ),
    );
  }
}

/// Chip de statistique
class _StatChip extends StatelessWidget {
  final String icon;
  final String value;
  final String label;
  final Color color;
  final bool isDark;

  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: LiquidGlassCard(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Row d'actions rapides
class _QuickActionsRow extends StatelessWidget {
  final bool isDark;

  const _QuickActionsRow({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionButton(
            icon: Icons.edit_rounded,
            label: 'Nouvelle note',
            color: AppColors.primary,
            isDark: isDark,
            onTap: () {
              HapticFeedback.lightImpact();
              // Navigate to journal editor
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionButton(
            icon: Icons.self_improvement_rounded,
            label: 'Méditer',
            color: AppColors.accent,
            isDark: isDark,
            onTap: () {
              HapticFeedback.lightImpact();
              // Navigate to meditation
            },
          ),
        ),
      ],
    );
  }
}

/// Bouton d'action rapide
class _QuickActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<_QuickActionButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: LiquidGlassCard(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(widget.icon, color: widget.color, size: 20),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: widget.isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
