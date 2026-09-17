import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/config/mascot_animations.dart';
import '../../../../core/widgets/glass/liquid_glass_kit.dart';
import '../../../mascot/presentation/providers/mascot_provider.dart';
import '../providers/coach_provider.dart';
import '../../data/models/coach_model.dart';
import '../../../../core/design_system/haptics/elyrii_haptics.dart';

class CoachPage extends StatefulWidget {
  const CoachPage({super.key});

  @override
  State<CoachPage> createState() => _CoachPageState();
}

class _CoachPageState extends State<CoachPage> {
  /// Message de retour inline (succès ou échec) après une demande de
  /// guidance, sous forme de bannière contextuelle iOS.
  String? _feedbackMessage;
  bool _feedbackIsSuccess = false;
  Timer? _feedbackTimer;

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    super.dispose();
  }

  /// Affiche une bannière contextuelle dans le flux de la page, qui
  /// s'efface d'elle-même après quelques secondes.
  void _showFeedback({required bool success, required String message}) {
    _feedbackTimer?.cancel();
    setState(() {
      _feedbackMessage = message;
      _feedbackIsSuccess = success;
    });
    _feedbackTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _feedbackMessage = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<CoachProvider>(
      builder: (context, provider, _) {
        if (!provider.hasLoadedRemote && !provider.isLoading) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              context.read<CoachProvider>().loadCoachData();
            }
          });
        }

        return Scaffold(
          backgroundColor: isDark
              ? AppColors.scaffoldDark
              : AppColors.scaffoldLight,
          // Tire-pour-rafraîchir natif iOS, plus aucun indicateur
          // de rafraîchissement Material.
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              CupertinoSliverRefreshControl(onRefresh: provider.loadCoachData),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  AppDimensions.pageHorizontalPadding,
                  MediaQuery.of(context).padding.top + 16,
                  AppDimensions.pageHorizontalPadding,
                  120,
                ),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(isDark),
                      if (_feedbackMessage != null) ...[
                        const SizedBox(height: 16),
                        _buildInlineBanner(
                              icon: _feedbackIsSuccess
                                  ? Icons.check_circle_rounded
                                  : Icons.cloud_off_rounded,
                              accent: _feedbackIsSuccess
                                  ? AppColors.success
                                  : AppColors.error,
                              message: _feedbackMessage!,
                              isDark: isDark,
                            )
                            .animate()
                            .fadeIn(duration: 200.ms),
                      ],
                      const SizedBox(height: 28),
                      if (provider.todayAdvice != null)
                        _buildAdviceCard(provider.todayAdvice!, isDark),
                      if (provider.isCreatingSession) ...[
                        const SizedBox(height: 16),
                        // Chargement d'une session : squelette shimmer discret
                        // de la couleur de surface, aucune barre de progression.
                        _GuidanceSkeleton(isDark: isDark),
                      ],
                      if (provider.error != null) ...[
                        const SizedBox(height: 16),
                        _buildInlineBanner(
                          icon: Icons.cloud_off_rounded,
                          accent: AppColors.error,
                          message: provider.error!,
                          isDark: isDark,
                        ),
                      ],
                      if (provider.latestSession != null) ...[
                        const SizedBox(height: 16),
                        _buildLatestSessionCard(
                          provider.latestSession!,
                          isDark,
                        ),
                      ],
                      const SizedBox(height: 28),
                      _buildSectionTitle(
                        'Recommandé pour toi',
                        'Basé sur ta progression et ton humeur',
                        isDark,
                      ),
                      const SizedBox(height: 12),
                      if (provider.recommendedActivities.isNotEmpty)
                        _buildRecommendedGroup(
                          context,
                          provider.recommendedActivities,
                          isDark,
                        ),
                      const SizedBox(height: 28),
                      _buildSectionTitle(
                        'Toutes les activités',
                        'Explore à ton rythme',
                        isDark,
                      ),
                      const SizedBox(height: 12),
                      _buildCategoryGrid(
                        context,
                        provider.allActivities,
                        isDark,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mon Coach',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Ton compagnon bien-être quotidien',
          style: TextStyle(
            fontSize: 15,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }

  Widget _buildAdviceCard(DailyAdvice advice, bool isDark) {
    return LiquidGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(advice.icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Conseil du jour',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      advice.source,
                      style: TextStyle(
                        fontSize: 11,
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
          const SizedBox(height: 16),
          Text(
            advice.text,
            style: AppTextStyles.bodyMedium(
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
              fontWeight: FontWeight.w400,
            ).copyWith(height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color: isDark
                ? AppColors.textTertiaryDark
                : AppColors.textTertiaryLight,
          ),
        ),
      ],
    );
  }

  /// Conteneur groupé iOS (rayon 16) : les activités recommandées y sont
  /// présentées en cellules adjacentes, séparées par des séparateurs insetés
  /// alignés sur le texte — façon Réglages iOS.
  Widget _buildRecommendedGroup(
    BuildContext context,
    List<CoachActivity> activities,
    bool isDark,
  ) {
    final separatorColor = isDark
        ? AppColors.dividerDark
        : AppColors.dividerLight;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < activities.length; i++) ...[
            _RecommendedActivityCell(
              activity: activities[i],
              isDark: isDark,
              onTap: () => _requestGuidance(context, activities[i]),
            ),
            if (i < activities.length - 1)
              // Séparateur inseté après l'icône (padding 14 + icône 40 + écart 12).
              Padding(
                padding: const EdgeInsets.only(left: 66),
                child: Container(height: 0.5, color: separatorColor),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryGrid(
    BuildContext context,
    List<CoachActivity> activities,
    bool isDark,
  ) {
    return GridView.builder(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: activities.length,
      itemBuilder: (context, index) {
        final activity = activities[index];
        return _ActivityGridCard(
          activity: activity,
          isDark: isDark,
          onTap: () => _requestGuidance(context, activity),
        );
      },
    );
  }

  Widget _buildLatestSessionCard(CoachSession session, bool isDark) {
    final textColor = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final subtitleColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return LiquidGlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: AppColors.accent),
              const SizedBox(width: 8),
              Text(
                'Guidance personnalisée',
                style: AppTextStyles.titleSmall(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            session.response,
            style: AppTextStyles.bodySmall(
              color: subtitleColor,
            ).copyWith(height: 1.45),
          ),
        ],
      ),
    );
  }

  /// Bannière d'alerte contextuelle inline, sans composant Android.
  Widget _buildInlineBanner({
    required IconData icon,
    required Color accent,
    required String message,
    required bool isDark,
  }) {
    return LiquidGlassCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(icon, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _requestGuidance(
    BuildContext context,
    CoachActivity activity,
  ) async {
    ElyriiHaptics.light();
    final mascotProvider = context.read<MascotProvider>();
    final success = await context
        .read<CoachProvider>()
        .requestGuidanceForActivity(activity);
    if (!mounted) return;
    if (success) {
      mascotProvider.react(MascotAnimations.acknowledge);
    }
    _showFeedback(
      success: success,
      message: success
          ? 'Conseil personnalisé enregistré.'
          : 'Impossible de générer un conseil pour le moment.',
    );
  }
}

/// Squelette de chargement discret pour la création de session : shimmer
/// doux de la couleur de surface, en remplacement de toute barre de
/// progression brute.
class _GuidanceSkeleton extends StatelessWidget {
  final bool isDark;

  const _GuidanceSkeleton({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final surface = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.04);

    Widget block(double height) =>
        Container(
              height: height,
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(16),
              ),
            )
            .animate(onPlay: (controller) => controller.repeat())
            .shimmer(
              duration: 1400.ms,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.5),
            );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [block(18), const SizedBox(height: 12), block(64)],
    );
  }
}

/// Cellule d'activité recommandée dans le conteneur groupé iOS : icône
/// squircle colorée, titre et description, pilule de durée arrondie et
/// chevron de navigation discret à droite.
class _RecommendedActivityCell extends StatefulWidget {
  final CoachActivity activity;
  final bool isDark;
  final VoidCallback onTap;

  const _RecommendedActivityCell({
    required this.activity,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_RecommendedActivityCell> createState() =>
      _RecommendedActivityCellState();
}

class _RecommendedActivityCellState extends State<_RecommendedActivityCell> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.activity.category.color;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      // Surbrillance discrète à l'appui, façon cellule iOS groupée.
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: _isPressed
            ? (widget.isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.04))
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(widget.activity.icon, size: 20, color: color),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.activity.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: widget.isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.activity.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Badge de durée en pilule arrondie, à gauche du chevron.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(
                  AppDimensions.radiusCircular,
                ),
              ),
              child: Text(
                '${widget.activity.durationMinutes} min',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: widget.isDark
                  ? AppColors.textTertiaryDark
                  : AppColors.textTertiaryLight,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityGridCard extends StatefulWidget {
  final CoachActivity activity;
  final bool isDark;
  final VoidCallback onTap;

  const _ActivityGridCard({
    required this.activity,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_ActivityGridCard> createState() => _ActivityGridCardState();
}

class _ActivityGridCardState extends State<_ActivityGridCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.activity.category.color;

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
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Icon(widget.activity.icon, size: 18, color: color),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${widget.activity.durationMinutes} min',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                widget.activity.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: widget.isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  widget.activity.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(widget.activity.category.icon, size: 12, color: color),
                  const SizedBox(width: 4),
                  Text(
                    widget.activity.category.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
