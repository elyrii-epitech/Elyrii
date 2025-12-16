import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/mascot_peek.dart';
import '../widgets/mascot_speech_bubble.dart';
import '../widgets/glass_mood_selector.dart';
import '../widgets/glass_settings_button.dart';
import '../widgets/last_journal_card.dart';
import '../widgets/mini_stats_row.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenSize = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;

    return ChangeNotifierProvider(
      create: (_) => DashboardProvider(),
      child: Consumer<DashboardProvider>(
        builder: (context, provider, child) {
          return Scaffold(
            backgroundColor:
                isDark ? const Color(0xFF171719) : const Color(0xFFE8E8EB),
            body: Stack(
              clipBehavior: Clip.none,
              children: [
                // Contenu principal avec scroll
                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      // Espace pour la mascotte flottante + bulle + safe area
                      SizedBox(height: topPadding + 170),

                      // Container principal avec le contenu
                      Container(
                        width: double.infinity,
                        constraints: BoxConstraints(
                          minHeight: screenSize.height - topPadding - 170,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.backgroundDark.withValues(alpha: 0.5)
                              : AppColors.backgroundLight
                                  .withValues(alpha: 0.5),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(32),
                            topRight: Radius.circular(32),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimensions.pageHorizontalPadding,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(height: AppDimensions.spacingXl),

                              // Greeting
                              _buildGreeting(provider, isDark),

                              const SizedBox(height: AppDimensions.spacingLg),

                              // Mood Selector
                              GlassMoodSelector(isDark: isDark),

                              const SizedBox(height: AppDimensions.spacingXl),

                              // Mini Stats Row
                              MiniStatsRow(
                                entriesThisMonth: 7,
                                tagsUsed: 3,
                                currentStreak: provider.currentStreak,
                                isDark: isDark,
                              ),

                              const SizedBox(height: AppDimensions.spacingLg),

                              // Last Journal Entry
                              LastJournalCard(
                                title: 'Une journée productive',
                                content:
                                    'Aujourd\'hui j\'ai réussi à finir mon projet et je me sens vraiment accompli...',
                                mood: MoodType.happy,
                                createdAt: DateTime.now()
                                    .subtract(const Duration(hours: 2)),
                                isDark: isDark,
                                onTap: () {
                                  // Navigate to journal
                                },
                              ),

                              // Espace pour la navbar
                              const SizedBox(height: 120),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Mascotte flottante + Bulle (fixe en haut)
                Positioned(
                  top: topPadding + 10,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      // Mascotte
                      MascotPeek(
                        selectedMood: provider.selectedMood,
                        isDark: isDark,
                        onTap: () {
                          provider.nextMascotMessage();
                        },
                      ),
                      const SizedBox(height: 8),
                      // Bulle de dialogue
                      MascotSpeechBubble(
                        message: provider.mascotMessage,
                        isDark: isDark,
                        onTap: () {
                          provider.nextMascotMessage();
                        },
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
                      // Page en construction
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Row(
                            children: [
                              Text('🚧'),
                              SizedBox(width: 8),
                              Text('Paramètres en cours de construction'),
                            ],
                          ),
                          backgroundColor: AppColors.primary,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
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
          '${provider.getGreeting()} ${provider.userName} 👋',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color:
                isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
