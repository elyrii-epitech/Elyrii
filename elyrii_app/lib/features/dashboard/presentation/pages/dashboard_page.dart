import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/liquid_glass_kit.dart';
import '../../../../routes/app_routes.dart';
import '../../data/models/dashboard_models.dart';
import '../../data/repositories/dashboard_repository.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/glass_settings_button.dart';
import '../widgets/last_journal_card.dart';
import '../../../journal/presentation/providers/journal_provider.dart';

import '../../../auth/presentation/providers/auth_provider.dart';

import '../widgets/mascot_peek.dart';
import '../widgets/mascot_speech_bubble.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().loadDashboardData();
      context.read<JournalProvider>().loadEntries();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top;

    return Consumer3<DashboardProvider, JournalProvider, AuthProvider>(
      builder: (context, provider, journalProvider, authProvider, child) {
        final firstName = authProvider.user?.firstName ?? '';

        return Scaffold(
          backgroundColor: isDark
              ? AppColors.scaffoldDark
              : AppColors.scaffoldLight,
          body: Stack(
            clipBehavior: Clip.none,
            children: [
              // Contenu principal avec scroll
              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    // Espace pour le status bar
                    SizedBox(height: topPadding),

                    // Mascotte 3D
                    MascotPeek(
                      selectedMood: provider.selectedMood,
                      isDark: isDark,
                      onTap: provider.nextMascotMessage,
                    ),

                    // Container principal avec le contenu
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.pageHorizontalPadding,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Speech Bubble de la mascotte
                          MascotSpeechBubble(
                                message: provider.mascotMessage,
                                isDark: isDark,
                                onTap: provider.nextMascotMessage,
                              )
                              .animate()
                              .fadeIn(delay: 400.ms)
                              .scale(curve: Curves.easeOutBack),

                          const SizedBox(height: 24),

                          // Greeting avec animation
                          _buildGreeting(provider, isDark, firstName)
                              .animate()
                              .fadeIn(duration: 400.ms)
                              .slideY(begin: 0.1, end: 0),

                          if (provider.isLoading) ...[
                            const SizedBox(height: 16),
                            const LinearProgressIndicator(minHeight: 3),
                          ],
                          if (provider.error != null) ...[
                            const SizedBox(height: 16),
                            _buildErrorBanner(provider.error!, isDark),
                          ],

                          const SizedBox(height: 28),

                          // Section "Comment te sens-tu ?"
                          _buildMoodSection(isDark, provider)
                              .animate()
                              .fadeIn(duration: 400.ms, delay: 100.ms)
                              .slideY(begin: 0.1, end: 0),

                          const SizedBox(height: 32),

                          // Section Stats
                          _buildStatsSection(provider, isDark)
                              .animate()
                              .fadeIn(duration: 400.ms, delay: 200.ms)
                              .slideY(begin: 0.1, end: 0),

                          const SizedBox(height: 24),

                          _buildReviewEntry(isDark)
                              .animate()
                              .fadeIn(duration: 400.ms, delay: 250.ms)
                              .slideY(begin: 0.1, end: 0),

                          const SizedBox(height: 24),

                          // Section "Ton activité"
                          _buildActivitySection(isDark, journalProvider)
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
    );
  }

  Widget _buildGreeting(
    DashboardProvider provider,
    bool isDark,
    String firstName,
  ) {
    return Column(
      children: [
        Text(
          '${provider.getGreeting()} $firstName',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
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
                child: const Icon(
                  Icons.mood_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
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
    return Column(
      children: [
        Row(
          children: [
            _StatChip(
              icon: Icons.edit_note_rounded,
              value: '${provider.journalEntriesCount}',
              label: 'entrées',
              color: AppColors.primary,
              isDark: isDark,
            ),
            const SizedBox(width: 12),
            _StatChip(
              icon: Icons.local_fire_department_rounded,
              value: '${provider.currentStreak}',
              label: 'jours',
              color: AppColors.secondary,
              isDark: isDark,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _StatChip(
              icon: Icons.flag_rounded,
              value: '${provider.activeChallengesCount}',
              label: 'défis',
              color: AppColors.accent,
              isDark: isDark,
            ),
            const SizedBox(width: 12),
            _StatChip(
              icon: Icons.stars_rounded,
              value: '${provider.totalPoints}',
              label: 'points',
              color: AppColors.success,
              isDark: isDark,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReviewEntry(bool isDark) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.pushNamed(context, AppRoutes.reviews);
      },
      child: LiquidGlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.analytics_rounded,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Voir le bilan',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Analyse ton humeur, tes journaux et tes progrès sur une période donnée.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark
                  ? AppColors.textTertiaryDark
                  : AppColors.textTertiaryLight,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message, bool isDark) {
    return LiquidGlassCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.error),
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

  Widget _buildActivitySection(bool isDark, JournalProvider journalProvider) {
    final lastEntry = journalProvider.entries.isNotEmpty
        ? journalProvider.entries.first
        : null;

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
          title: lastEntry?.title,
          content: lastEntry?.content,
          mood: _parseMood(lastEntry?.mood),
          createdAt: lastEntry?.createdAt,
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

  MoodType? _parseMood(String? moodName) {
    if (moodName == null) return null;
    try {
      return MoodType.values.firstWhere((m) => m.name == moodName);
    } catch (_) {
      return null;
    }
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
          child: Icon(
            widget.mood.icon,
            size: widget.isSelected ? 28 : 24,
            color: widget.isSelected
                ? widget.mood.color
                : (widget.isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight),
          ),
        ),
      ),
    );
  }
}

/// Chip de statistique
class _StatChip extends StatelessWidget {
  final IconData icon;
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
            Icon(icon, size: 22, color: color),
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

class ReviewsPage extends StatefulWidget {
  const ReviewsPage({super.key});

  @override
  State<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends State<ReviewsPage> {
  static const List<String> _ranges = ['7d', '30d', '90d'];

  late String _selectedRange;
  late Future<DashboardStats> _future;

  @override
  void initState() {
    super.initState();
    _selectedRange = _ranges[1];
    _future = _loadStats();
  }

  Future<DashboardStats> _loadStats() {
    final client = context.read<ApiClient>();
    final repository = DashboardRepository(client: client);
    return repository.getStats(range: _selectedRange);
  }

  void _selectRange(String range) {
    if (_selectedRange == range) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedRange = range;
      _future = _loadStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.scaffoldDark
          : AppColors.scaffoldLight,
      body: SafeArea(
        top: false,
        bottom: false,
        child: FutureBuilder<DashboardStats>(
          future: _future,
          builder: (context, snapshot) {
            final stats = snapshot.data;

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, topPadding, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.maybePop(context),
                              icon: Icon(
                                Icons.arrow_back_rounded,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Bilan',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? AppColors.textPrimaryDark
                                          : AppColors.textPrimaryLight,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Une vue claire sur ton humeur, ton activité et tes progrès.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark
                                          ? AppColors.textSecondaryDark
                                          : AppColors.textSecondaryLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _future = _loadStats();
                                });
                              },
                              icon: Icon(
                                Icons.refresh_rounded,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _RangeSelector(
                          isDark: isDark,
                          selectedRange: _selectedRange,
                          onSelected: _selectRange,
                        ),
                        const SizedBox(height: 16),
                        if (snapshot.connectionState == ConnectionState.waiting)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        if (snapshot.hasError)
                          LiquidGlassCard(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'Impossible de charger le bilan pour le moment.',
                                style: TextStyle(
                                  color: isDark
                                      ? AppColors.textPrimaryDark
                                      : AppColors.textPrimaryLight,
                                ),
                              ),
                            ),
                          ),
                        if (stats != null) ...[
                          _OverviewGrid(stats: stats, isDark: isDark),
                          const SizedBox(height: 20),
                          _SectionHeader(
                            title: 'Tendance de l’humeur',
                            subtitle: 'Nombre de prises d’humeur par jour',
                            isDark: isDark,
                          ),
                          const SizedBox(height: 12),
                          _TrendChart(stats: stats, isDark: isDark),
                          const SizedBox(height: 20),
                          _SectionHeader(
                            title: 'Répartition',
                            subtitle: 'Ce qui ressort le plus sur la période',
                            isDark: isDark,
                          ),
                          const SizedBox(height: 12),
                          _MoodDistributionList(stats: stats, isDark: isDark),
                          const SizedBox(height: 20),
                          _SectionHeader(
                            title: 'Activité',
                            subtitle:
                                'Journal et humeur sur la même ligne du temps',
                            isDark: isDark,
                          ),
                          const SizedBox(height: 12),
                          _ActivityTimeline(stats: stats, isDark: isDark),
                          const SizedBox(height: 140),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RangeSelector extends StatelessWidget {
  final bool isDark;
  final String selectedRange;
  final ValueChanged<String> onSelected;

  const _RangeSelector({
    required this.isDark,
    required this.selectedRange,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    const ranges = ['7d', '30d', '90d'];

    return Row(
      children: ranges.map((range) {
        final selected = selectedRange == range;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: range == ranges.last ? 0 : 8),
            child: GestureDetector(
              onTap: () => onSelected(range),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.16)
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.03)),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  border: Border.all(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.45)
                        : Colors.transparent,
                  ),
                ),
                child: Center(
                  child: Text(
                    range,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? AppColors.primary
                          : (isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _OverviewGrid extends StatelessWidget {
  final DashboardStats stats;
  final bool isDark;

  const _OverviewGrid({required this.stats, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _SummaryTile(
              width: tileWidth,
              icon: Icons.local_fire_department_rounded,
              label: 'Streak',
              value: '${stats.streak}',
              color: AppColors.secondary,
              isDark: isDark,
            ),
            _SummaryTile(
              width: tileWidth,
              icon: Icons.mood_rounded,
              label: 'Humeurs',
              value: '${stats.moodLogsCount}',
              color: AppColors.primary,
              isDark: isDark,
            ),
            _SummaryTile(
              width: tileWidth,
              icon: Icons.edit_note_rounded,
              label: 'Journal',
              value: '${stats.journalEntriesCount}',
              color: AppColors.accent,
              isDark: isDark,
            ),
            _SummaryTile(
              width: tileWidth,
              icon: Icons.stars_rounded,
              label: 'Points',
              value: '${stats.totalPoints}',
              color: AppColors.success,
              isDark: isDark,
            ),
            _SummaryTile(
              width: tileWidth,
              icon: Icons.flag_rounded,
              label: 'Défis',
              value:
                  '${stats.completedChallengesCount}/${stats.activeChallengesCount + stats.completedChallengesCount}',
              color: AppColors.warning,
              isDark: isDark,
            ),
            _SummaryTile(
              width: tileWidth,
              icon: Icons.self_improvement_rounded,
              label: 'Méditation',
              value: '${stats.meditationSessionsCount}',
              color: AppColors.info,
              isDark: isDark,
            ),
            _SummaryTile(
              width: tileWidth,
              icon: Icons.trending_up_rounded,
              label: 'Taux',
              value: '${(stats.completionRate * 100).round()}%',
              color: AppColors.successDark,
              isDark: isDark,
            ),
          ],
        );
      },
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final double width;
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _SummaryTile({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: LiquidGlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
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

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isDark;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
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
            fontSize: 12,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }
}

class _TrendChart extends StatelessWidget {
  final DashboardStats stats;
  final bool isDark;

  const _TrendChart({required this.stats, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final points = stats.moodTrend7Days;
    if (points.isEmpty) {
      return LiquidGlassCard(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Aucune humeur enregistrée sur cette période.',
          style: TextStyle(
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
      );
    }

    final maxCount = points
        .map((point) => point.count)
        .fold<int>(0, (max, value) => value > max ? value : max)
        .clamp(1, 9999)
        .toDouble();
    return LiquidGlassCard(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        height: 180,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: points.map((point) {
              final parsedDate = DateTime.tryParse(point.day);
              final barHeight = 104.0 * (point.count / maxCount);
              final accent = point.count > 0
                  ? AppColors.primary.withValues(alpha: 0.85)
                  : (isDark ? Colors.white24 : Colors.black12);

              return SizedBox(
                width: 44,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${point.count}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 108,
                      alignment: Alignment.bottomCenter,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 16,
                        height: barHeight.clamp(6, 104).toDouble(),
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      parsedDate != null
                          ? _shortDateLabel(parsedDate)
                          : point.day,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

String _shortDateLabel(DateTime date) {
  const months = [
    'Jan',
    'Fév',
    'Mar',
    'Avr',
    'Mai',
    'Juin',
    'Juil',
    'Août',
    'Sep',
    'Oct',
    'Nov',
    'Déc',
  ];
  return '${date.day} ${months[date.month - 1]}';
}

class _MoodDistributionList extends StatelessWidget {
  final DashboardStats stats;
  final bool isDark;

  const _MoodDistributionList({required this.stats, required this.isDark});

  Color _moodColor(String moodType) {
    switch (moodType) {
      case 'verySad':
        return const Color(0xFF7BA3C7);
      case 'sad':
        return const Color(0xFF93B8DA);
      case 'neutral':
        return const Color(0xFFA39C96);
      case 'happy':
        return const Color(0xFFA8D5BA);
      case 'veryHappy':
        return const Color(0xFF7BC393);
      default:
        return AppColors.primary;
    }
  }

  String _moodLabel(String moodType) {
    switch (moodType) {
      case 'verySad':
        return 'Très triste';
      case 'sad':
        return 'Triste';
      case 'neutral':
        return 'Neutre';
      case 'happy':
        return 'Content';
      case 'veryHappy':
        return 'Très content';
      default:
        return 'Inconnu';
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = stats.moodDistribution;
    if (items.isEmpty) {
      return LiquidGlassCard(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Aucune répartition disponible.',
          style: TextStyle(
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
      );
    }

    final total = items.fold<int>(0, (sum, item) => sum + item.count);

    return LiquidGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: items.map((item) {
          final percentage = total == 0 ? 0.0 : item.count / total;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _moodColor(item.moodType),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _moodLabel(item.moodType),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: percentage,
                          minHeight: 8,
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.05),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _moodColor(item.moodType),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${item.count}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ActivityTimeline extends StatelessWidget {
  final DashboardStats stats;
  final bool isDark;

  const _ActivityTimeline({required this.stats, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final points = stats.activityTimeline;
    if (points.isEmpty) {
      return LiquidGlassCard(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Aucune activité à afficher sur cette période.',
          style: TextStyle(
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
      );
    }

    return LiquidGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: points.map((point) {
          final parsedDate = DateTime.tryParse(point.day);
          final total = point.moodLogs + point.journalEntries;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                SizedBox(
                  width: 88,
                  child: Text(
                    parsedDate != null
                        ? _shortDateLabel(parsedDate)
                        : point.day,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Humeurs ${point.moodLogs}  Journal ${point.journalEntries}  Total $total',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            flex: point.moodLogs == 0 ? 1 : point.moodLogs,
                            child: Container(
                              height: 8,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(
                                  alpha: 0.75,
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: point.journalEntries == 0
                                ? 1
                                : point.journalEntries,
                            child: Container(
                              height: 8,
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
