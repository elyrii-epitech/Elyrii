import '../../../../core/accessibility/motion.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/elyrii_page_header.dart';
import '../../../../core/widgets/glass/liquid_glass_kit.dart';
import '../../data/models/coach_model.dart';
import '../providers/coach_provider.dart';
import '../coach_activity_launcher.dart';
import '../widgets/coach_activity_card.dart';
import '../widgets/coach_activity_cell.dart';
import '../widgets/coach_mascot.dart';
import '../widgets/latest_session_card.dart';
import '../widgets/need_selector.dart';

/// Page Coach : Elyrii accueille, demande ce dont l'utilisateur a besoin
/// et route chaque activité vers une expérience réelle — séance de
/// respiration immersive, journal guidé ou guidance IA.
///
/// Composition (philosophie Apple : contenu d'abord, chrome discret) :
/// 1. En-tête spatial + mascotte 3D en posture d'écoute et bulle de parole.
/// 2. Sélection du besoin immédiat qui pilote les recommandations.
/// 3. Conseils groupés iOS, conseil du jour, dernier échange IA.
/// 4. Catalogue exploratoire complet.
class CoachPage extends StatefulWidget {
  const CoachPage({super.key});

  @override
  State<CoachPage> createState() => _CoachPageState();
}

class _CoachPageState extends State<CoachPage> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<CoachProvider>().loadCoachData();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<CoachProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: isDark
              ? AppColors.scaffoldDark
              : AppColors.scaffoldLight,
          body: ElyriiPageFrame.tab(
            title: "Elyrii t'accompagne",
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              CupertinoSliverRefreshControl(onRefresh: provider.loadCoachData),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.pageHorizontalPadding,
                  0,
                  AppDimensions.pageHorizontalPadding,
                  AppDimensions.dockClearance,
                ),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppDimensions.spacing8),
                      Center(
                        child:
                            CoachMascot(
                                  size: 210,
                                  onTap: provider.nextMascotMessage,
                                )
                                .animateRespectingMotion(context)
                                .fadeIn(duration: 450.ms, delay: 60.ms)
                                .slideY(
                                  begin: 0.05,
                                  end: 0,
                                  duration: 450.ms,
                                  curve: Curves.easeOutCubic,
                                ),
                      ),

                      // ---- Routage par besoin immédiat ----
                      const SizedBox(height: AppDimensions.spacing32),
                      _buildSectionTitle(
                        'De quoi as-tu besoin ?',
                        'Dis-le-moi, je m\'occupe du reste.',
                      ),
                      const SizedBox(height: AppDimensions.spacing12),
                      NeedSelector(
                        needs: CoachNeed.values,
                        selected: provider.selectedNeed,
                        onSelect: provider.selectNeed,
                      ),
                      const SizedBox(height: AppDimensions.spacing24),
                      _buildHighlightedActivities(provider, isDark),

                      // ---- Conseil du jour ----
                      if (provider.todayAdvice != null) ...[
                        const SizedBox(height: AppDimensions.spacing32),
                        _buildAdviceCard(provider.todayAdvice!),
                      ],

                      // ---- Dernier échange avec le coach IA ----
                      if (provider.latestSession != null) ...[
                        const SizedBox(height: AppDimensions.spacing16),
                        LatestSessionCard(
                          session: provider.latestSession!,
                          isDark: isDark,
                        ),
                      ],

                      // ---- Catalogue exploratoire ----
                      const SizedBox(height: AppDimensions.spacing32),
                      _buildSectionTitle(
                        'Toutes les activités',
                        'Explore à ton rythme',
                      ),
                      const SizedBox(height: AppDimensions.spacing12),
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

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.titleMedium(color: context.textPrimary),
        ),
        const SizedBox(height: AppDimensions.spacing4),
        Text(
          subtitle,
          style: AppTextStyles.bodySmall(color: context.textTertiary),
        ),
      ],
    );
  }

  /// Conteneur groupé iOS (rayon 16) des activités mises en avant : cellules
  /// adjacentes séparées par des séparateurs insetés alignés sur le texte —
  /// façon Réglages iOS. Le titre suit le besoin sélectionné.
  Widget _buildHighlightedActivities(CoachProvider provider, bool isDark) {
    final activities = provider.highlightedActivities;
    if (activities.isEmpty) return const SizedBox.shrink();

    final separatorColor = isDark
        ? AppColors.dividerDark
        : AppColors.dividerLight;
    final selectedNeed = provider.selectedNeed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          selectedNeed?.sectionTitle ?? 'Recommandé pour toi',
          selectedNeed != null
              ? 'Choisi pour ce moment précis'
              : 'Trois façons simples de commencer',
        ),
        const SizedBox(height: AppDimensions.spacing12),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : AppColors.cardLight,
            borderRadius: BorderRadius.circular(AppDimensions.radius16),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < activities.length; i++) ...[
                CoachActivityCell(
                      activity: activities[i],
                      isDark: isDark,
                      onTap: () => launchCoachActivity(context, activities[i]),
                    )
                    .animateRespectingMotion(
                      context,
                      key: ValueKey(
                        '${selectedNeed?.name}-${activities[i].id}',
                      ),
                    )
                    .fadeIn(duration: 220.ms, delay: (i * 45).ms)
                    .slideY(
                      begin: 0.06,
                      end: 0,
                      duration: 220.ms,
                      delay: (i * 45).ms,
                    ),
                if (i < activities.length - 1)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: CoachActivityCell.dividerInset,
                    ),
                    child: Container(height: 0.5, color: separatorColor),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAdviceCard(DailyAdvice advice) {
    return LiquidGlassCard(
      padding: const EdgeInsets.all(AppDimensions.spacing20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppDimensions.spacing8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppDimensions.radius12),
                ),
                child: Icon(advice.icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: AppDimensions.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Conseil du jour',
                      style: AppTextStyles.titleSmall(
                        color: AppColors.readableAccent(
                          AppColors.primary,
                          isDark:
                              Theme.of(context).brightness == Brightness.dark,
                        ),
                      ),
                    ),
                    Text(
                      advice.source,
                      style: AppTextStyles.labelSmall(
                        color: context.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing16),
          Text(
            advice.text,
            style: AppTextStyles.bodyMedium(color: context.textPrimary),
          ),
          if (advice.sourceUrl != null)
            TextButton.icon(
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Consulter la source'),
              onPressed: () async {
                final opened = await launchUrl(
                  Uri.parse(advice.sourceUrl!),
                  mode: LaunchMode.externalApplication,
                );
                if (!opened && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Impossible d’ouvrir la source. Réessaie.'),
                    ),
                  );
                }
              },
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid(
    BuildContext context,
    List<CoachActivity> activities,
    bool isDark,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            constraints.maxWidth >= 340 &&
                MediaQuery.textScalerOf(context).scale(1) <= 1.2
            ? 2
            : 1;
        final width =
            (constraints.maxWidth - AppDimensions.spacing12 * (columns - 1)) /
            columns;
        return Wrap(
          spacing: AppDimensions.spacing12,
          runSpacing: AppDimensions.spacing12,
          children: activities
              .map(
                (activity) => SizedBox(
                  width: width,
                  child: CoachActivityCard(
                    activity: activity,
                    isDark: isDark,
                    onTap: () => launchCoachActivity(context, activity),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}
