import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass/liquid_glass_kit.dart';
import '../../data/models/coach_model.dart';
import '../../../dashboard/presentation/widgets/mascot_speech_bubble.dart';
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
                  130,
                ),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(isDark),
                      // ---- Zone héroïque : Elyrii parle, on écoute ----
                      // Composition premium : la bulle vit au-dessus de la
                      // tête (l'attache pointe vers le modèle), la mascotte
                      // en posture d'écoute porte la scène, le besoin arrive
                      // ensuite comme une réponse naturelle.
                      Center(
                        child: Column(
                          children: [
                            const SizedBox(height: 10),
                            MascotSpeechBubble(
                              message: provider.mascotMessage,
                              isDark: isDark,
                              tailAtBottom: true,
                              onTap: provider.nextMascotMessage,
                            ).animate(key: ValueKey(provider.mascotMessage))
                                .fadeIn(duration: 300.ms)
                                .slideY(
                                  begin: -0.06,
                                  end: 0,
                                  duration: 300.ms,
                                  curve: Curves.easeOutCubic,
                                ),
                            // L'attache plonge légèrement vers la tête.
                            const SizedBox(height: 8),
                            CoachMascot(
                              size: 210,
                              onTap: provider.nextMascotMessage,
                            )
                                .animate()
                                .fadeIn(duration: 450.ms, delay: 80.ms)
                                .slideY(
                                  begin: 0.05,
                                  end: 0,
                                  duration: 450.ms,
                                  curve: Curves.easeOutCubic,
                                ),
                          ],
                        ),
                      ),

                      // ---- Routage par besoin immédiat ----
                      const SizedBox(height: 30),
                      _buildSectionTitle(
                        'De quoi as-tu besoin ?',
                        'Dis-le-moi, je m\'occupe du reste.',
                        isDark,
                      ),
                      const SizedBox(height: 12),
                      NeedSelector(
                        needs: CoachNeed.values,
                        selected: provider.selectedNeed,
                        onSelect: provider.selectNeed,
                      ),
                      const SizedBox(height: 24),
                      _buildHighlightedActivities(provider, isDark),

                      // ---- Conseil du jour ----
                      if (provider.todayAdvice != null) ...[
                        const SizedBox(height: 30),
                        _buildAdviceCard(provider.todayAdvice!, isDark),
                      ],

                      // ---- Dernier échange avec le coach IA ----
                      if (provider.latestSession != null) ...[
                        const SizedBox(height: 16),
                        LatestSessionCard(
                          session: provider.latestSession!,
                          isDark: isDark,
                        ),
                      ],

                      // ---- Catalogue exploratoire ----
                      const SizedBox(height: 30),
                      _buildSectionTitle(
                        'Toutes les activités',
                        'Explore à ton rythme',
                        isDark,
                      ),
                      const SizedBox(height: 12),
                      _buildCategoryGrid(context, provider.allActivities, isDark),
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
        const Text(
          'MON COACH',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Elyrii t\'accompagne',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            height: 1.1,
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
          isDark,
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : AppColors.cardLight,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < activities.length; i++) ...[
                CoachActivityCell(
                  activity: activities[i],
                  isDark: isDark,
                  onTap: () => launchCoachActivity(context, activities[i]),
                ).animate(key: ValueKey('${selectedNeed?.name}-${activities[i].id}'))
                    .fadeIn(duration: 220.ms, delay: (i * 45).ms)
                    .slideY(begin: 0.06, end: 0, duration: 220.ms, delay: (i * 45).ms),
                if (i < activities.length - 1)
                  // Séparateur inseté après l'icône (padding 14 + icône 40 + écart 12).
                  Padding(
                    padding: const EdgeInsets.only(left: 66),
                    child: Container(height: 0.5, color: separatorColor),
                  ),
              ],
            ],
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
        return CoachActivityCard(
          activity: activity,
          isDark: isDark,
          onTap: () => launchCoachActivity(context, activity),
        );
      },
    );
  }
}
